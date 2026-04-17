// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {EASClaimVerifierUpgradeable} from "../contracts/upgradeable/EASClaimVerifierUpgradeable.sol";
import {EASTrustedIssuersAdapterUpgradeable} from "../contracts/upgradeable/EASTrustedIssuersAdapterUpgradeable.sol";
import {EASIdentityProxyUpgradeable} from "../contracts/upgradeable/EASIdentityProxyUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title DeployUpgradeable
 * @notice Deploys the 3 UUPS-upgradeable contracts behind ERC1967 proxies.
 * @dev Required env:
 *        PRIVATE_KEY    — deployer key
 *        ADMIN_ADDRESS  — admin on the proxies (default: deployer)
 *
 *      This script only instantiates the proxies; topic-schema mapping,
 *      topic-policy mapping, and Schema-2 UID must be configured separately
 *      by the admin.
 */
contract DeployUpgradeable is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        address admin = vm.envOr("ADMIN_ADDRESS", deployer);

        console2.log("=== UUPS Deploy ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("Admin:", admin);

        vm.startBroadcast(deployerKey);

        // Verifier
        EASClaimVerifierUpgradeable verifierImpl = new EASClaimVerifierUpgradeable();
        ERC1967Proxy verifierProxy = new ERC1967Proxy(
            address(verifierImpl), abi.encodeWithSelector(EASClaimVerifierUpgradeable.initialize.selector, admin)
        );

        // Adapter
        EASTrustedIssuersAdapterUpgradeable adapterImpl = new EASTrustedIssuersAdapterUpgradeable();
        ERC1967Proxy adapterProxy = new ERC1967Proxy(
            address(adapterImpl), abi.encodeWithSelector(EASTrustedIssuersAdapterUpgradeable.initialize.selector, admin)
        );

        // Identity Proxy
        EASIdentityProxyUpgradeable identityImpl = new EASIdentityProxyUpgradeable();
        ERC1967Proxy identityProxy = new ERC1967Proxy(
            address(identityImpl), abi.encodeWithSelector(EASIdentityProxyUpgradeable.initialize.selector, admin)
        );

        vm.stopBroadcast();

        console2.log("EASClaimVerifier impl:", address(verifierImpl));
        console2.log("EASClaimVerifier proxy:", address(verifierProxy));
        console2.log("EASTrustedIssuersAdapter impl:", address(adapterImpl));
        console2.log("EASTrustedIssuersAdapter proxy:", address(adapterProxy));
        console2.log("EASIdentityProxy impl:", address(identityImpl));
        console2.log("EASIdentityProxy proxy:", address(identityProxy));
    }
}
