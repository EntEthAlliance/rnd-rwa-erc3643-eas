// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {EASClaimVerifier} from "../contracts/EASClaimVerifier.sol";
import {EASTrustedIssuersAdapter} from "../contracts/EASTrustedIssuersAdapter.sol";

/**
 * @title ConfigureBridge
 * @notice Idempotent post-deploy wiring: topic-schema mapping, topic-policy
 *         mapping, and the Schema-2 UID for the adapter.
 * @dev Run by an OPERATOR_ROLE holder. Intended for incremental reconfig —
 *      every setter is safe to re-run.
 *
 *      Required env:
 *        PRIVATE_KEY                    — operator key
 *        VERIFIER_ADDRESS               — EASClaimVerifier (or its proxy)
 *        ADAPTER_ADDRESS                — EASTrustedIssuersAdapter
 *        INVESTOR_ELIGIBILITY_SCHEMA_UID — from RegisterSchemas
 *        ISSUER_AUTHORIZATION_SCHEMA_UID — from RegisterSchemas
 *
 *        KYC_POLICY, AML_POLICY, SANCTIONS_POLICY, SOF_POLICY,
 *        PROFESSIONAL_POLICY, INSTITUTIONAL_POLICY, COUNTRY_POLICY,
 *        ACCREDITATION_POLICY — each optional; skipped if unset.
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

    function run() external {
        uint256 key = vm.envUint("PRIVATE_KEY");
        EASClaimVerifier verifier = EASClaimVerifier(vm.envAddress("VERIFIER_ADDRESS"));
        EASTrustedIssuersAdapter adapter = EASTrustedIssuersAdapter(vm.envAddress("ADAPTER_ADDRESS"));

        bytes32 invSchema = vm.envBytes32("INVESTOR_ELIGIBILITY_SCHEMA_UID");
        bytes32 authSchema = vm.envBytes32("ISSUER_AUTHORIZATION_SCHEMA_UID");

        vm.startBroadcast(key);

        console2.log("--- Topic-schema mapping ---");
        verifier.setTopicSchemaMapping(TOPIC_KYC, invSchema);
        verifier.setTopicSchemaMapping(TOPIC_AML, invSchema);
        verifier.setTopicSchemaMapping(TOPIC_COUNTRY, invSchema);
        verifier.setTopicSchemaMapping(TOPIC_ACCREDITATION, invSchema);
        verifier.setTopicSchemaMapping(TOPIC_PROFESSIONAL, invSchema);
        verifier.setTopicSchemaMapping(TOPIC_INSTITUTIONAL, invSchema);
        verifier.setTopicSchemaMapping(TOPIC_SANCTIONS, invSchema);
        verifier.setTopicSchemaMapping(TOPIC_SOURCE_OF_FUNDS, invSchema);

        console2.log("--- Issuer Authorization schema on adapter ---");
        adapter.setIssuerAuthSchemaUID(authSchema);

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
}
