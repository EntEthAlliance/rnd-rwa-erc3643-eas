// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {ISchemaRegistry, SchemaRecord} from "@eas/ISchemaRegistry.sol";
import {ISchemaResolver} from "@eas/resolver/ISchemaResolver.sol";

/**
 * @title RegisterSchemas
 * @notice Registers the Shibui EAS schemas (Investor Eligibility v2 + Issuer Authorization).
 * @dev Post-refactor:
 *        - Investor Eligibility is v2 with evidenceHash and verificationMethod
 *          fields (audit C-7). The new schema UID differs from v1; there is no
 *          production v1 deployment so no dual-accept period is required.
 *        - Issuer Authorization is registered with the TrustedIssuerResolver
 *          address (audit C-5). Pass it via the `ISSUER_AUTH_RESOLVER` env var.
 *          The Wallet-Identity Link schema is deferred (V2 roadmap).
 */
contract RegisterSchemas is Script {
    address constant REGISTRY_MAINNET = 0xA7b39296258348C78294F95B872b282326A97BDF;
    address constant REGISTRY_SEPOLIA = 0x0a7E2Ff54e76B8E6659aedc9103FB21c038050D0;
    address constant REGISTRY_BASE = 0x4200000000000000000000000000000000000020;
    address constant REGISTRY_BASE_SEPOLIA = 0x4200000000000000000000000000000000000020;
    address constant REGISTRY_OPTIMISM = 0x4200000000000000000000000000000000000020;
    address constant REGISTRY_ARBITRUM = 0xA310da9c5B885E7fb3fbA9D66E9Ba6Df512b78eB;

    /// @notice Schema 1 v2 string (must match abi.encode layout in MockAttester / TopicPolicyBase).
    string constant INVESTOR_ELIGIBILITY_SCHEMA =
        "address identity,uint8 kycStatus,uint8 amlStatus,uint8 sanctionsStatus,uint8 sourceOfFundsStatus,uint8 accreditationType,uint16 countryCode,uint64 expirationTimestamp,bytes32 evidenceHash,uint8 verificationMethod";

    string constant ISSUER_AUTHORIZATION_SCHEMA = "address issuerAddress,uint256[] authorizedTopics,string issuerName";

    bytes32 public investorEligibilityUID;
    bytes32 public issuerAuthorizationUID;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address registryAddress = vm.envOr("SCHEMA_REGISTRY", address(0));
        address trustedIssuerResolver = vm.envOr("ISSUER_AUTH_RESOLVER", address(0));

        if (registryAddress == address(0)) registryAddress = _getSchemaRegistry();
        require(trustedIssuerResolver != address(0), "ISSUER_AUTH_RESOLVER env var required");

        ISchemaRegistry registry = ISchemaRegistry(registryAddress);

        console2.log("=== EAS Schema Registration ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("Schema Registry:", registryAddress);
        console2.log("Trusted Issuer Resolver:", trustedIssuerResolver);
        console2.log("");

        vm.startBroadcast(deployerPrivateKey);

        // Investor Eligibility v2 — no resolver; policy modules enforce payload at verify time.
        investorEligibilityUID = _registerSchemaIfNeeded(registry, INVESTOR_ELIGIBILITY_SCHEMA, address(0), true);
        console2.log("Investor Eligibility v2 UID:");
        console2.logBytes32(investorEligibilityUID);

        // Issuer Authorization — resolver-gated (TrustedIssuerResolver).
        issuerAuthorizationUID =
            _registerSchemaIfNeeded(registry, ISSUER_AUTHORIZATION_SCHEMA, trustedIssuerResolver, true);
        console2.log("Issuer Authorization UID:");
        console2.logBytes32(issuerAuthorizationUID);

        vm.stopBroadcast();

        console2.log("");
        console2.log("=== Schema Registration Complete ===");
        console2.log("INVESTOR_ELIGIBILITY_SCHEMA_UID=", vm.toString(investorEligibilityUID));
        console2.log("ISSUER_AUTHORIZATION_SCHEMA_UID=", vm.toString(issuerAuthorizationUID));
    }

    function _registerSchemaIfNeeded(ISchemaRegistry registry, string memory schema, address resolver, bool revocable)
        internal
        returns (bytes32 uid)
    {
        uid = keccak256(abi.encodePacked(schema, resolver, revocable));

        try registry.getSchema(uid) returns (SchemaRecord memory record) {
            if (bytes(record.schema).length > 0) {
                console2.log("Schema already registered, skipping");
                return uid;
            }
        } catch {}

        uid = registry.register(schema, ISchemaResolver(resolver), revocable);
        console2.log("Registered new schema");
    }

    function _getSchemaRegistry() internal view returns (address) {
        uint256 chainId = block.chainid;
        if (chainId == 1) return REGISTRY_MAINNET;
        if (chainId == 11155111) return REGISTRY_SEPOLIA;
        if (chainId == 8453) return REGISTRY_BASE;
        if (chainId == 84532) return REGISTRY_BASE_SEPOLIA;
        if (chainId == 10) return REGISTRY_OPTIMISM;
        if (chainId == 42161) return REGISTRY_ARBITRUM;
        revert("SCHEMA_REGISTRY env var required for this network");
    }
}
