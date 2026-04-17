// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {EASClaimVerifier} from "../contracts/EASClaimVerifier.sol";
import {EASTrustedIssuersAdapter} from "../contracts/EASTrustedIssuersAdapter.sol";
import {EASIdentityProxy} from "../contracts/EASIdentityProxy.sol";
import {MockClaimTopicsRegistry} from "../contracts/mocks/MockClaimTopicsRegistry.sol";
import {MockEAS} from "../contracts/mocks/MockEAS.sol";
import {MockAttester} from "../contracts/mocks/MockAttester.sol";

import {KYCStatusPolicy} from "../contracts/policies/KYCStatusPolicy.sol";
import {AccreditationPolicy} from "../contracts/policies/AccreditationPolicy.sol";
import {CountryAllowListPolicy} from "../contracts/policies/CountryAllowListPolicy.sol";

/**
 * @title SetupPilot
 * @notice End-to-end pilot on a local anvil chain using MockEAS.
 * @dev Post-refactor flow:
 *        1. Deploy MockEAS + core contracts + policies.
 *        2. Register schemas on MockEAS (UIDs are keccak-derived in the verifier / adapter
 *           config here; real deployments wire the UIDs from `RegisterSchemas`).
 *        3. Create a Schema-2 authorization attestation for the pilot KYC provider.
 *        4. addTrustedAttester with the authUID (audit C-5).
 *        5. Seed 5 investor identities with Schema-v2 attestations (audit C-7).
 *
 *      Intended for `anvil` / testnet only. Do NOT run on mainnet.
 */
contract SetupPilot is Script {
    uint256 constant TOPIC_KYC = 1;
    uint256 constant TOPIC_ACCREDITATION = 7;
    uint256 constant TOPIC_COUNTRY = 3;

    bytes32 constant INVESTOR_ELIGIBILITY_UID = keccak256("InvestorEligibility_v2");
    bytes32 constant ISSUER_AUTH_UID = keccak256("IssuerAuthorization_v1");

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        console2.log("=== Shibui Pilot Setup ===");
        console2.log("Deployer:", deployer);
        console2.log("Chain ID:", block.chainid);

        vm.startBroadcast(deployerKey);

        // MockEAS so the pilot is fully self-contained.
        MockEAS eas = new MockEAS();
        console2.log("MockEAS:", address(eas));

        EASTrustedIssuersAdapter adapter = new EASTrustedIssuersAdapter(deployer);
        EASIdentityProxy identityProxy = new EASIdentityProxy(deployer);
        EASClaimVerifier verifier = new EASClaimVerifier(deployer);
        MockClaimTopicsRegistry topicsRegistry = new MockClaimTopicsRegistry();

        adapter.setEASAddress(address(eas));
        adapter.setIssuerAuthSchemaUID(ISSUER_AUTH_UID);

        verifier.setEASAddress(address(eas));
        verifier.setTrustedIssuersAdapter(address(adapter));
        verifier.setIdentityProxy(address(identityProxy));
        verifier.setClaimTopicsRegistry(address(topicsRegistry));

        KYCStatusPolicy kycPolicy = new KYCStatusPolicy();

        uint8[] memory accTypes = new uint8[](2);
        accTypes[0] = 2;
        accTypes[1] = 4;
        AccreditationPolicy accPolicy = new AccreditationPolicy(deployer, accTypes);

        uint16[] memory countries = new uint16[](1);
        countries[0] = 840; // US
        CountryAllowListPolicy countryPolicy =
            new CountryAllowListPolicy(deployer, CountryAllowListPolicy.Mode.Allow, countries);

        verifier.setTopicSchemaMapping(TOPIC_KYC, INVESTOR_ELIGIBILITY_UID);
        verifier.setTopicSchemaMapping(TOPIC_ACCREDITATION, INVESTOR_ELIGIBILITY_UID);
        verifier.setTopicSchemaMapping(TOPIC_COUNTRY, INVESTOR_ELIGIBILITY_UID);

        verifier.setTopicPolicy(TOPIC_KYC, address(kycPolicy));
        verifier.setTopicPolicy(TOPIC_ACCREDITATION, address(accPolicy));
        verifier.setTopicPolicy(TOPIC_COUNTRY, address(countryPolicy));

        topicsRegistry.addClaimTopic(TOPIC_KYC);
        topicsRegistry.addClaimTopic(TOPIC_ACCREDITATION);
        topicsRegistry.addClaimTopic(TOPIC_COUNTRY);

        // Schema-2 authorizer (deployer-run). In production, an authorizer must be
        // registered on TrustedIssuerResolver before this step succeeds on real EAS.
        MockAttester authorizer = new MockAttester(address(eas), "PilotAuthorizer");

        // KYC provider
        MockAttester kycProvider = new MockAttester(address(eas), "PilotKYC");

        uint256[] memory authorizedTopics = new uint256[](3);
        authorizedTopics[0] = TOPIC_KYC;
        authorizedTopics[1] = TOPIC_ACCREDITATION;
        authorizedTopics[2] = TOPIC_COUNTRY;

        bytes32 authUID = authorizer.attestIssuerAuthorization(
            ISSUER_AUTH_UID, address(kycProvider), authorizedTopics, "PilotKYC"
        );

        adapter.addTrustedAttester(address(kycProvider), authorizedTopics, authUID);

        // Seed 5 investors
        for (uint256 i = 0; i < 5; i++) {
            address wallet = address(uint160(uint256(keccak256(abi.encodePacked("pilot_wallet_", i)))));
            address identity = address(uint160(uint256(keccak256(abi.encodePacked("pilot_identity_", i)))));

            identityProxy.registerWallet(wallet, identity);

            bytes32 uid = kycProvider.attestInvestorEligibility(
                INVESTOR_ELIGIBILITY_UID,
                identity,
                identity,
                1, // kycStatus = VERIFIED
                0, // amlStatus = CLEAR
                0, // sanctionsStatus = CLEAR
                1, // sourceOfFundsStatus = VERIFIED
                2, // accreditationType = ACCREDITED
                840, // US
                uint64(block.timestamp + 365 days),
                keccak256(abi.encodePacked("evidence-", i)),
                2 // verificationMethod = third-party
            );

            // Register for each required topic
            vm.stopBroadcast();
            vm.startBroadcast(address(kycProvider));
            verifier.registerAttestation(identity, TOPIC_KYC, uid);
            verifier.registerAttestation(identity, TOPIC_ACCREDITATION, uid);
            verifier.registerAttestation(identity, TOPIC_COUNTRY, uid);
            vm.stopBroadcast();
            vm.startBroadcast(deployerKey);

            console2.log("Investor", i + 1);
            console2.log("  wallet:  ", wallet);
            console2.log("  identity:", identity);
            console2.log("  verified:", verifier.isVerified(wallet));
        }

        vm.stopBroadcast();

        console2.log("");
        console2.log("=== Deployment Summary ===");
        console2.log("VERIFIER_ADDRESS=", address(verifier));
        console2.log("ADAPTER_ADDRESS=", address(adapter));
        console2.log("IDENTITY_PROXY_ADDRESS=", address(identityProxy));
        console2.log("TOPICS_REGISTRY=", address(topicsRegistry));
        console2.log("KYC_PROVIDER=", address(kycProvider));
    }
}
