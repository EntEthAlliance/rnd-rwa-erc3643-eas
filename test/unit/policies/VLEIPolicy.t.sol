// SPDX-License-Identifier: Apache-2.0
// Copyright © 2026 Enterprise Ethereum Alliance Inc.
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Attestation} from "@eas/Common.sol";
import {VLEIPolicy} from "../../../contracts/policies/VLEIPolicy.sol";

/**
 * @title VLEIPolicyTest
 * @notice Unit tests for the vlei-to-eas topic policy (PR #98 shipped it
 *         untested). Covers the four validate() gates: decode safety, GLEIF
 *         SAID confirmation, staleness, and credential-type match.
 */
contract VLEIPolicyTest is Test {
    uint256 constant TOPIC_VLEI_LE = 15;
    uint64 constant MAX_STALENESS = 21600; // 6 h; exercises the optional bound (0 disables it)

    VLEIPolicy internal policy;

    function setUp() public {
        vm.warp(1_800_000_000);
        policy = new VLEIPolicy(TOPIC_VLEI_LE, "LE", MAX_STALENESS);
    }

    function _attestation(bytes memory data) internal pure returns (Attestation memory att) {
        att.uid = keccak256("uid");
        att.schema = keccak256("vlei-schema");
        att.data = data;
    }

    function _vleiData(string memory credType, bytes32 said, uint64 verifiedAt) internal pure returns (bytes memory) {
        return abi.encode(
            "5493001KJTIIGC8Y1R12", // lei
            "Example Corp GmbH", // legalName
            credType,
            "EKYGGh-FtAphGmSZbsuBs_t4qpsjYJ2ZqvMKluq9OxmP", // keriAid
            said,
            verifiedAt
        );
    }

    function test_metadata() public view {
        assertEq(policy.topicId(), TOPIC_VLEI_LE);
        assertEq(policy.name(), "VLEIPolicy");
    }

    function test_valid_fresh_le_credential_passes() public view {
        bytes memory data = _vleiData("LE", keccak256("said"), uint64(block.timestamp - 1 hours));
        assertTrue(policy.validate(_attestation(data)));
    }

    function test_zero_said_fails() public view {
        bytes memory data = _vleiData("LE", bytes32(0), uint64(block.timestamp - 1 hours));
        assertFalse(policy.validate(_attestation(data)));
    }

    function test_stale_attestation_fails() public view {
        bytes memory data = _vleiData("LE", keccak256("said"), uint64(block.timestamp - MAX_STALENESS - 1));
        assertFalse(policy.validate(_attestation(data)));
    }

    function test_boundary_exactly_at_staleness_passes() public view {
        bytes memory data = _vleiData("LE", keccak256("said"), uint64(block.timestamp - MAX_STALENESS));
        assertTrue(policy.validate(_attestation(data)));
    }

    function test_wrong_cred_type_fails() public view {
        bytes memory data = _vleiData("ECR", keccak256("said"), uint64(block.timestamp - 1 hours));
        assertFalse(policy.validate(_attestation(data)));
    }

    function test_empty_data_fails_without_revert() public view {
        assertFalse(policy.validate(_attestation("")));
    }

    function test_malformed_data_fails_without_revert() public view {
        assertFalse(policy.validate(_attestation(hex"deadbeef")));
    }

    function test_investor_eligibility_payload_fails_without_revert() public view {
        // Cross-schema contamination guard: a valid InvestorEligibility payload
        // must not decode as a vLEI credential.
        bytes memory wrongSchema = abi.encode(
            address(0xBEEF),
            uint8(1),
            uint8(0),
            uint8(0),
            uint8(1),
            uint8(2),
            uint16(840),
            uint64(block.timestamp + 365 days),
            keccak256("ev"),
            uint8(2)
        );
        assertFalse(policy.validate(_attestation(wrongSchema)));
    }

    function test_constructor_rejects_bad_config() public {
        vm.expectRevert("VLEIPolicy: empty credType");
        new VLEIPolicy(TOPIC_VLEI_LE, "", MAX_STALENESS);
    }

    // ---- maxStaleness = 0: staleness check disabled ----
    //
    // The vlei-to-eas bridge sets verifiedAt once at issuance and never re-attests;
    // liveness comes from the EAS expirationTime/revocationTime, which the verifier
    // core checks before calling the policy. A zero bound must therefore be accepted
    // and must skip only the staleness gate, leaving the other checks intact.

    function test_constructor_accepts_zero_staleness() public {
        VLEIPolicy noStaleness = new VLEIPolicy(TOPIC_VLEI_LE, "LE", 0);
        assertEq(noStaleness.topicId(), TOPIC_VLEI_LE);
    }

    function test_zero_staleness_accepts_old_verified_at() public {
        VLEIPolicy noStaleness = new VLEIPolicy(TOPIC_VLEI_LE, "LE", 0);
        bytes memory data = _vleiData("LE", keccak256("said"), uint64(block.timestamp - 400 days));
        assertTrue(noStaleness.validate(_attestation(data)));
    }

    function test_zero_staleness_still_rejects_zero_said() public {
        VLEIPolicy noStaleness = new VLEIPolicy(TOPIC_VLEI_LE, "LE", 0);
        bytes memory data = _vleiData("LE", bytes32(0), uint64(block.timestamp - 400 days));
        assertFalse(noStaleness.validate(_attestation(data)));
    }

    function test_zero_staleness_still_rejects_wrong_cred_type() public {
        VLEIPolicy noStaleness = new VLEIPolicy(TOPIC_VLEI_LE, "LE", 0);
        bytes memory data = _vleiData("ECR", keccak256("said"), uint64(block.timestamp - 400 days));
        assertFalse(noStaleness.validate(_attestation(data)));
    }
}
