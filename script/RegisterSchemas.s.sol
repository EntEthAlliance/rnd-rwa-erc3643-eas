// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {ISchemaRegistry, SchemaRecord} from "@eas/ISchemaRegistry.sol";
import {ISchemaResolver} from "@eas/resolver/ISchemaResolver.sol";

/**
 * @title RegisterSchemas
 * @author EEA Working Group
 * @notice Registers all required EAS schemas for the EAS-ERC3643 bridge
 * @dev This script is idempotent - running multiple times is safe.
 *      Schema UIDs are deterministic based on schema string, resolver, and revocable flag.
 *
 *      Run with:
 *      forge script script/RegisterSchemas.s.sol:RegisterSchemas --rpc-url $RPC_URL --broadcast
 *
 *      Environment variables:
 *      - PRIVATE_KEY: Deployer private key
 *      - SCHEMA_REGISTRY: (optional) Schema registry address, auto-detected if not set
 */
contract RegisterSchemas is Script {
    // Known Schema Registry addresses
    address constant REGISTRY_MAINNET = 0xA7b39296258348C78294F95B872b282326A97BDF;
    address constant REGISTRY_SEPOLIA = 0x0a7E2Ff54e76B8E6659aedc9103FB21c038050D0;
    address constant REGISTRY_BASE = 0x4200000000000000000000000000000000000020;
    address constant REGISTRY_BASE_SEPOLIA = 0x4200000000000000000000000000000000000020;
    address constant REGISTRY_OPTIMISM = 0x4200000000000000000000000000000000000020;
    address constant REGISTRY_ARBITRUM = 0xA310da9c5B885E7fb3fbA9D66E9Ba6Df512b78eB;

    // Schema definitions
    string constant INVESTOR_ELIGIBILITY_SCHEMA =
        "address identity,uint8 kycStatus,uint8 accreditationType,uint16 countryCode,uint64 expirationTimestamp";

    string constant ISSUER_AUTHORIZATION_SCHEMA = "address issuerAddress,uint256[] authorizedTopics,string issuerName";

    string constant WALLET_IDENTITY_LINK_SCHEMA =
        "address walletAddress,address identityAddress,uint64 linkedTimestamp";

    // Stored UIDs after registration
    bytes32 public investorEligibilityUID;
    bytes32 public issuerAuthorizationUID;
    bytes32 public walletIdentityLinkUID;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address registryAddress = vm.envOr("SCHEMA_REGISTRY", address(0));

        if (registryAddress == address(0)) {
            registryAddress = _getSchemaRegistry();
        }

        ISchemaRegistry registry = ISchemaRegistry(registryAddress);

        console2.log("=== EAS Schema Registration ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("Schema Registry:", registryAddress);
        console2.log("");

        vm.startBroadcast(deployerPrivateKey);

        // Register Investor Eligibility Schema (core schema for KYC/AML)
        investorEligibilityUID = _registerSchemaIfNeeded(
            registry,
            INVESTOR_ELIGIBILITY_SCHEMA,
            address(0), // No resolver - validation done by bridge contracts
            true // Revocable
        );
        console2.log("Investor Eligibility Schema UID:");
        console2.logBytes32(investorEligibilityUID);

        // Register Issuer Authorization Schema
        issuerAuthorizationUID = _registerSchemaIfNeeded(registry, ISSUER_AUTHORIZATION_SCHEMA, address(0), true);
        console2.log("Issuer Authorization Schema UID:");
        console2.logBytes32(issuerAuthorizationUID);

        // Register Wallet-Identity Link Schema
        walletIdentityLinkUID = _registerSchemaIfNeeded(registry, WALLET_IDENTITY_LINK_SCHEMA, address(0), true);
        console2.log("Wallet-Identity Link Schema UID:");
        console2.logBytes32(walletIdentityLinkUID);

        vm.stopBroadcast();

        console2.log("");
        console2.log("=== Schema Registration Complete ===");
        console2.log("");
        console2.log("Save these UIDs for bridge configuration:");
        console2.log("INVESTOR_ELIGIBILITY_SCHEMA_UID=", vm.toString(investorEligibilityUID));
        console2.log("ISSUER_AUTHORIZATION_SCHEMA_UID=", vm.toString(issuerAuthorizationUID));
        console2.log("WALLET_IDENTITY_LINK_SCHEMA_UID=", vm.toString(walletIdentityLinkUID));
    }

    /**
     * @notice Registers a schema if it doesn't already exist
     * @dev Schema UID is deterministic, so we can compute it and check existence
     * @param registry The schema registry contract
     * @param schema The schema string
     * @param resolver Optional resolver address
     * @param revocable Whether attestations can be revoked
     * @return uid The schema UID (existing or newly registered)
     */
    function _registerSchemaIfNeeded(ISchemaRegistry registry, string memory schema, address resolver, bool revocable)
        internal
        returns (bytes32 uid)
    {
        // Compute expected UID (matches EAS's implementation)
        uid = keccak256(abi.encodePacked(schema, resolver, revocable));

        // Check if schema already exists by trying to get it
        // If it exists, the schema string will be non-empty
        try registry.getSchema(uid) returns (SchemaRecord memory record) {
            if (bytes(record.schema).length > 0) {
                console2.log("Schema already registered, skipping:", schema);
                return uid;
            }
        } catch {
            // Schema doesn't exist, continue to register
        }

        // Register new schema
        uid = registry.register(schema, ISchemaResolver(resolver), revocable);
        console2.log("Registered new schema:", schema);
        return uid;
    }

    /**
     * @notice Gets the Schema Registry address for the current chain
     * @return The schema registry address
     */
    function _getSchemaRegistry() internal view returns (address) {
        uint256 chainId = block.chainid;

        if (chainId == 1) return REGISTRY_MAINNET;
        if (chainId == 11155111) return REGISTRY_SEPOLIA;
        if (chainId == 8453) return REGISTRY_BASE;
        if (chainId == 84532) return REGISTRY_BASE_SEPOLIA;
        if (chainId == 10) return REGISTRY_OPTIMISM;
        if (chainId == 42161) return REGISTRY_ARBITRUM;

        revert("SCHEMA_REGISTRY environment variable required for this network");
    }
}
