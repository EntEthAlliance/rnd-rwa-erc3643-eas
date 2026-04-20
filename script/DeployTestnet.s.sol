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
 * @title DeployTestnet
 * @notice Non-gated deploy for Sepolia / Base Sepolia. Single `ADMIN_ADDRESS`
 *         holds all roles; no multisig or audit-ack required.
 * @dev Required env:
 *        PRIVATE_KEY    — deployer key
 *        ADMIN_ADDRESS  — optional; defaults to deployer if unset
 *        EAS_ADDRESS    — optional; auto-detected per chain
 */
contract DeployTestnet is Script {
    address constant EAS_SEPOLIA = 0xC2679fBD37d54388Ce493F1DB75320D236e1815e;
    address constant EAS_BASE_SEPOLIA = 0x4200000000000000000000000000000000000021;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        address admin = vm.envOr("ADMIN_ADDRESS", deployer);
        address easAddress = vm.envOr("EAS_ADDRESS", address(0));
        if (easAddress == address(0)) easAddress = _getEAS();

        console2.log("=== Testnet Deploy ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", deployer);
        console2.log("Admin:", admin);
        console2.log("EAS:", easAddress);

        vm.startBroadcast(deployerKey);

        address[] memory initialAuthorizers;
        TrustedIssuerResolver resolver = new TrustedIssuerResolver(IEAS(easAddress), admin, initialAuthorizers);

        EASTrustedIssuersAdapter adapter = new EASTrustedIssuersAdapter(admin);
        EASIdentityProxy identityProxy = new EASIdentityProxy(admin);
        EASClaimVerifier verifier = new EASClaimVerifier(admin);

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
    }

    function _getEAS() internal view returns (address) {
        if (block.chainid == 11155111) return EAS_SEPOLIA;
        if (block.chainid == 84532) return EAS_BASE_SEPOLIA;
        revert("EAS_ADDRESS required for this network");
    }
}
