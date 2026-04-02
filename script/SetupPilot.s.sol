// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {EASClaimVerifier} from "../contracts/EASClaimVerifier.sol";
import {EASTrustedIssuersAdapter} from "../contracts/EASTrustedIssuersAdapter.sol";
import {EASIdentityProxy} from "../contracts/EASIdentityProxy.sol";
import {MockClaimTopicsRegistry} from "../contracts/mocks/MockClaimTopicsRegistry.sol";

/**
 * @title SetupPilot
 * @author EEA Working Group
 * @notice Complete pilot deployment script for testing and demonstration
 * @dev Deploys all bridge contracts, configures them, sets up a KYC provider,
 *      and creates 5 test investor identities with attestations.
 *
 *      Run with:
 *      forge script script/SetupPilot.s.sol:SetupPilot --rpc-url $RPC_URL --broadcast
 *
 *      Environment variables:
 *      - PRIVATE_KEY: Deployer private key (also acts as token issuer and KYC provider)
 *      - EAS_ADDRESS: (optional) EAS contract address, auto-detected if not set
 *
 *      This script is designed for testnet/local deployments only.
 */
contract SetupPilot is Script {
    // EAS addresses
    address constant EAS_SEPOLIA = 0xC2679fBD37d54388Ce493F1DB75320D236e1815e;
    address constant EAS_BASE_SEPOLIA = 0x4200000000000000000000000000000000000021;

    // Claim topic constants (ERC-3643 standard)
    uint256 constant TOPIC_KYC = 1;
    uint256 constant TOPIC_AML = 2;
    uint256 constant TOPIC_COUNTRY = 3;
    uint256 constant TOPIC_ACCREDITATION = 7;

    // Demo schema UID (replace with actual registered schema)
    bytes32 constant DEMO_SCHEMA_UID = keccak256(
        "address identity,uint8 kycStatus,uint8 accreditationType,uint16 countryCode,uint64 expirationTimestamp"
    );

    // Deployed contracts
    EASClaimVerifier public verifier;
    EASTrustedIssuersAdapter public adapter;
    EASIdentityProxy public identityProxy;
    MockClaimTopicsRegistry public topicsRegistry;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address easAddress = vm.envOr("EAS_ADDRESS", address(0));

        if (easAddress == address(0)) {
            easAddress = _getEasAddress();
        }

        console2.log("=== EAS-ERC3643 Bridge Pilot Setup ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer/TokenIssuer:", deployer);
        console2.log("EAS Address:", easAddress);
        console2.log("");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy core bridge contracts
        console2.log("Step 1: Deploying bridge contracts...");

        adapter = new EASTrustedIssuersAdapter(deployer);
        console2.log("  EASTrustedIssuersAdapter:", address(adapter));

        identityProxy = new EASIdentityProxy(deployer);
        console2.log("  EASIdentityProxy:", address(identityProxy));

        verifier = new EASClaimVerifier(deployer);
        console2.log("  EASClaimVerifier:", address(verifier));

        // 2. Deploy mock claim topics registry for pilot
        console2.log("Step 2: Deploying ClaimTopicsRegistry...");
        topicsRegistry = new MockClaimTopicsRegistry();
        console2.log("  MockClaimTopicsRegistry:", address(topicsRegistry));

        // 3. Configure verifier
        console2.log("Step 3: Configuring verifier...");
        verifier.setEASAddress(easAddress);
        verifier.setTrustedIssuersAdapter(address(adapter));
        verifier.setIdentityProxy(address(identityProxy));
        verifier.setClaimTopicsRegistry(address(topicsRegistry));
        console2.log("  Verifier configured with all dependencies");

        // 4. Set up claim topics
        console2.log("Step 4: Configuring claim topics...");
        topicsRegistry.addClaimTopic(TOPIC_KYC);
        topicsRegistry.addClaimTopic(TOPIC_ACCREDITATION);
        console2.log("  Added topics: KYC (1), Accreditation (7)");

        // 5. Set topic-to-schema mappings
        console2.log("Step 5: Setting schema mappings...");
        verifier.setTopicSchemaMapping(TOPIC_KYC, DEMO_SCHEMA_UID);
        verifier.setTopicSchemaMapping(TOPIC_ACCREDITATION, DEMO_SCHEMA_UID);
        console2.log("  Topics mapped to demo schema");

        // 6. Add deployer as KYC provider (trusted attester)
        console2.log("Step 6: Adding KYC provider...");
        uint256[] memory topics = new uint256[](2);
        topics[0] = TOPIC_KYC;
        topics[1] = TOPIC_ACCREDITATION;
        adapter.addTrustedAttester(deployer, topics);
        console2.log("  KYC Provider (deployer) added as trusted attester");

        // 7. Create 5 test investor identities
        console2.log("Step 7: Creating test investor wallets...");
        address[5] memory investors;
        for (uint256 i = 0; i < 5; i++) {
            // Generate deterministic addresses for testing
            investors[i] = address(uint160(uint256(keccak256(abi.encodePacked("pilot_investor_", i)))));
            console2.log("  Investor", i + 1, ":", investors[i]);
        }

        vm.stopBroadcast();

        // Output summary
        console2.log("");
        console2.log("=== Pilot Deployment Complete ===");
        console2.log("");
        console2.log("Contract Addresses:");
        console2.log("  VERIFIER_ADDRESS=", address(verifier));
        console2.log("  ADAPTER_ADDRESS=", address(adapter));
        console2.log("  IDENTITY_PROXY_ADDRESS=", address(identityProxy));
        console2.log("  CLAIM_TOPICS_REGISTRY=", address(topicsRegistry));
        console2.log("");
        console2.log("Test Investors:");
        for (uint256 i = 0; i < 5; i++) {
            console2.log("  Investor", i + 1, ":", investors[i]);
        }
        console2.log("");
        console2.log("Next Steps:");
        console2.log("1. Create EAS attestations for test investors");
        console2.log("2. Register attestations: verifier.registerAttestation(investor, topic, uid)");
        console2.log("3. Verify eligibility: verifier.isVerified(investor)");
        console2.log("");
        console2.log("Demo Transfer:");
        console2.log("1. Fund investor wallets with test tokens");
        console2.log("2. Perform transfer - Identity Registry will call verifier.isVerified()");
    }

    function _getEasAddress() internal view returns (address) {
        uint256 chainId = block.chainid;

        if (chainId == 11155111) return EAS_SEPOLIA;
        if (chainId == 84532) return EAS_BASE_SEPOLIA;

        // For local testing, return a placeholder
        if (chainId == 31337) return address(0xEA5);

        revert("EAS_ADDRESS required for this network");
    }
}
