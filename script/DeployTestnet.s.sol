// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {EASClaimVerifier} from "../contracts/EASClaimVerifier.sol";
import {EASTrustedIssuersAdapter} from "../contracts/EASTrustedIssuersAdapter.sol";
import {EASIdentityProxy} from "../contracts/EASIdentityProxy.sol";

/**
 * @title DeployTestnet
 * @author EEA Working Group
 * @notice Deployment script for Sepolia and other testnets
 * @dev Deploys the EAS-ERC3643 bridge with testnet-appropriate configuration.
 *      Includes test data setup for integration testing.
 *
 *      Run with:
 *      forge script script/DeployTestnet.s.sol:DeployTestnet --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
 *
 *      Environment variables:
 *      - PRIVATE_KEY: Deployer private key
 *      - OWNER_ADDRESS: (optional) Bridge owner, defaults to deployer
 *      - CLAIM_TOPICS_REGISTRY: (optional) Existing registry address
 *      - ETHERSCAN_API_KEY: For contract verification
 */
contract DeployTestnet is Script {
    // Sepolia EAS addresses
    address constant EAS_SEPOLIA = 0xC2679fBD37d54388Ce493F1DB75320D236e1815e;
    address constant SCHEMA_REGISTRY_SEPOLIA = 0x0a7E2Ff54e76B8E6659aedc9103FB21c038050D0;

    // Base Sepolia EAS addresses
    address constant EAS_BASE_SEPOLIA = 0x4200000000000000000000000000000000000021;
    address constant SCHEMA_REGISTRY_BASE_SEPOLIA = 0x4200000000000000000000000000000000000020;

    // Claim topic constants
    uint256 constant TOPIC_KYC = 1;
    uint256 constant TOPIC_AML = 2;
    uint256 constant TOPIC_COUNTRY = 3;
    uint256 constant TOPIC_ACCREDITATION = 7;

    // Standard schema for investor eligibility
    bytes32 constant INVESTOR_ELIGIBILITY_SCHEMA_UID = keccak256(
        "address identity,uint8 kycStatus,uint8 accreditationType,uint16 countryCode,uint64 expirationTimestamp"
    );

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address owner = vm.envOr("OWNER_ADDRESS", deployer);
        address claimTopicsRegistry = vm.envOr("CLAIM_TOPICS_REGISTRY", address(0));

        (address easAddress,) = _getNetworkConfig();

        console2.log("=== EAS-ERC3643 Bridge Testnet Deployment ===");
        console2.log("Network:", _getNetworkName());
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", deployer);
        console2.log("Owner:", owner);
        console2.log("EAS:", easAddress);
        console2.log("");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy contracts
        console2.log("Deploying contracts...");

        EASTrustedIssuersAdapter adapter = new EASTrustedIssuersAdapter(owner);
        console2.log("EASTrustedIssuersAdapter:", address(adapter));

        EASIdentityProxy identityProxy = new EASIdentityProxy(owner);
        console2.log("EASIdentityProxy:", address(identityProxy));

        EASClaimVerifier verifier = new EASClaimVerifier(owner);
        console2.log("EASClaimVerifier:", address(verifier));

        // Configure verifier
        console2.log("");
        console2.log("Configuring verifier...");

        verifier.setEASAddress(easAddress);
        console2.log("  EAS address set");

        verifier.setTrustedIssuersAdapter(address(adapter));
        console2.log("  Adapter set");

        verifier.setIdentityProxy(address(identityProxy));
        console2.log("  Identity proxy set");

        if (claimTopicsRegistry != address(0)) {
            verifier.setClaimTopicsRegistry(claimTopicsRegistry);
            console2.log("  Claim topics registry set:", claimTopicsRegistry);
        }

        // Set default schema mappings for testnet
        console2.log("");
        console2.log("Setting default schema mappings...");

        verifier.setTopicSchemaMapping(TOPIC_KYC, INVESTOR_ELIGIBILITY_SCHEMA_UID);
        verifier.setTopicSchemaMapping(TOPIC_AML, INVESTOR_ELIGIBILITY_SCHEMA_UID);
        verifier.setTopicSchemaMapping(TOPIC_COUNTRY, INVESTOR_ELIGIBILITY_SCHEMA_UID);
        verifier.setTopicSchemaMapping(TOPIC_ACCREDITATION, INVESTOR_ELIGIBILITY_SCHEMA_UID);
        console2.log("  Topics 1,2,3,7 mapped to investor eligibility schema");

        vm.stopBroadcast();

        // Output deployment info
        console2.log("");
        console2.log("=== Deployment Complete ===");
        console2.log("");
        console2.log("Export these environment variables:");
        console2.log("");
        console2.log("export VERIFIER_ADDRESS=", address(verifier));
        console2.log("export ADAPTER_ADDRESS=", address(adapter));
        console2.log("export IDENTITY_PROXY_ADDRESS=", address(identityProxy));
        console2.log("");
        console2.log("Next steps:");
        console2.log("1. Set claim topics registry (if not already set)");
        console2.log("2. Add trusted attesters via AddTrustedAttester.s.sol");
        console2.log("3. Register actual schema UIDs via ConfigureBridge.s.sol");
        console2.log("");
        console2.log("Verify contracts on Etherscan:");
        console2.log("forge verify-contract", address(verifier), "EASClaimVerifier --chain", _getNetworkName());
    }

    function _getNetworkConfig() internal view returns (address eas, address schemaRegistry) {
        uint256 chainId = block.chainid;

        if (chainId == 11155111) {
            return (EAS_SEPOLIA, SCHEMA_REGISTRY_SEPOLIA);
        }
        if (chainId == 84532) {
            return (EAS_BASE_SEPOLIA, SCHEMA_REGISTRY_BASE_SEPOLIA);
        }

        revert("Unsupported testnet. Use DeployBridge.s.sol for other networks.");
    }

    function _getNetworkName() internal view returns (string memory) {
        uint256 chainId = block.chainid;

        if (chainId == 11155111) return "sepolia";
        if (chainId == 84532) return "base-sepolia";

        return "unknown";
    }
}
