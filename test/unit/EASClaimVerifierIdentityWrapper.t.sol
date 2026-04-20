// SPDX-License-Identifier: Apache-2.0
// Copyright © 2026 Enterprise Ethereum Alliance Inc.
pragma solidity ^0.8.24;

import {BridgeHarness} from "../helpers/BridgeHarness.sol";
import {EASClaimVerifierIdentityWrapper} from "../../contracts/compat/EASClaimVerifierIdentityWrapper.sol";
import {IIdentity} from "../../contracts/interfaces/IIdentity.sol";
import {MockAttester} from "../../contracts/mocks/MockAttester.sol";

/**
 * @title EASClaimVerifierIdentityWrapperTest
 * @notice Unit tests for the Path B read-compat shim (follow-up to #55).
 * @dev The wrapper intentionally does NOT implement ERC-734 key management,
 *      signature verification, or topic-policy validation. These tests exist
 *      primarily to *document and lock in* those non-behaviours, so a future
 *      refactor can't silently weaken the reclassification from audit C-4.
 */
contract EASClaimVerifierIdentityWrapperTest is BridgeHarness {
    address internal investor;
    MockAttester internal kyc;
    EASClaimVerifierIdentityWrapper internal wrapper;

    function setUp() public {
        _setupBridge();
        investor = makeAddr("investor");
        kyc = _createAttester("KYC", _topicsArray(TOPIC_KYC));

        wrapper = new EASClaimVerifierIdentityWrapper(investor, address(eas), address(verifier), address(adapter));
    }

    // ----- ERC-734 non-implementation ----------------------------------------

    function test_addKey_reverts() public {
        vm.expectRevert(bytes("Key management not supported"));
        wrapper.addKey(bytes32(uint256(1)), 1, 1);
    }

    function test_removeKey_reverts() public {
        vm.expectRevert(bytes("Key management not supported"));
        wrapper.removeKey(bytes32(uint256(1)), 1);
    }

    function test_execute_reverts() public {
        vm.expectRevert(bytes("Execution not supported"));
        wrapper.execute(address(0), 0, "");
    }

    function test_approve_reverts() public {
        vm.expectRevert(bytes("Execution not supported"));
        wrapper.approve(0, true);
    }

    function test_getKey_returns_management_key_for_identity() public view {
        (uint256[] memory purposes, uint256 keyType, bytes32 key) = wrapper.getKey(keccak256(abi.encode(investor)));
        assertEq(purposes.length, 1);
        assertEq(purposes[0], 1, "should be MANAGEMENT purpose");
        assertEq(keyType, 1);
        assertEq(key, keccak256(abi.encode(investor)));
    }

    function test_getKey_returns_empty_for_unknown_key() public view {
        (uint256[] memory purposes, uint256 keyType, bytes32 key) = wrapper.getKey(keccak256("unknown"));
        assertEq(purposes.length, 0);
        assertEq(keyType, 0);
        assertEq(key, bytes32(0));
    }

    function test_keyHasPurpose_only_management_for_identity() public view {
        bytes32 identityKey = keccak256(abi.encode(investor));
        assertTrue(wrapper.keyHasPurpose(identityKey, 1));
        assertFalse(wrapper.keyHasPurpose(identityKey, 2));
        assertFalse(wrapper.keyHasPurpose(keccak256("other"), 1));
    }

    // ----- ERC-735 non-implementation ----------------------------------------

    function test_addClaim_reverts_with_eas_guidance() public {
        vm.expectRevert(bytes("Use EAS to create attestations"));
        wrapper.addClaim(1, 1, address(this), "", "", "");
    }

    function test_removeClaim_reverts_with_eas_guidance() public {
        vm.expectRevert(bytes("Use EAS to revoke attestations"));
        wrapper.removeClaim(bytes32(0));
    }

    // ----- getClaim behaviour ------------------------------------------------

    function test_getClaim_returns_empty_signature_and_scheme_1() public {
        EligibilityData memory e = _happyPayload(uint64(block.timestamp + 365 days));
        _attestAndRegister(kyc, investor, _topicsArray(TOPIC_KYC), e);

        bytes32 claimId = keccak256(abi.encode(address(kyc), TOPIC_KYC));
        (uint256 topic, uint256 scheme, address issuer, bytes memory sig, bytes memory data, string memory uri) =
            wrapper.getClaim(claimId);

        assertEq(topic, TOPIC_KYC);
        assertEq(scheme, 1, "wrapper advertises scheme=1 regardless of EAS internals");
        assertEq(issuer, address(kyc));
        assertEq(sig.length, 0, "wrapper cannot return the EAS signature");
        assertGt(data.length, 0);
        assertEq(bytes(uri).length, 0);
    }

    function test_getClaim_returns_empty_tuple_for_unknown_id() public view {
        (uint256 topic, uint256 scheme, address issuer, bytes memory sig, bytes memory data, string memory uri) =
            wrapper.getClaim(keccak256("nobody"));
        assertEq(topic, 0);
        assertEq(scheme, 0);
        assertEq(issuer, address(0));
        assertEq(sig.length, 0);
        assertEq(data.length, 0);
        assertEq(bytes(uri).length, 0);
    }

    // ----- getClaimIdsByTopic ------------------------------------------------

    function test_getClaimIdsByTopic_lists_registered_attestations() public {
        EligibilityData memory e = _happyPayload(uint64(block.timestamp + 365 days));
        _attestAndRegister(kyc, investor, _topicsArray(TOPIC_KYC), e);

        bytes32[] memory ids = wrapper.getClaimIdsByTopic(TOPIC_KYC);
        assertEq(ids.length, 1);
        assertEq(ids[0], keccak256(abi.encode(address(kyc), TOPIC_KYC)));
    }

    function test_getClaimIdsByTopic_empty_for_topic_with_no_attestation() public view {
        bytes32[] memory ids = wrapper.getClaimIdsByTopic(TOPIC_SANCTIONS);
        assertEq(ids.length, 0);
    }

    // ----- isClaimValid (intentionally payload-unaware in this shim) ---------

    function test_isClaimValid_accepts_stale_payload_intentionally() public {
        // Audit C-4 footnote: isClaimValid() in the wrapper does NOT run topic
        // policies; it only checks attestation existence, revocation, and
        // EAS-level expiration. So a kycStatus=0 attestation will pass here
        // even though EASClaimVerifier.isVerified() would reject it.
        EligibilityData memory e = _happyPayload(uint64(block.timestamp + 365 days));
        e.kycStatus = 0; // NOT_VERIFIED — would fail payload-aware verification
        _attestAndRegister(kyc, investor, _topicsArray(TOPIC_KYC), e);

        bool ok = wrapper.isClaimValid(IIdentity(address(wrapper)), TOPIC_KYC, "", "");
        assertTrue(ok, "wrapper.isClaimValid does not enforce payload; this is by design");
    }
}
