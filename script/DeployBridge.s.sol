// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {EASClaimVerifier} from "../contracts/EASClaimVerifier.sol";
import {EASTrustedIssuersAdapter} from "../contracts/EASTrustedIssuersAdapter.sol";
import {EASIdentityProxy} from "../contracts/EASIdentityProxy.sol";

/**
 * @title DeployBridge
 * @notice Deployment script for the EAS-to-ERC-3643 Bridge contracts
 * @dev Run with: forge script script/DeployBridge.s.sol --rpc-url $RPC_URL --broadcast
 */
contract DeployBridge is Script {
    // EAS contract addresses by network
    address constant EAS_MAINNET = 0xA1207F3BBa224E2c9c3c6D5aF63D0eb1582Ce587;
    address constant EAS_BASE = 0x4200000000000000000000000000000000000021;
    address constant EAS_BASE_SEPOLIA = 0x4200000000000000000000000000000000000021;
    address constant EAS_OPTIMISM = 0x4200000000000000000000000000000000000021;
    address constant EAS_ARBITRUM = 0xbD75f629A22Dc1ceD33dDA0b68c546A1c035c458;

    function run() external {
        // Get deployment parameters from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address owner = vm.envOr("OWNER_ADDRESS", deployer);
        address easAddress = vm.envOr("EAS_ADDRESS", address(0));

        // Auto-detect EAS address based on chain ID if not provided
        if (easAddress == address(0)) {
            easAddress = _getEASAddress();
        }

        console2.log("Deployer:", deployer);
        console2.log("Owner:", owner);
        console2.log("EAS Address:", easAddress);
        console2.log("Chain ID:", block.chainid);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy core contracts
        EASTrustedIssuersAdapter adapter = new EASTrustedIssuersAdapter(owner);
        console2.log("EASTrustedIssuersAdapter deployed at:", address(adapter));

        EASIdentityProxy identityProxy = new EASIdentityProxy(owner);
        console2.log("EASIdentityProxy deployed at:", address(identityProxy));

        EASClaimVerifier verifier = new EASClaimVerifier(owner);
        console2.log("EASClaimVerifier deployed at:", address(verifier));

        // Configure verifier
        verifier.setEASAddress(easAddress);
        verifier.setTrustedIssuersAdapter(address(adapter));
        verifier.setIdentityProxy(address(identityProxy));

        console2.log("Verifier configured with EAS and adapters");

        vm.stopBroadcast();

        // Log deployment summary
        console2.log("\n=== Deployment Summary ===");
        console2.log("EASTrustedIssuersAdapter:", address(adapter));
        console2.log("EASIdentityProxy:", address(identityProxy));
        console2.log("EASClaimVerifier:", address(verifier));
        console2.log("");
        console2.log("Next steps:");
        console2.log("1. Set claim topics registry: verifier.setClaimTopicsRegistry(address)");
        console2.log("2. Map topics to schemas: verifier.setTopicSchemaMapping(topic, schemaUID)");
        console2.log("3. Add trusted attesters: adapter.addTrustedAttester(attester, topics)");
    }

    function _getEASAddress() internal view returns (address) {
        uint256 chainId = block.chainid;

        if (chainId == 1) return EAS_MAINNET;
        if (chainId == 8453) return EAS_BASE;
        if (chainId == 84532) return EAS_BASE_SEPOLIA;
        if (chainId == 10) return EAS_OPTIMISM;
        if (chainId == 42161) return EAS_ARBITRUM;

        // For local/unknown networks, require explicit EAS address
        revert("EAS_ADDRESS environment variable required for this network");
    }
}
