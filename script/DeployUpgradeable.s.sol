// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {EASClaimVerifierUpgradeable} from "../contracts/upgradeable/EASClaimVerifierUpgradeable.sol";
import {EASTrustedIssuersAdapterUpgradeable} from "../contracts/upgradeable/EASTrustedIssuersAdapterUpgradeable.sol";
import {EASIdentityProxyUpgradeable} from "../contracts/upgradeable/EASIdentityProxyUpgradeable.sol";

/**
 * @title DeployUpgradeable
 * @notice Deployment script for UUPS-upgradeable EAS-to-ERC-3643 Bridge contracts
 * @dev Deploys implementation contracts and ERC1967 proxies for each.
 *
 * Run with: forge script script/DeployUpgradeable.s.sol --rpc-url $RPC_URL --broadcast
 *
 * Environment variables:
 * - PRIVATE_KEY: Deployer private key
 * - OWNER_ADDRESS: (optional) Owner address, defaults to deployer
 * - EAS_ADDRESS: (optional) EAS contract address, auto-detected by chain ID
 */
contract DeployUpgradeable is Script {
    // EAS contract addresses by network
    address constant EAS_MAINNET = 0xA1207F3BBa224E2c9c3c6D5aF63D0eb1582Ce587;
    address constant EAS_BASE = 0x4200000000000000000000000000000000000021;
    address constant EAS_BASE_SEPOLIA = 0x4200000000000000000000000000000000000021;
    address constant EAS_OPTIMISM = 0x4200000000000000000000000000000000000021;
    address constant EAS_ARBITRUM = 0xbD75f629A22Dc1ceD33dDA0b68c546A1c035c458;
    address constant EAS_SEPOLIA = 0xC2679fBD37d54388Ce493F1DB75320D236e1815e;

    struct DeployedContracts {
        address adapterImpl;
        address adapterProxy;
        address identityProxyImpl;
        address identityProxyProxy;
        address verifierImpl;
        address verifierProxy;
    }

    function run() external returns (DeployedContracts memory) {
        // Get deployment parameters from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address owner = vm.envOr("OWNER_ADDRESS", deployer);
        address easAddress = vm.envOr("EAS_ADDRESS", address(0));

        // Auto-detect EAS address based on chain ID if not provided
        if (easAddress == address(0)) {
            easAddress = _getEASAddress();
        }

        console2.log("=== UUPS Upgradeable Bridge Deployment ===");
        console2.log("Deployer:", deployer);
        console2.log("Owner:", owner);
        console2.log("EAS Address:", easAddress);
        console2.log("Chain ID:", block.chainid);
        console2.log("");

        vm.startBroadcast(deployerPrivateKey);

        DeployedContracts memory d = _deployContracts(owner, easAddress);

        vm.stopBroadcast();

        _logSummary(d);

        return d;
    }

    function _deployContracts(address owner, address easAddress) internal returns (DeployedContracts memory d) {
        // 1. Deploy EASTrustedIssuersAdapterUpgradeable
        console2.log("Deploying EASTrustedIssuersAdapterUpgradeable...");
        EASTrustedIssuersAdapterUpgradeable adapterImpl = new EASTrustedIssuersAdapterUpgradeable();
        d.adapterImpl = address(adapterImpl);
        console2.log("  Implementation:", d.adapterImpl);

        bytes memory adapterInitData = abi.encodeCall(EASTrustedIssuersAdapterUpgradeable.initialize, (owner));
        ERC1967Proxy adapterProxy = new ERC1967Proxy(d.adapterImpl, adapterInitData);
        d.adapterProxy = address(adapterProxy);
        console2.log("  Proxy:", d.adapterProxy);

        // 2. Deploy EASIdentityProxyUpgradeable
        console2.log("Deploying EASIdentityProxyUpgradeable...");
        EASIdentityProxyUpgradeable identityProxyImpl = new EASIdentityProxyUpgradeable();
        d.identityProxyImpl = address(identityProxyImpl);
        console2.log("  Implementation:", d.identityProxyImpl);

        bytes memory identityProxyInitData = abi.encodeCall(EASIdentityProxyUpgradeable.initialize, (owner));
        ERC1967Proxy identityProxyProxy = new ERC1967Proxy(d.identityProxyImpl, identityProxyInitData);
        d.identityProxyProxy = address(identityProxyProxy);
        console2.log("  Proxy:", d.identityProxyProxy);

        // 3. Deploy EASClaimVerifierUpgradeable
        console2.log("Deploying EASClaimVerifierUpgradeable...");
        EASClaimVerifierUpgradeable verifierImpl = new EASClaimVerifierUpgradeable();
        d.verifierImpl = address(verifierImpl);
        console2.log("  Implementation:", d.verifierImpl);

        bytes memory verifierInitData = abi.encodeCall(EASClaimVerifierUpgradeable.initialize, (owner));
        ERC1967Proxy verifierProxy = new ERC1967Proxy(d.verifierImpl, verifierInitData);
        d.verifierProxy = address(verifierProxy);
        console2.log("  Proxy:", d.verifierProxy);

        // 4. Configure verifier through proxy
        _configureVerifier(d.verifierProxy, easAddress, d.adapterProxy, d.identityProxyProxy);

        return d;
    }

    function _configureVerifier(
        address verifierProxy,
        address easAddress,
        address adapterProxy,
        address identityProxyProxy
    ) internal {
        console2.log("");
        console2.log("Configuring verifier...");
        EASClaimVerifierUpgradeable verifier = EASClaimVerifierUpgradeable(verifierProxy);
        verifier.setEASAddress(easAddress);
        console2.log("  EAS address set");

        verifier.setTrustedIssuersAdapter(adapterProxy);
        console2.log("  Trusted Issuers Adapter set");

        verifier.setIdentityProxy(identityProxyProxy);
        console2.log("  Identity Proxy set");
    }

    function _logSummary(DeployedContracts memory d) internal pure {
        console2.log("");
        console2.log("=== Deployment Summary ===");
        console2.log("EASTrustedIssuersAdapterUpgradeable:");
        console2.log("  Implementation:", d.adapterImpl);
        console2.log("  Proxy:", d.adapterProxy);
        console2.log("");
        console2.log("EASIdentityProxyUpgradeable:");
        console2.log("  Implementation:", d.identityProxyImpl);
        console2.log("  Proxy:", d.identityProxyProxy);
        console2.log("");
        console2.log("EASClaimVerifierUpgradeable:");
        console2.log("  Implementation:", d.verifierImpl);
        console2.log("  Proxy:", d.verifierProxy);
        console2.log("");
        console2.log("Next steps:");
        console2.log("1. Set claim topics registry: verifier.setClaimTopicsRegistry(address)");
        console2.log("2. Map topics to schemas: verifier.setTopicSchemaMapping(topic, schemaUID)");
        console2.log("3. Add trusted attesters: adapter.addTrustedAttester(attester, topics)");
    }

    function _getEASAddress() internal view returns (address) {
        uint256 chainId = block.chainid;

        if (chainId == 1) return EAS_MAINNET;
        if (chainId == 11155111) return EAS_SEPOLIA;
        if (chainId == 8453) return EAS_BASE;
        if (chainId == 84532) return EAS_BASE_SEPOLIA;
        if (chainId == 10) return EAS_OPTIMISM;
        if (chainId == 42161) return EAS_ARBITRUM;

        // For local/unknown networks, require explicit EAS address
        revert("EAS_ADDRESS environment variable required for this network");
    }
}

/**
 * @title UpgradeVerifier
 * @notice Script to upgrade the EASClaimVerifierUpgradeable implementation
 * @dev Run with: forge script script/DeployUpgradeable.s.sol:UpgradeVerifier --rpc-url $RPC_URL --broadcast
 *
 * Environment variables:
 * - PRIVATE_KEY: Owner private key
 * - VERIFIER_PROXY: Address of the verifier proxy
 */
contract UpgradeVerifier is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address verifierProxy = vm.envAddress("VERIFIER_PROXY");

        console2.log("=== Upgrading EASClaimVerifierUpgradeable ===");
        console2.log("Proxy:", verifierProxy);

        vm.startBroadcast(privateKey);

        // Deploy new implementation
        EASClaimVerifierUpgradeable newImpl = new EASClaimVerifierUpgradeable();
        console2.log("New implementation deployed at:", address(newImpl));

        // Upgrade proxy to new implementation
        EASClaimVerifierUpgradeable verifier = EASClaimVerifierUpgradeable(verifierProxy);
        verifier.upgradeToAndCall(address(newImpl), "");
        console2.log("Proxy upgraded successfully");

        vm.stopBroadcast();
    }
}

/**
 * @title UpgradeAdapter
 * @notice Script to upgrade the EASTrustedIssuersAdapterUpgradeable implementation
 * @dev Run with: forge script script/DeployUpgradeable.s.sol:UpgradeAdapter --rpc-url $RPC_URL --broadcast
 */
contract UpgradeAdapter is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address adapterProxy = vm.envAddress("ADAPTER_PROXY");

        console2.log("=== Upgrading EASTrustedIssuersAdapterUpgradeable ===");
        console2.log("Proxy:", adapterProxy);

        vm.startBroadcast(privateKey);

        EASTrustedIssuersAdapterUpgradeable newImpl = new EASTrustedIssuersAdapterUpgradeable();
        console2.log("New implementation deployed at:", address(newImpl));

        EASTrustedIssuersAdapterUpgradeable adapter = EASTrustedIssuersAdapterUpgradeable(adapterProxy);
        adapter.upgradeToAndCall(address(newImpl), "");
        console2.log("Proxy upgraded successfully");

        vm.stopBroadcast();
    }
}

/**
 * @title UpgradeIdentityProxy
 * @notice Script to upgrade the EASIdentityProxyUpgradeable implementation
 * @dev Run with: forge script script/DeployUpgradeable.s.sol:UpgradeIdentityProxy --rpc-url $RPC_URL --broadcast
 */
contract UpgradeIdentityProxy is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address identityProxyProxy = vm.envAddress("IDENTITY_PROXY_PROXY");

        console2.log("=== Upgrading EASIdentityProxyUpgradeable ===");
        console2.log("Proxy:", identityProxyProxy);

        vm.startBroadcast(privateKey);

        EASIdentityProxyUpgradeable newImpl = new EASIdentityProxyUpgradeable();
        console2.log("New implementation deployed at:", address(newImpl));

        EASIdentityProxyUpgradeable proxy = EASIdentityProxyUpgradeable(identityProxyProxy);
        proxy.upgradeToAndCall(address(newImpl), "");
        console2.log("Proxy upgraded successfully");

        vm.stopBroadcast();
    }
}
