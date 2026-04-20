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
 * @title DeployMainnet
 * @notice Gated production deploy. Reverts unless `AUDIT_ACKNOWLEDGED=true` and
 *         a `MULTISIG_ADDRESS` is supplied. Grants `DEFAULT_ADMIN_ROLE` on every
 *         contract to the multisig, then renounces the deployer's admin grant.
 * @dev Required env:
 *        AUDIT_ACKNOWLEDGED = "true"
 *        PRIVATE_KEY         — deployer key (used only to execute deploy txs)
 *        MULTISIG_ADDRESS    — production admin (receives DEFAULT_ADMIN_ROLE)
 *        CLAIM_TOPICS_REGISTRY — pre-deployed Claim Topics Registry
 *        EAS_ADDRESS         — EAS on the target chain
 *
 *      Post-deploy the multisig must:
 *        1. Call the topic-schema mapping setters (needs registered schema UIDs).
 *        2. Call `setTopicPolicy` for each topic.
 *        3. Call `adapter.setIssuerAuthSchemaUID`.
 *        4. Call `resolver.addAuthorizer(...)` for every approved Schema-2 author.
 */
contract DeployMainnet is Script {
    address constant EAS_MAINNET = 0xA1207F3BBa224E2c9c3c6D5aF63D0eb1582Ce587;
    address constant EAS_BASE = 0x4200000000000000000000000000000000000021;
    address constant EAS_OPTIMISM = 0x4200000000000000000000000000000000000021;
    address constant EAS_ARBITRUM = 0xbD75f629A22Dc1ceD33dDA0b68c546A1c035c458;

    function run() external {
        string memory ackRaw = vm.envOr("AUDIT_ACKNOWLEDGED", string(""));
        require(
            keccak256(bytes(ackRaw)) == keccak256(bytes("true")),
            "Refusing to deploy: AUDIT_ACKNOWLEDGED must be 'true' (see AUDIT.md)"
        );

        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        address multisig = vm.envAddress("MULTISIG_ADDRESS");
        address claimTopicsRegistry = vm.envAddress("CLAIM_TOPICS_REGISTRY");

        address easAddress = vm.envOr("EAS_ADDRESS", address(0));
        if (easAddress == address(0)) easAddress = _getEAS();

        require(multisig != address(0), "MULTISIG_ADDRESS required");
        require(multisig != deployer, "MULTISIG_ADDRESS must not equal deployer");
        require(claimTopicsRegistry != address(0), "CLAIM_TOPICS_REGISTRY required");

        console2.log("=== Mainnet Deploy ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", deployer);
        console2.log("Multisig:", multisig);
        console2.log("EAS:", easAddress);

        vm.startBroadcast(deployerKey);

        // Resolver — deployer bootstraps, transfers ownership to multisig below.
        address[] memory initialAuthorizers;
        TrustedIssuerResolver resolver = new TrustedIssuerResolver(IEAS(easAddress), deployer, initialAuthorizers);

        // Core contracts — deployer gets admin+operator initially so we can wire up.
        EASTrustedIssuersAdapter adapter = new EASTrustedIssuersAdapter(deployer);
        EASIdentityProxy identityProxy = new EASIdentityProxy(deployer);
        EASClaimVerifier verifier = new EASClaimVerifier(deployer);

        // Basic wiring that doesn't require schema UIDs yet.
        verifier.setEASAddress(easAddress);
        verifier.setTrustedIssuersAdapter(address(adapter));
        verifier.setIdentityProxy(address(identityProxy));
        verifier.setClaimTopicsRegistry(claimTopicsRegistry);
        adapter.setEASAddress(easAddress);

        // Policies (stateless ones constructed with no args; admin-owned two take the multisig immediately).
        address kyc = address(new KYCStatusPolicy());
        address aml = address(new AMLPolicy());
        address sanc = address(new SanctionsPolicy());
        address sof = address(new SourceOfFundsPolicy());
        address prof = address(new ProfessionalInvestorPolicy());
        address inst = address(new InstitutionalInvestorPolicy());

        uint16[] memory noCountries = new uint16[](0);
        address country = address(new CountryAllowListPolicy(multisig, CountryAllowListPolicy.Mode.Allow, noCountries));
        uint8[] memory noAccreditations = new uint8[](0);
        address acc = address(new AccreditationPolicy(multisig, noAccreditations));

        // Hand all admin privileges to the multisig.
        _transferRole(verifier.DEFAULT_ADMIN_ROLE(), address(verifier), deployer, multisig);
        _transferRole(verifier.OPERATOR_ROLE(), address(verifier), deployer, multisig);
        _transferRole(adapter.DEFAULT_ADMIN_ROLE(), address(adapter), deployer, multisig);
        _transferRole(adapter.OPERATOR_ROLE(), address(adapter), deployer, multisig);
        _transferRole(identityProxy.DEFAULT_ADMIN_ROLE(), address(identityProxy), deployer, multisig);
        _transferRole(identityProxy.AGENT_ROLE(), address(identityProxy), deployer, multisig);

        // Resolver is Ownable (not AccessControl); transfer ownership explicitly.
        resolver.transferOwnership(multisig);

        vm.stopBroadcast();

        console2.log("TrustedIssuerResolver:", address(resolver));
        console2.log("EASTrustedIssuersAdapter:", address(adapter));
        console2.log("EASIdentityProxy:", address(identityProxy));
        console2.log("EASClaimVerifier:", address(verifier));
        console2.log("KYCStatusPolicy:", kyc);
        console2.log("AMLPolicy:", aml);
        console2.log("SanctionsPolicy:", sanc);
        console2.log("SourceOfFundsPolicy:", sof);
        console2.log("ProfessionalInvestorPolicy:", prof);
        console2.log("InstitutionalInvestorPolicy:", inst);
        console2.log("CountryAllowListPolicy:", country);
        console2.log("AccreditationPolicy:", acc);
        console2.log("");
        console2.log("Admin rights have been transferred to the multisig.");
        console2.log("Multisig must complete setup: setTopicSchemaMapping, setTopicPolicy,");
        console2.log("  setIssuerAuthSchemaUID on the adapter, and addAuthorizer on the resolver.");
    }

    function _transferRole(bytes32 role, address contractAddr, address from, address to) internal {
        (bool ok,) = contractAddr.call(abi.encodeWithSignature("grantRole(bytes32,address)", role, to));
        require(ok, "grantRole failed");
        (ok,) = contractAddr.call(abi.encodeWithSignature("renounceRole(bytes32,address)", role, from));
        require(ok, "renounceRole failed");
    }

    function _getEAS() internal view returns (address) {
        if (block.chainid == 1) return EAS_MAINNET;
        if (block.chainid == 8453) return EAS_BASE;
        if (block.chainid == 10) return EAS_OPTIMISM;
        if (block.chainid == 42161) return EAS_ARBITRUM;
        revert("EAS_ADDRESS required for this network");
    }
}
