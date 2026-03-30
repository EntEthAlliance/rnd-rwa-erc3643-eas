// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {EASClaimVerifier} from "../contracts/EASClaimVerifier.sol";
import {EASTrustedIssuersAdapter} from "../contracts/EASTrustedIssuersAdapter.sol";

/**
 * @title ConfigureBridge
 * @notice Configuration script for post-deployment setup
 * @dev Run with: forge script script/ConfigureBridge.s.sol --rpc-url $RPC_URL --broadcast
 */
contract ConfigureBridge is Script {
    // Common claim topic IDs (matching ERC-3643 conventions)
    uint256 constant TOPIC_KYC = 1;
    uint256 constant TOPIC_AML = 2;
    uint256 constant TOPIC_COUNTRY = 3;
    uint256 constant TOPIC_ACCREDITATION = 7;

    function run() external {
        // Get configuration from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address verifierAddress = vm.envAddress("VERIFIER_ADDRESS");
        address adapterAddress = vm.envAddress("ADAPTER_ADDRESS");
        address claimTopicsRegistry = vm.envAddress("CLAIM_TOPICS_REGISTRY");

        EASClaimVerifier verifier = EASClaimVerifier(verifierAddress);

        console2.log("Configuring bridge contracts...");
        console2.log("Verifier:", verifierAddress);
        console2.log("Adapter:", adapterAddress);
        // Note: adapter is configured separately via AddTrustedAttester.s.sol

        vm.startBroadcast(deployerPrivateKey);

        // Set claim topics registry
        verifier.setClaimTopicsRegistry(claimTopicsRegistry);
        console2.log("Claim topics registry set:", claimTopicsRegistry);

        // Set up schema mappings (customize these for your deployment)
        bytes32 schemaKYC = keccak256("InvestorEligibility");
        bytes32 schemaAccreditation = keccak256("Accreditation");

        verifier.setTopicSchemaMapping(TOPIC_KYC, schemaKYC);
        console2.log("Topic 1 (KYC) mapped to schema:", vm.toString(schemaKYC));

        verifier.setTopicSchemaMapping(TOPIC_ACCREDITATION, schemaAccreditation);
        console2.log("Topic 7 (Accreditation) mapped to schema:", vm.toString(schemaAccreditation));

        vm.stopBroadcast();

        console2.log("\n=== Configuration Complete ===");
        console2.log("Next step: Add trusted attesters using AddTrustedAttester.s.sol");
    }
}
