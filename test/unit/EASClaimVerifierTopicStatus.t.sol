// SPDX-License-Identifier: Apache-2.0
// Copyright © 2026 Enterprise Ethereum Alliance Inc.
pragma solidity ^0.8.24;

import {BridgeHarness} from "../helpers/BridgeHarness.sol";
import {IEASClaimVerifier} from "../../contracts/interfaces/IEASClaimVerifier.sol";
import {EASClaimVerifier} from "../../contracts/EASClaimVerifier.sol";
import {ITopicPolicy} from "../../contracts/policies/ITopicPolicy.sol";
import {MockAttester} from "../../contracts/mocks/MockAttester.sol";
import {Attestation, RevocationRequest, RevocationRequestData} from "@eas/IEAS.sol";

/// @dev Violates the ITopicPolicy "never reverts" rule, to prove the verifier fails closed.
contract RevertingPolicy is ITopicPolicy {
    function topicId() external pure returns (uint256) {
        return 1;
    }

    function name() external pure returns (string memory) {
        return "RevertingPolicy";
    }

    function validate(Attestation calldata) external pure returns (bool) {
        revert("boom");
    }
}

/**
 * @title EASClaimVerifierTopicStatusTest
 * @notice Per-token topic sets, the per-topic status view, batch registration and the
 *         non-reverting path (upstream feedback from the Interlock starter kit).
 */
contract EASClaimVerifierTopicStatusTest is BridgeHarness {
    address internal investor;
    address internal wallet;
    MockAttester internal kyc;
    MockAttester internal kyc2;
    MockAttester internal accreditor;

    function setUp() public {
        _setupBridge();
        investor = makeAddr("investor");
        wallet = makeAddr("wallet");
        kyc = _createAttester("KYC", _topicsArray(TOPIC_KYC, TOPIC_AML));
        kyc2 = _createAttester("KYC2", _topicsArray(TOPIC_KYC));
        accreditor = _createAttester("ACC", _topicsArray(TOPIC_ACCREDITATION));
        _bindWallet(wallet, investor);
    }

    // ============ Point 2: one verifier, different rules per token ============

    /// @dev Two products share one verifier but require different topics. An investor who is
    ///      KYC'd but not accredited must pass the retail product and fail the accredited one,
    ///      without a second verifier/registry/adapter.
    function test_one_verifier_serves_tokens_with_different_topic_sets() public {
        _attestAndRegister(kyc, investor, _topicsArray(TOPIC_KYC), _happyPayload(_inOneYear()));

        uint256[] memory retail = _topicsArray(TOPIC_KYC);
        uint256[] memory accredited = _topicsArray(TOPIC_KYC, TOPIC_ACCREDITATION);

        assertTrue(verifier.isVerifiedForTopics(wallet, retail));
        assertFalse(verifier.isVerifiedForTopics(wallet, accredited));

        _attestAndRegister(accreditor, investor, _topicsArray(TOPIC_ACCREDITATION), _happyPayload(_inOneYear()));
        assertTrue(verifier.isVerifiedForTopics(wallet, accredited));
    }

    /// @dev The topic-set variant must enforce the same rules as isVerified, not a weaker copy.
    function test_isVerifiedForTopics_matches_isVerified_for_registry_topics() public {
        uint256[] memory topics = _topicsArray(TOPIC_KYC, TOPIC_AML);
        _setRequiredTopics(topics);
        EligibilityData memory e = _happyPayload(_inOneYear());
        e.amlStatus = 1; // flagged → AML policy rejects
        _attestAndRegister(kyc, investor, topics, e);

        assertFalse(verifier.isVerified(wallet));
        assertEq(verifier.isVerified(wallet), verifier.isVerifiedForTopics(wallet, topics));
    }

    function test_isVerifiedForTopics_reverts_on_missing_policy_like_isVerified() public {
        vm.prank(tokenIssuer);
        verifier.setTopicPolicy(TOPIC_KYC, address(0));
        vm.expectRevert(abi.encodeWithSelector(IEASClaimVerifier.PolicyNotConfiguredForTopic.selector, TOPIC_KYC));
        verifier.isVerifiedForTopics(wallet, _topicsArray(TOPIC_KYC));
    }

    // ============ Point 3: a reason, not only yes or no ============

    function test_status_ok() public {
        _attestAndRegister(kyc, investor, _topicsArray(TOPIC_KYC), _happyPayload(_inOneYear()));
        _assertStatus(TOPIC_KYC, IEASClaimVerifier.TopicStatus.OK);
    }

    function test_status_not_registered() public {
        _assertStatus(TOPIC_KYC, IEASClaimVerifier.TopicStatus.NotRegistered);
    }

    function test_status_policy_rejected() public {
        EligibilityData memory e = _happyPayload(_inOneYear());
        e.kycStatus = 0;
        _attestAndRegister(kyc, investor, _topicsArray(TOPIC_KYC), e);
        _assertStatus(TOPIC_KYC, IEASClaimVerifier.TopicStatus.PolicyRejected);
    }

    function test_status_revoked() public {
        bytes32 uid = _attestAndRegister(kyc, investor, _topicsArray(TOPIC_KYC), _happyPayload(_inOneYear()));
        _revoke(kyc, uid);
        _assertStatus(TOPIC_KYC, IEASClaimVerifier.TopicStatus.Revoked);
    }

    /// @dev EAS-level expiry (not the payload's expirationTimestamp) is what makes vLEI
    ///      credentials lapse, so it must surface as Expired, not PolicyRejected.
    function test_status_expired_by_eas_expiration_time() public {
        EligibilityData memory e = _happyPayload(_inOneYear());
        bytes memory data = kyc.encodeInvestorEligibility(
            investor,
            e.kycStatus,
            e.amlStatus,
            e.sanctionsStatus,
            e.sourceOfFundsStatus,
            e.accreditationType,
            e.countryCode,
            e.expirationTimestamp,
            e.evidenceHash,
            e.verificationMethod
        );
        bytes32 uid =
            kyc.attestCustom(SCHEMA_INVESTOR_ELIGIBILITY, investor, data, uint64(block.timestamp + 1 days), true);
        vm.prank(address(kyc));
        verifier.registerAttestation(investor, TOPIC_KYC, uid);
        _assertStatus(TOPIC_KYC, IEASClaimVerifier.TopicStatus.OK);

        vm.warp(block.timestamp + 1 days);
        _assertStatus(TOPIC_KYC, IEASClaimVerifier.TopicStatus.Expired);
    }

    function test_status_schema_not_mapped() public {
        vm.prank(tokenIssuer);
        verifier.setTopicSchemaMapping(TOPIC_KYC, bytes32(0));
        _assertStatus(TOPIC_KYC, IEASClaimVerifier.TopicStatus.SchemaNotMapped);
    }

    function test_status_attestation_invalid_after_schema_remap() public {
        _attestAndRegister(kyc, investor, _topicsArray(TOPIC_KYC), _happyPayload(_inOneYear()));
        vm.prank(tokenIssuer);
        verifier.setTopicSchemaMapping(TOPIC_KYC, keccak256("OtherSchema"));
        _assertStatus(TOPIC_KYC, IEASClaimVerifier.TopicStatus.AttestationInvalid);
    }

    /// @dev With several attesters, the reason must point at the most actionable failure
    ///      (a revoked credential), not the attester that simply never attested.
    function test_status_reports_furthest_failure_across_attesters() public {
        bytes32 uid = _attestAndRegister(kyc, investor, _topicsArray(TOPIC_KYC), _happyPayload(_inOneYear()));
        _revoke(kyc, uid);
        // kyc2 is trusted for TOPIC_KYC but has registered nothing for this investor.
        _assertStatus(TOPIC_KYC, IEASClaimVerifier.TopicStatus.Revoked);
    }

    /// @dev A second attester's valid credential satisfies the topic even if the first is revoked.
    function test_status_ok_when_any_attester_passes() public {
        bytes32 uid = _attestAndRegister(kyc, investor, _topicsArray(TOPIC_KYC), _happyPayload(_inOneYear()));
        _revoke(kyc, uid);
        _attestAndRegister(kyc2, investor, _topicsArray(TOPIC_KYC), _happyPayload(_inOneYear()));
        _assertStatus(TOPIC_KYC, IEASClaimVerifier.TopicStatus.OK);
    }

    function test_statuses_are_per_topic_and_in_order() public {
        _attestAndRegister(kyc, investor, _topicsArray(TOPIC_KYC), _happyPayload(_inOneYear()));
        IEASClaimVerifier.TopicStatus[] memory s =
            verifier.getTopicStatuses(wallet, _topicsArray(TOPIC_KYC, TOPIC_ACCREDITATION));
        assertEq(s.length, 2);
        assertEq(uint8(s[0]), uint8(IEASClaimVerifier.TopicStatus.OK));
        assertEq(uint8(s[1]), uint8(IEASClaimVerifier.TopicStatus.NotRegistered));
    }

    // ============ Minor: never revert (ERC-7943 canTransfer) ============

    function test_status_policy_missing_does_not_revert() public {
        vm.prank(tokenIssuer);
        verifier.setTopicPolicy(TOPIC_KYC, address(0));
        IEASClaimVerifier.TopicStatus[] memory s = verifier.getTopicStatuses(wallet, _topicsArray(TOPIC_KYC));
        assertEq(uint8(s[0]), uint8(IEASClaimVerifier.TopicStatus.PolicyMissing));
    }

    /// @dev An unwired verifier must still answer (fail closed) rather than revert.
    function test_status_not_configured_does_not_revert() public {
        EASClaimVerifier fresh = new EASClaimVerifier(tokenIssuer);
        IEASClaimVerifier.TopicStatus[] memory s = fresh.getTopicStatuses(wallet, _topicsArray(TOPIC_KYC, TOPIC_AML));
        assertEq(uint8(s[0]), uint8(IEASClaimVerifier.TopicStatus.NotConfigured));
        assertEq(uint8(s[1]), uint8(IEASClaimVerifier.TopicStatus.NotConfigured));
    }

    /// @dev A buggy policy that reverts must deny the investor, not brick every transfer.
    function test_reverting_policy_fails_closed() public {
        _attestAndRegister(kyc, investor, _topicsArray(TOPIC_KYC), _happyPayload(_inOneYear()));
        address reverting = address(new RevertingPolicy());
        vm.prank(tokenIssuer);
        verifier.setTopicPolicy(TOPIC_KYC, reverting);
        _setRequiredTopics(_topicsArray(TOPIC_KYC));

        assertFalse(verifier.isVerified(wallet));
        _assertStatus(TOPIC_KYC, IEASClaimVerifier.TopicStatus.PolicyRejected);
    }

    // ============ Point 4: batch registration ============

    function test_registerAttestations_registers_all_topics_in_one_call() public {
        bytes32 uid = _attestOnly(kyc, _happyPayload(_inOneYear()));
        bytes32[] memory uids = new bytes32[](2);
        uids[0] = uid;
        uids[1] = uid;

        vm.prank(address(kyc));
        verifier.registerAttestations(investor, _topicsArray(TOPIC_KYC, TOPIC_AML), uids);

        assertEq(verifier.getRegisteredAttestation(investor, TOPIC_KYC, address(kyc)), uid);
        assertEq(verifier.getRegisteredAttestation(investor, TOPIC_AML, address(kyc)), uid);
        assertTrue(verifier.isVerifiedForTopics(wallet, _topicsArray(TOPIC_KYC, TOPIC_AML)));
    }

    function test_registerAttestations_rejects_length_mismatch() public {
        vm.prank(address(kyc));
        vm.expectRevert(IEASClaimVerifier.ArrayLengthMismatch.selector);
        verifier.registerAttestations(investor, _topicsArray(TOPIC_KYC, TOPIC_AML), new bytes32[](1));
    }

    /// @dev Batching must not open a path around audit finding C-3 (no self-registration).
    function test_registerAttestations_rejects_self_registration() public {
        bytes32[] memory uids = new bytes32[](1);
        uids[0] = _attestOnly(kyc, _happyPayload(_inOneYear()));
        vm.prank(investor);
        vm.expectRevert(bytes("Caller not authorized"));
        verifier.registerAttestations(investor, _topicsArray(TOPIC_KYC), uids);
    }

    /// @dev All-or-nothing: if one entry is invalid, none of the batch is registered.
    function test_registerAttestations_is_atomic() public {
        bytes32[] memory uids = new bytes32[](2);
        uids[0] = _attestOnly(kyc, _happyPayload(_inOneYear()));
        uids[1] = _attestOnly(kyc, _happyPayload(_inOneYear()));

        // kyc is not trusted for TOPIC_ACCREDITATION, so the second entry fails.
        vm.prank(address(kyc));
        vm.expectRevert(bytes("Attester not trusted"));
        verifier.registerAttestations(investor, _topicsArray(TOPIC_KYC, TOPIC_ACCREDITATION), uids);

        assertEq(verifier.getRegisteredAttestation(investor, TOPIC_KYC, address(kyc)), bytes32(0));
    }

    // ============ Helpers ============

    /// @dev Asserts the status AND that it agrees with the boolean answer, so the reason view
    ///      can never say OK while isVerifiedForTopics says no (or vice versa).
    function _assertStatus(uint256 topic, IEASClaimVerifier.TopicStatus expected) internal {
        uint256[] memory topics = _topicsArray(topic);
        IEASClaimVerifier.TopicStatus[] memory s = verifier.getTopicStatuses(wallet, topics);
        assertEq(s.length, 1);
        assertEq(uint8(s[0]), uint8(expected), "status");

        if (expected == IEASClaimVerifier.TopicStatus.PolicyMissing) return; // bool path reverts
        assertEq(verifier.isVerifiedForTopics(wallet, topics), expected == IEASClaimVerifier.TopicStatus.OK, "agree");
    }

    function _revoke(MockAttester attester, bytes32 uid) internal {
        vm.prank(address(attester));
        eas.revoke(
            RevocationRequest({schema: SCHEMA_INVESTOR_ELIGIBILITY, data: RevocationRequestData({uid: uid, value: 0})})
        );
    }

    function _attestOnly(MockAttester attester, EligibilityData memory e) internal returns (bytes32) {
        return attester.attestInvestorEligibility(
            SCHEMA_INVESTOR_ELIGIBILITY,
            investor,
            investor,
            e.kycStatus,
            e.amlStatus,
            e.sanctionsStatus,
            e.sourceOfFundsStatus,
            e.accreditationType,
            e.countryCode,
            e.expirationTimestamp,
            e.evidenceHash,
            e.verificationMethod
        );
    }

    function _inOneYear() internal view returns (uint64) {
        return uint64(block.timestamp + 365 days);
    }
}
