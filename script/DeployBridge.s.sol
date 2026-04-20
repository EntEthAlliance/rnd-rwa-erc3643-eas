// SPDX-License-Identifier: Apache-2.0
// Copyright © 2026 Enterprise Ethereum Alliance Inc.
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {EASClaimVerifier} from "../contracts/EASClaimVerifier.sol";
import {EASTrustedIssuersAdapter} from "../contracts/EASTrustedIssuersAdapter.sol";
import {EASIdentityProxy} from "../contracts/EASIdentityProxy.sol";

import {KYCStatusPolicy} from "../contracts/policies/KYCStatusPolicy.sol";
import {AMLPolicy} from "../contracts/policies/AMLPolicy.sol";
import {SanctionsPolicy} from "../contracts/policies/SanctionsPolicy.sol";
import {SourceOfFundsPolicy} from "../contracts/policies/SourceOfFundsPolicy.sol";
import {ProfessionalInvestorPolicy} from "../contracts/policies/ProfessionalInvestorPolicy.sol";
import {InstitutionalInvestorPolicy} from "../contracts/policies/InstitutionalInvestorPolicy.sol";
import {CountryAllowListPolicy} from "../contracts/policies/CountryAllowListPolicy.sol";
import {AccreditationPolicy} from "../contracts/policies/AccreditationPolicy.sol";

import {TrustedIssuerResolver} from "../contracts/resolvers/TrustedIssuerResolver.sol";
import {IEAS} from "@eas/IEAS.sol";

/**
 * @title DeployBridge
 * @notice Deploys the post-refactor Shibui stack: resolver, core contracts, and
 *         all 8 topic policies, then wires them to a single `ADMIN_ADDRESS`.
 * @dev Post-deploy, call `RegisterSchemas` with `ISSUER_AUTH_RESOLVER` set to
 *      the resolver address printed by this script, then run `setTopicSchemaMapping`
 *      and `setIssuerAuthSchemaUID` with the resulting Schema UIDs.
 *
 *      Env:
 *        PRIVATE_KEY    deployer key
 *        ADMIN_ADDRESS  receives DEFAULT_ADMIN_ROLE + OPERATOR_ROLE/AGENT_ROLE
 *                       on all deployed contracts (expected: multisig in prod)
 *        EAS_ADDRESS    overrides per-chain EAS address lookup
 */
contract DeployBridge is Script {
    address constant EAS_MAINNET = 0xA1207F3BBa224E2c9c3c6D5aF63D0eb1582Ce587;
    address constant EAS_BASE = 0x4200000000000000000000000000000000000021;
    address constant EAS_BASE_SEPOLIA = 0x4200000000000000000000000000000000000021;
    address constant EAS_OPTIMISM = 0x4200000000000000000000000000000000000021;
    address constant EAS_ARBITRUM = 0xbD75f629A22Dc1ceD33dDA0b68c546A1c035c458;
    address constant EAS_SEPOLIA = 0xC2679fBD37d54388Ce493F1DB75320D236e1815e;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address admin = vm.envOr("ADMIN_ADDRESS", deployer);
        address easAddress = vm.envOr("EAS_ADDRESS", address(0));
        if (easAddress == address(0)) easAddress = _getEASAddress();

        console2.log("Deployer:", deployer);
        console2.log("Admin:", admin);
        console2.log("EAS:", easAddress);
        console2.log("Chain ID:", block.chainid);

        vm.startBroadcast(deployerPrivateKey);

        // 1. TrustedIssuerResolver (for Schema 2 gating)
        address[] memory initialAuthorizers;
        TrustedIssuerResolver resolver = new TrustedIssuerResolver(IEAS(easAddress), admin, initialAuthorizers);
        console2.log("TrustedIssuerResolver:", address(resolver));

        // 2. Core contracts
        EASTrustedIssuersAdapter adapter = new EASTrustedIssuersAdapter(admin);
        EASIdentityProxy identityProxy = new EASIdentityProxy(admin);
        EASClaimVerifier verifier = new EASClaimVerifier(admin);

        console2.log("EASTrustedIssuersAdapter:", address(adapter));
        console2.log("EASIdentityProxy:", address(identityProxy));
        console2.log("EASClaimVerifier:", address(verifier));

        // 3. Policies
        address kyc = address(new KYCStatusPolicy());
        address aml = address(new AMLPolicy());
        address sanc = address(new SanctionsPolicy());
        address sof = address(new SourceOfFundsPolicy());
        address prof = address(new ProfessionalInvestorPolicy());
        address inst = address(new InstitutionalInvestorPolicy());

        uint16[] memory defaultCountries = new uint16[](0);
        address country =
            address(new CountryAllowListPolicy(admin, CountryAllowListPolicy.Mode.Allow, defaultCountries));

        uint8[] memory defaultAccreditations = new uint8[](0);
        address acc = address(new AccreditationPolicy(admin, defaultAccreditations));

        console2.log("KYCStatusPolicy:", kyc);
        console2.log("AMLPolicy:", aml);
        console2.log("SanctionsPolicy:", sanc);
        console2.log("SourceOfFundsPolicy:", sof);
        console2.log("ProfessionalInvestorPolicy:", prof);
        console2.log("InstitutionalInvestorPolicy:", inst);
        console2.log("CountryAllowListPolicy:", country);
        console2.log("AccreditationPolicy:", acc);

        vm.stopBroadcast();

        console2.log("");
        console2.log("Next steps:");
        console2.log("1. forge script script/RegisterSchemas.s.sol --rpc-url $RPC_URL --broadcast \\");
        console2.log("     --env ISSUER_AUTH_RESOLVER=%s", address(resolver));
        console2.log("2. admin calls verifier.setEASAddress(EAS), setTrustedIssuersAdapter(adapter),");
        console2.log("   setIdentityProxy(identityProxy), setClaimTopicsRegistry(registry).");
        console2.log("3. admin calls adapter.setEASAddress(EAS), setIssuerAuthSchemaUID(schema2UID).");
        console2.log("4. admin calls verifier.setTopicSchemaMapping(topicId, schema1UID) for each topic.");
        console2.log("5. admin calls verifier.setTopicPolicy(topicId, policyAddress) for each topic.");
        console2.log("6. admin calls resolver.addAuthorizer(authorizerAddress) for approved writers of Schema 2.");
    }

    function _getEASAddress() internal view returns (address) {
        uint256 chainId = block.chainid;
        if (chainId == 1) return EAS_MAINNET;
        if (chainId == 8453) return EAS_BASE;
        if (chainId == 84532) return EAS_BASE_SEPOLIA;
        if (chainId == 10) return EAS_OPTIMISM;
        if (chainId == 42161) return EAS_ARBITRUM;
        if (chainId == 11155111) return EAS_SEPOLIA;
        revert("EAS_ADDRESS env var required for this network");
    }
}
