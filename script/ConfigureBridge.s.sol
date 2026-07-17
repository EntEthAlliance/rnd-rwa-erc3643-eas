// SPDX-License-Identifier: Apache-2.0
// Copyright © 2026 Enterprise Ethereum Alliance Inc.
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {EASClaimVerifier} from "../contracts/EASClaimVerifier.sol";
import {EASTrustedIssuersAdapter} from "../contracts/EASTrustedIssuersAdapter.sol";
import {ClaimTopicsRegistry} from "../contracts/ClaimTopicsRegistry.sol";

/**
 * @title ConfigureBridge
 * @notice Idempotent post-deploy wiring. Covers the FULL configuration surface
 *         `isVerified()` requires — dependency wiring, claim topics,
 *         topic-schema mapping, topic-policy mapping, and the Schema-2 UID.
 *
 * @dev The previous version of this script only set topic-schema and
 *      topic-policy mappings. The verifier's dependency wiring
 *      (`setEASAddress`, `setTrustedIssuersAdapter`, `setIdentityProxy`,
 *      `setClaimTopicsRegistry`) and the adapter's EAS address existed only in
 *      `SetupPilot` (anvil/MockEAS only), so the 2026-07-17 Sepolia deployment
 *      went live with all four verifier dependencies unset — every
 *      `isVerified()` call reverted `EASNotConfigured`. This script now owns
 *      that wiring so a single re-run repairs an unwired deployment.
 *
 *      Run by a key holding OPERATOR_ROLE on the verifier and registry and
 *      DEFAULT_ADMIN_ROLE on the adapter (on testnet the deploy admin holds
 *      all three). Every setter is safe to re-run.
 *
 *      Required env:
 *        PRIVATE_KEY                     — operator key
 *        VERIFIER_ADDRESS                — EASClaimVerifier (or its proxy)
 *        ADAPTER_ADDRESS                 — EASTrustedIssuersAdapter
 *        IDENTITY_PROXY_ADDRESS          — EASIdentityProxy
 *        INVESTOR_ELIGIBILITY_SCHEMA_UID — from RegisterSchemas
 *        ISSUER_AUTHORIZATION_SCHEMA_UID — from RegisterSchemas
 *        REQUIRED_TOPICS                 — comma-separated topic IDs the token
 *                                          enforces, e.g. "1,2,13"
 *
 *      Optional env:
 *        EAS_ADDRESS            — auto-detected on Sepolia / Base Sepolia
 *        CLAIM_TOPICS_REGISTRY  — existing registry; when unset a new
 *                                 ClaimTopicsRegistry is deployed (repair path
 *                                 for networks where it is still 0x0)
 *        KYC_POLICY, AML_POLICY, SANCTIONS_POLICY, SOF_POLICY,
 *        PROFESSIONAL_POLICY, INSTITUTIONAL_POLICY, COUNTRY_POLICY,
 *        ACCREDITATION_POLICY   — each optional; skipped if unset.
 */
contract ConfigureBridge is Script {
    uint256 constant TOPIC_KYC = 1;
    uint256 constant TOPIC_AML = 2;
    uint256 constant TOPIC_COUNTRY = 3;
    uint256 constant TOPIC_ACCREDITATION = 7;
    uint256 constant TOPIC_PROFESSIONAL = 9;
    uint256 constant TOPIC_INSTITUTIONAL = 10;
    uint256 constant TOPIC_SANCTIONS = 13;
    uint256 constant TOPIC_SOURCE_OF_FUNDS = 14;

    address constant EAS_SEPOLIA = 0xC2679fBD37d54388Ce493F1DB75320D236e1815e;
    address constant EAS_BASE_SEPOLIA = 0x4200000000000000000000000000000000000021;

    function run() external {
        uint256 key = vm.envUint("PRIVATE_KEY");
        EASClaimVerifier verifier = EASClaimVerifier(vm.envAddress("VERIFIER_ADDRESS"));
        EASTrustedIssuersAdapter adapter = EASTrustedIssuersAdapter(vm.envAddress("ADAPTER_ADDRESS"));
        address identityProxy = vm.envAddress("IDENTITY_PROXY_ADDRESS");

        address easAddress = vm.envOr("EAS_ADDRESS", address(0));
        if (easAddress == address(0)) easAddress = _getEAS();

        bytes32 invSchema = vm.envBytes32("INVESTOR_ELIGIBILITY_SCHEMA_UID");
        bytes32 authSchema = vm.envBytes32("ISSUER_AUTHORIZATION_SCHEMA_UID");
        uint256[] memory requiredTopics = _parseTopics(vm.envString("REQUIRED_TOPICS"));
        require(requiredTopics.length > 0, "REQUIRED_TOPICS env var required (e.g. '1,2,13')");

        vm.startBroadcast(key);

        console2.log("--- Claim topics registry ---");
        address registryAddr = vm.envOr("CLAIM_TOPICS_REGISTRY", address(0));
        ClaimTopicsRegistry topicsRegistry;
        if (registryAddr == address(0)) {
            topicsRegistry = new ClaimTopicsRegistry(vm.addr(key));
            console2.log("Deployed new ClaimTopicsRegistry:", address(topicsRegistry));
        } else {
            topicsRegistry = ClaimTopicsRegistry(registryAddr);
            console2.log("Using existing ClaimTopicsRegistry:", registryAddr);
        }

        for (uint256 i = 0; i < requiredTopics.length; i++) {
            if (!topicsRegistry.hasClaimTopic(requiredTopics[i])) {
                topicsRegistry.addClaimTopic(requiredTopics[i]);
                console2.log("Required topic added:", requiredTopics[i]);
            } else {
                console2.log("Required topic already set:", requiredTopics[i]);
            }
        }

        console2.log("--- Verifier dependency wiring ---");
        verifier.setEASAddress(easAddress);
        verifier.setTrustedIssuersAdapter(address(adapter));
        verifier.setIdentityProxy(identityProxy);
        verifier.setClaimTopicsRegistry(address(topicsRegistry));
        console2.log("Verifier wired: EAS, adapter, identity proxy, topics registry");

        console2.log("--- Adapter wiring ---");
        adapter.setEASAddress(easAddress);
        adapter.setIssuerAuthSchemaUID(authSchema);

        console2.log("--- Topic-schema mapping ---");
        verifier.setTopicSchemaMapping(TOPIC_KYC, invSchema);
        verifier.setTopicSchemaMapping(TOPIC_AML, invSchema);
        verifier.setTopicSchemaMapping(TOPIC_COUNTRY, invSchema);
        verifier.setTopicSchemaMapping(TOPIC_ACCREDITATION, invSchema);
        verifier.setTopicSchemaMapping(TOPIC_PROFESSIONAL, invSchema);
        verifier.setTopicSchemaMapping(TOPIC_INSTITUTIONAL, invSchema);
        verifier.setTopicSchemaMapping(TOPIC_SANCTIONS, invSchema);
        verifier.setTopicSchemaMapping(TOPIC_SOURCE_OF_FUNDS, invSchema);

        console2.log("--- Topic-policy mapping (optional per topic) ---");
        _bindIfSet(verifier, TOPIC_KYC, "KYC_POLICY");
        _bindIfSet(verifier, TOPIC_AML, "AML_POLICY");
        _bindIfSet(verifier, TOPIC_SANCTIONS, "SANCTIONS_POLICY");
        _bindIfSet(verifier, TOPIC_SOURCE_OF_FUNDS, "SOF_POLICY");
        _bindIfSet(verifier, TOPIC_PROFESSIONAL, "PROFESSIONAL_POLICY");
        _bindIfSet(verifier, TOPIC_INSTITUTIONAL, "INSTITUTIONAL_POLICY");
        _bindIfSet(verifier, TOPIC_COUNTRY, "COUNTRY_POLICY");
        _bindIfSet(verifier, TOPIC_ACCREDITATION, "ACCREDITATION_POLICY");

        vm.stopBroadcast();

        console2.log("");
        console2.log("Next: run VerifyDeployment.s.sol to smoke-test the wiring.");
        console2.log("CLAIM_TOPICS_REGISTRY=", address(topicsRegistry));
    }

    function _bindIfSet(EASClaimVerifier verifier, uint256 topic, string memory envKey) internal {
        address policy = vm.envOr(envKey, address(0));
        if (policy == address(0)) {
            console2.log("Skip topic (no env):", topic);
            return;
        }
        verifier.setTopicPolicy(topic, policy);
        console2.log("Bound topic -> policy:", topic, policy);
    }

    /// @notice Parses a comma-separated list like "1,2,13" into a uint256[].
    function _parseTopics(string memory raw) internal pure returns (uint256[] memory) {
        bytes memory b = bytes(raw);
        if (b.length == 0) return new uint256[](0);

        uint256 count = 1;
        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] == ",") count++;
        }

        uint256[] memory result = new uint256[](count);
        uint256 idx = 0;
        uint256 acc = 0;
        bool hasDigit = false;

        for (uint256 i = 0; i <= b.length; i++) {
            bytes1 ch = i < b.length ? b[i] : bytes1(",");
            if (ch == ",") {
                require(hasDigit, "REQUIRED_TOPICS malformed (empty segment)");
                result[idx++] = acc;
                acc = 0;
                hasDigit = false;
            } else {
                require(ch >= 0x30 && ch <= 0x39, "REQUIRED_TOPICS must be digits and commas");
                acc = acc * 10 + (uint8(ch) - 0x30);
                hasDigit = true;
            }
        }

        return result;
    }

    function _getEAS() internal view returns (address) {
        if (block.chainid == 11155111) return EAS_SEPOLIA;
        if (block.chainid == 84532) return EAS_BASE_SEPOLIA;
        revert("EAS_ADDRESS required for this network");
    }
}
