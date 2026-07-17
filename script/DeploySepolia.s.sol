// SPDX-License-Identifier: Apache-2.0
// Copyright © 2026 Enterprise Ethereum Alliance Inc.
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {EASClaimVerifier} from "../contracts/EASClaimVerifier.sol";
import {EASTrustedIssuersAdapter} from "../contracts/EASTrustedIssuersAdapter.sol";
import {EASIdentityProxy} from "../contracts/EASIdentityProxy.sol";
import {ClaimTopicsRegistry} from "../contracts/ClaimTopicsRegistry.sol";
import {TrustedIssuerResolver} from "../contracts/resolvers/TrustedIssuerResolver.sol";

import {KYCStatusPolicy} from "../contracts/policies/KYCStatusPolicy.sol";
import {AMLPolicy} from "../contracts/policies/AMLPolicy.sol";
import {SanctionsPolicy} from "../contracts/policies/SanctionsPolicy.sol";
import {SourceOfFundsPolicy} from "../contracts/policies/SourceOfFundsPolicy.sol";
import {ProfessionalInvestorPolicy} from "../contracts/policies/ProfessionalInvestorPolicy.sol";
import {InstitutionalInvestorPolicy} from "../contracts/policies/InstitutionalInvestorPolicy.sol";
import {CountryAllowListPolicy} from "../contracts/policies/CountryAllowListPolicy.sol";
import {AccreditationPolicy} from "../contracts/policies/AccreditationPolicy.sol";

import {IEAS} from "@eas/IEAS.sol";
import {ISchemaRegistry, SchemaRecord} from "@eas/ISchemaRegistry.sol";
import {ISchemaResolver} from "@eas/resolver/ISchemaResolver.sol";

/**
 * @title DeploySepolia
 * @notice One-command testnet deployment: deploy, register schemas, WIRE,
 *         configure, and write the canonical manifest. Replaces the previous
 *         four-script relay (DeployTestnet -> RegisterSchemas ->
 *         ConfigureBridge -> manual JSON edit) whose hand-carried env vars
 *         allowed the wiring step to be skipped entirely — which is exactly
 *         what happened on the 2026-07-17 Sepolia deployment.
 *
 * @dev Everything a fresh network needs, in dependency order, in a single
 *      broadcast:
 *        1. Core contracts + ClaimTopicsRegistry + TrustedIssuerResolver.
 *        2. All eight topic policies.
 *        3. EAS schema registration (idempotent; UID derivation matches the
 *           EAS SchemaRegistry).
 *        4. Full verifier + adapter wiring (the step that was previously
 *           missing from every non-mock script).
 *        5. Topic-schema, topic-policy, and required-topic configuration.
 *        6. Manifest written to `deployments/<chainid>.autogen.json`
 *           including the deployment block — no manual JSON editing, no
 *           console-log copying.
 *
 *      Testnet only: single ADMIN holds all roles, no multisig gate. For
 *      mainnet use DeployMainnet.s.sol.
 *
 *      Required env:
 *        PRIVATE_KEY     — deployer key
 *      Optional env:
 *        ADMIN_ADDRESS   — defaults to deployer
 *        EAS_ADDRESS     — auto-detected on Sepolia / Base Sepolia
 *        SCHEMA_REGISTRY — auto-detected on Sepolia / Base Sepolia
 *        REQUIRED_TOPICS — comma-separated; defaults to "1,2,13"
 *                          (KYC, AML, Sanctions)
 *
 *      Usage:
 *        PRIVATE_KEY=0x... forge script script/DeploySepolia.s.sol \
 *          --rpc-url $RPC_SEPOLIA --broadcast
 *      Then:
 *        VERIFIER_ADDRESS=<from manifest> forge script \
 *          script/VerifyDeployment.s.sol --rpc-url $RPC_SEPOLIA
 */
contract DeploySepolia is Script {
    uint256 constant TOPIC_KYC = 1;
    uint256 constant TOPIC_AML = 2;
    uint256 constant TOPIC_COUNTRY = 3;
    uint256 constant TOPIC_ACCREDITATION = 7;
    uint256 constant TOPIC_PROFESSIONAL = 9;
    uint256 constant TOPIC_INSTITUTIONAL = 10;
    uint256 constant TOPIC_SANCTIONS = 13;
    uint256 constant TOPIC_SOURCE_OF_FUNDS = 14;

    address constant EAS_SEPOLIA = 0xC2679fBD37d54388Ce493F1DB75320D236e1815e;
    address constant EAS_BASE_SEPOLIA = 0x4200000000000000000000000000000000000021;
    address constant REGISTRY_SEPOLIA = 0x0a7E2Ff54e76B8E6659aedc9103FB21c038050D0;
    address constant REGISTRY_BASE_SEPOLIA = 0x4200000000000000000000000000000000000020;

    string constant INVESTOR_ELIGIBILITY_SCHEMA =
        "address identity,uint8 kycStatus,uint8 amlStatus,uint8 sanctionsStatus,uint8 sourceOfFundsStatus,uint8 accreditationType,uint16 countryCode,uint64 expirationTimestamp,bytes32 evidenceHash,uint8 verificationMethod";

    string constant ISSUER_AUTHORIZATION_SCHEMA = "address issuerAddress,uint256[] authorizedTopics,string issuerName";

    struct Deployed {
        address resolver;
        address adapter;
        address identityProxy;
        address verifier;
        address topicsRegistry;
        address kyc;
        address aml;
        address sanctions;
        address sof;
        address professional;
        address institutional;
        address country;
        address accreditation;
        bytes32 invSchemaUID;
        bytes32 authSchemaUID;
    }

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        address admin = vm.envOr("ADMIN_ADDRESS", deployer);

        address easAddress = vm.envOr("EAS_ADDRESS", address(0));
        if (easAddress == address(0)) easAddress = _getEAS();
        address schemaRegistryAddress = vm.envOr("SCHEMA_REGISTRY", address(0));
        if (schemaRegistryAddress == address(0)) schemaRegistryAddress = _getSchemaRegistry();

        uint256[] memory requiredTopics = _requiredTopics();

        console2.log("=== Shibui orchestrated deploy ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", deployer);
        console2.log("Admin:", admin);
        console2.log("EAS:", easAddress);
        console2.log("Schema registry:", schemaRegistryAddress);

        Deployed memory d;
        uint256 startBlock = block.number;

        vm.startBroadcast(deployerKey);

        // 1. Core contracts
        address[] memory initialAuthorizers;
        d.resolver = address(new TrustedIssuerResolver(IEAS(easAddress), admin, initialAuthorizers));
        d.adapter = address(new EASTrustedIssuersAdapter(admin));
        d.identityProxy = address(new EASIdentityProxy(admin));
        d.verifier = address(new EASClaimVerifier(admin));
        d.topicsRegistry = address(new ClaimTopicsRegistry(admin));

        // 2. Topic policies
        d.kyc = address(new KYCStatusPolicy());
        d.aml = address(new AMLPolicy());
        d.sanctions = address(new SanctionsPolicy());
        d.sof = address(new SourceOfFundsPolicy());
        d.professional = address(new ProfessionalInvestorPolicy());
        d.institutional = address(new InstitutionalInvestorPolicy());
        uint16[] memory defaultCountries = new uint16[](0);
        d.country = address(new CountryAllowListPolicy(admin, CountryAllowListPolicy.Mode.Allow, defaultCountries));
        uint8[] memory defaultAccreditations = new uint8[](0);
        d.accreditation = address(new AccreditationPolicy(admin, defaultAccreditations));

        // 3. EAS schemas (idempotent)
        ISchemaRegistry registry = ISchemaRegistry(schemaRegistryAddress);
        d.invSchemaUID = _registerSchemaIfNeeded(registry, INVESTOR_ELIGIBILITY_SCHEMA, address(0), true);
        d.authSchemaUID = _registerSchemaIfNeeded(registry, ISSUER_AUTHORIZATION_SCHEMA, d.resolver, true);

        // 4. Wiring — the step this script exists to make unskippable.
        //    Requires admin == deployer (testnet default); on a split-role
        //    setup run ConfigureBridge with the operator key instead.
        EASClaimVerifier verifier = EASClaimVerifier(d.verifier);
        verifier.setEASAddress(easAddress);
        verifier.setTrustedIssuersAdapter(d.adapter);
        verifier.setIdentityProxy(d.identityProxy);
        verifier.setClaimTopicsRegistry(d.topicsRegistry);
        EASTrustedIssuersAdapter(d.adapter).setEASAddress(easAddress);
        EASTrustedIssuersAdapter(d.adapter).setIssuerAuthSchemaUID(d.authSchemaUID);

        // 5. Configuration
        ClaimTopicsRegistry topicsRegistry = ClaimTopicsRegistry(d.topicsRegistry);
        for (uint256 i = 0; i < requiredTopics.length; i++) {
            topicsRegistry.addClaimTopic(requiredTopics[i]);
        }

        verifier.setTopicSchemaMapping(TOPIC_KYC, d.invSchemaUID);
        verifier.setTopicSchemaMapping(TOPIC_AML, d.invSchemaUID);
        verifier.setTopicSchemaMapping(TOPIC_COUNTRY, d.invSchemaUID);
        verifier.setTopicSchemaMapping(TOPIC_ACCREDITATION, d.invSchemaUID);
        verifier.setTopicSchemaMapping(TOPIC_PROFESSIONAL, d.invSchemaUID);
        verifier.setTopicSchemaMapping(TOPIC_INSTITUTIONAL, d.invSchemaUID);
        verifier.setTopicSchemaMapping(TOPIC_SANCTIONS, d.invSchemaUID);
        verifier.setTopicSchemaMapping(TOPIC_SOURCE_OF_FUNDS, d.invSchemaUID);

        verifier.setTopicPolicy(TOPIC_KYC, d.kyc);
        verifier.setTopicPolicy(TOPIC_AML, d.aml);
        verifier.setTopicPolicy(TOPIC_COUNTRY, d.country);
        verifier.setTopicPolicy(TOPIC_ACCREDITATION, d.accreditation);
        verifier.setTopicPolicy(TOPIC_PROFESSIONAL, d.professional);
        verifier.setTopicPolicy(TOPIC_INSTITUTIONAL, d.institutional);
        verifier.setTopicPolicy(TOPIC_SANCTIONS, d.sanctions);
        verifier.setTopicPolicy(TOPIC_SOURCE_OF_FUNDS, d.sof);

        vm.stopBroadcast();

        // 6. Manifest — written by the deploy itself, never by hand.
        _writeManifest(d, easAddress, schemaRegistryAddress, deployer, startBlock);

        console2.log("");
        console2.log("=== Deploy complete ===");
        console2.log("Verifier:", d.verifier);
        console2.log("Topics registry:", d.topicsRegistry);
        console2.log("Manifest:", _manifestPath());
        console2.log("Next: VERIFIER_ADDRESS=", d.verifier);
        console2.log("      forge script script/VerifyDeployment.s.sol --rpc-url <rpc>");
    }

    // ============ Internal ============

    function _requiredTopics() internal view returns (uint256[] memory topics) {
        string memory raw = vm.envOr("REQUIRED_TOPICS", string("1,2,13"));
        topics = _parseTopics(raw);
        require(topics.length > 0, "REQUIRED_TOPICS malformed");
    }

    function _registerSchemaIfNeeded(ISchemaRegistry registry, string memory schema, address resolver, bool revocable)
        internal
        returns (bytes32 uid)
    {
        uid = keccak256(abi.encodePacked(schema, resolver, revocable));

        try registry.getSchema(uid) returns (SchemaRecord memory record) {
            if (bytes(record.schema).length > 0) {
                console2.log("Schema already registered, skipping");
                return uid;
            }
        } catch {}

        uid = registry.register(schema, ISchemaResolver(resolver), revocable);
        console2.log("Registered new schema");
    }

    function _manifestPath() internal view returns (string memory) {
        return string.concat("deployments/", vm.toString(block.chainid), ".autogen.json");
    }

    function _writeManifest(
        Deployed memory d,
        address easAddress,
        address schemaRegistryAddress,
        address deployer,
        uint256 startBlock
    ) internal {
        string memory policies = "policies";
        vm.serializeAddress(policies, "KYCStatusPolicy", d.kyc);
        vm.serializeAddress(policies, "AMLPolicy", d.aml);
        vm.serializeAddress(policies, "SanctionsPolicy", d.sanctions);
        vm.serializeAddress(policies, "SourceOfFundsPolicy", d.sof);
        vm.serializeAddress(policies, "AccreditationPolicy", d.accreditation);
        vm.serializeAddress(policies, "ProfessionalInvestorPolicy", d.professional);
        vm.serializeAddress(policies, "InstitutionalInvestorPolicy", d.institutional);
        string memory policiesJson = vm.serializeAddress(policies, "CountryAllowListPolicy", d.country);

        string memory shibui = "shibui";
        vm.serializeAddress(shibui, "EASClaimVerifier", d.verifier);
        vm.serializeAddress(shibui, "EASTrustedIssuersAdapter", d.adapter);
        vm.serializeAddress(shibui, "EASIdentityProxy", d.identityProxy);
        vm.serializeAddress(shibui, "ClaimTopicsRegistry", d.topicsRegistry);
        vm.serializeAddress(shibui, "TrustedIssuerResolver", d.resolver);
        string memory shibuiJson = vm.serializeString(shibui, "policies", policiesJson);

        string memory eas = "eas";
        vm.serializeAddress(eas, "EAS", easAddress);
        string memory easJson = vm.serializeAddress(eas, "SchemaRegistry", schemaRegistryAddress);

        string memory schemas = "schemas";
        vm.serializeBytes32(schemas, "investorEligibility", d.invSchemaUID);
        string memory schemasJson = vm.serializeBytes32(schemas, "issuerAuthorization", d.authSchemaUID);

        string memory root = "root";
        vm.serializeUint(root, "chainId", block.chainid);
        vm.serializeString(root, "eas", easJson);
        vm.serializeString(root, "shibui", shibuiJson);
        vm.serializeString(root, "schemas", schemasJson);
        vm.serializeAddress(root, "deployer", deployer);
        vm.serializeUint(root, "deploymentBlock", startBlock);
        string memory out = vm.serializeUint(root, "deployedAtTimestamp", block.timestamp);

        vm.writeJson(out, _manifestPath());
    }

    /// @notice Parses a comma-separated list like "1,2,13" into a uint256[].
    function _parseTopics(string memory raw) internal pure returns (uint256[] memory) {
        bytes memory b = bytes(raw);
        if (b.length == 0) return new uint256[](0);

        uint256 count = 1;
        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] == ",") count++;
        }

        uint256[] memory result = new uint256[](count);
        uint256 idx = 0;
        uint256 acc = 0;
        bool hasDigit = false;

        for (uint256 i = 0; i <= b.length; i++) {
            bytes1 ch = i < b.length ? b[i] : bytes1(",");
            if (ch == ",") {
                require(hasDigit, "topics malformed (empty segment)");
                result[idx++] = acc;
                acc = 0;
                hasDigit = false;
            } else {
                require(ch >= 0x30 && ch <= 0x39, "topics must be digits and commas");
                acc = acc * 10 + (uint8(ch) - 0x30);
                hasDigit = true;
            }
        }

        return result;
    }

    function _getEAS() internal view returns (address) {
        if (block.chainid == 11155111) return EAS_SEPOLIA;
        if (block.chainid == 84532) return EAS_BASE_SEPOLIA;
        revert("EAS_ADDRESS required for this network");
    }

    function _getSchemaRegistry() internal view returns (address) {
        if (block.chainid == 11155111) return REGISTRY_SEPOLIA;
        if (block.chainid == 84532) return REGISTRY_BASE_SEPOLIA;
        revert("SCHEMA_REGISTRY env var required for this network");
    }
}
