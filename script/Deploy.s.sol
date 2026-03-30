// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {EASClaimVerifier} from "../contracts/EASClaimVerifier.sol";
import {EASTrustedIssuersAdapter} from "../contracts/EASTrustedIssuersAdapter.sol";
import {EASIdentityProxy} from "../contracts/EASIdentityProxy.sol";

/**
 * @title DeployBridge
 * @notice Deployment script for the EAS-to-ERC-3643 bridge contracts
 * @dev Run with: forge script script/Deploy.s.sol:DeployBridge --rpc-url <RPC_URL> --broadcast
 *
 * Environment variables required:
 * - PRIVATE_KEY: Deployer private key
 * - TOKEN_ISSUER: Address of the token issuer (owner of bridge contracts)
 * - EAS_ADDRESS: Address of the EAS contract on the target network
 * - CLAIM_TOPICS_REGISTRY: Address of the ClaimTopicsRegistry contract
 */
contract DeployBridge is Script {
    // Known EAS contract addresses
    address constant EAS_SEPOLIA = 0xC2679fBD37d54388Ce493F1DB75320D236e1815e;
    address constant EAS_MAINNET = 0xA1207F3BBa224E2c9c3c6D5aF63D0eb1582Ce587;
    address constant EAS_BASE = 0x4200000000000000000000000000000000000021;
    address constant EAS_ARBITRUM = 0xbD75f629A22Dc1ceD33dDA0b68c546A1c035c458;
    address constant EAS_OPTIMISM = 0x4200000000000000000000000000000000000021;

    function run() external {
        // Load configuration from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address tokenIssuer = vm.envAddress("TOKEN_ISSUER");
        address easAddress = vm.envOr("EAS_ADDRESS", address(0));
        address claimTopicsRegistry = vm.envOr("CLAIM_TOPICS_REGISTRY", address(0));

        // Auto-detect EAS address based on chain ID
        if (easAddress == address(0)) {
            easAddress = _getEASAddress(block.chainid);
        }

        console.log("Deploying EAS-to-ERC-3643 Bridge");
        console.log("================================");
        console.log("Chain ID:", block.chainid);
        console.log("Token Issuer:", tokenIssuer);
        console.log("EAS Address:", easAddress);
        console.log("Claim Topics Registry:", claimTopicsRegistry);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy EASTrustedIssuersAdapter
        EASTrustedIssuersAdapter adapter = new EASTrustedIssuersAdapter(tokenIssuer);
        console.log("EASTrustedIssuersAdapter deployed at:", address(adapter));

        // Deploy EASIdentityProxy
        EASIdentityProxy identityProxy = new EASIdentityProxy(tokenIssuer);
        console.log("EASIdentityProxy deployed at:", address(identityProxy));

        // Deploy EASClaimVerifier
        EASClaimVerifier verifier = new EASClaimVerifier(tokenIssuer);
        console.log("EASClaimVerifier deployed at:", address(verifier));

        // Configure verifier (only if addresses are provided)
        if (easAddress != address(0)) {
            verifier.setEASAddress(easAddress);
            console.log("EAS address configured");
        }

        verifier.setTrustedIssuersAdapter(address(adapter));
        console.log("Trusted Issuers Adapter configured");

        verifier.setIdentityProxy(address(identityProxy));
        console.log("Identity Proxy configured");

        if (claimTopicsRegistry != address(0)) {
            verifier.setClaimTopicsRegistry(claimTopicsRegistry);
            console.log("Claim Topics Registry configured");
        }

        vm.stopBroadcast();

        console.log("");
        console.log("Deployment complete!");
        console.log("");
        console.log("Next steps:");
        console.log("1. Set topic-to-schema mappings: verifier.setTopicSchemaMapping(topic, schemaUID)");
        console.log("2. Add trusted attesters: adapter.addTrustedAttester(attester, topics)");
        console.log("3. Configure claim topics registry if not done");
    }

    function _getEASAddress(uint256 chainId) internal pure returns (address) {
        if (chainId == 1) return EAS_MAINNET;
        if (chainId == 11155111) return EAS_SEPOLIA;
        if (chainId == 8453) return EAS_BASE;
        if (chainId == 42161) return EAS_ARBITRUM;
        if (chainId == 10) return EAS_OPTIMISM;
        return address(0);
    }
}

/**
 * @title ConfigureBridge
 * @notice Script to configure an already deployed bridge
 * @dev Run with: forge script script/Deploy.s.sol:ConfigureBridge --rpc-url <RPC_URL> --broadcast
 *
 * Environment variables required:
 * - PRIVATE_KEY: Owner private key
 * - VERIFIER_ADDRESS: Address of deployed EASClaimVerifier
 * - ADAPTER_ADDRESS: Address of deployed EASTrustedIssuersAdapter
 * - SCHEMA_UID: Schema UID for investor eligibility
 * - ATTESTER_ADDRESS: Address of trusted attester to add
 */
contract ConfigureBridge is Script {
    // Standard claim topics
    uint256 constant TOPIC_KYC = 1;
    uint256 constant TOPIC_ACCREDITATION = 7;
    uint256 constant TOPIC_COUNTRY = 3;

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address verifierAddress = vm.envAddress("VERIFIER_ADDRESS");
        address adapterAddress = vm.envAddress("ADAPTER_ADDRESS");
        bytes32 schemaUID = vm.envBytes32("SCHEMA_UID");
        address attesterAddress = vm.envOr("ATTESTER_ADDRESS", address(0));

        EASClaimVerifier verifier = EASClaimVerifier(verifierAddress);
        EASTrustedIssuersAdapter adapter = EASTrustedIssuersAdapter(adapterAddress);

        console.log("Configuring EAS-to-ERC-3643 Bridge");
        console.log("==================================");

        vm.startBroadcast(privateKey);

        // Set schema mappings
        verifier.setTopicSchemaMapping(TOPIC_KYC, schemaUID);
        console.log("Set KYC topic schema mapping");

        verifier.setTopicSchemaMapping(TOPIC_ACCREDITATION, schemaUID);
        console.log("Set Accreditation topic schema mapping");

        verifier.setTopicSchemaMapping(TOPIC_COUNTRY, schemaUID);
        console.log("Set Country topic schema mapping");

        // Add trusted attester if provided
        if (attesterAddress != address(0)) {
            uint256[] memory topics = new uint256[](3);
            topics[0] = TOPIC_KYC;
            topics[1] = TOPIC_ACCREDITATION;
            topics[2] = TOPIC_COUNTRY;

            adapter.addTrustedAttester(attesterAddress, topics);
            console.log("Added trusted attester:", attesterAddress);
        }

        vm.stopBroadcast();

        console.log("");
        console.log("Configuration complete!");
    }
}

/**
 * @title RegisterSchema
 * @notice Script to register EAS schemas
 * @dev Run with: forge script script/Deploy.s.sol:RegisterSchema --rpc-url <RPC_URL> --broadcast
 *
 * Note: This requires EAS SDK interaction. The schema registration is typically
 * done via the EAS SDK, not direct contract calls. This script shows the schema
 * definition for reference.
 */
contract RegisterSchema is Script {
    // Investor Eligibility Schema
    string constant INVESTOR_ELIGIBILITY_SCHEMA =
        "address identity, uint8 kycStatus, uint8 accreditationType, uint16 countryCode, uint64 expirationTimestamp";

    // Issuer Authorization Schema
    string constant ISSUER_AUTHORIZATION_SCHEMA =
        "address issuerAddress, uint256[] authorizedTopics, string issuerName";

    // Wallet-Identity Link Schema
    string constant WALLET_IDENTITY_LINK_SCHEMA =
        "address walletAddress, address identityAddress, uint64 linkedTimestamp";

    function run() external pure {
        console.log("EAS Schema Definitions");
        console.log("======================");
        console.log("");
        console.log("Register these schemas via EAS SDK or EAS web interface:");
        console.log("");
        console.log("1. Investor Eligibility Schema:");
        console.log(INVESTOR_ELIGIBILITY_SCHEMA);
        console.log("");
        console.log("2. Issuer Authorization Schema:");
        console.log(ISSUER_AUTHORIZATION_SCHEMA);
        console.log("");
        console.log("3. Wallet-Identity Link Schema:");
        console.log(WALLET_IDENTITY_LINK_SCHEMA);
        console.log("");
        console.log("Schema Registration Steps:");
        console.log("1. Go to https://easscan.org/schema/create");
        console.log("2. Enter the schema string");
        console.log("3. Set resolver (optional, use TrustedIssuersAdapter for Investor Eligibility)");
        console.log("4. Set revocable = true");
        console.log("5. Submit transaction");
        console.log("6. Record the schema UID for configuration");
    }
}
