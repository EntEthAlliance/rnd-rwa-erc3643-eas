// SPDX-License-Identifier: Apache-2.0
// Copyright © 2026 Enterprise Ethereum Alliance Inc.
pragma solidity ^0.8.24;

import {BridgeHarness} from "../helpers/BridgeHarness.sol";
import {MockAttester} from "../../contracts/mocks/MockAttester.sol";
import {RevocationRequest, RevocationRequestData} from "@eas/IEAS.sol";

/**
 * @title AttestationRevocationTest
 * @notice Revocation lifecycle (follow-up to audit fix C-2 and #54).
 * @dev Exercises:
 *        - Attester-initiated EAS revocation flips isVerified → false.
 *        - Removing an attester from the adapter invalidates all their
 *          attestations for the topics they covered.
 *        - Re-attestation by the same attester (new UID) restores verification
 *          once re-registered.
 *        - EAS-level expiration makes verification fail at the expected block.
 */
contract AttestationRevocationTest is BridgeHarness {
    address internal investor;
    address internal wallet;
    MockAttester internal kycProvider;

    function setUp() public {
        _setupBridge();
        investor = makeAddr("investor");
        wallet = makeAddr("wallet");
        kycProvider = _createAttester("KYC", _topicsArray(TOPIC_KYC));
        _bindWallet(wallet, investor);
        _setRequiredTopics(_topicsArray(TOPIC_KYC));
    }

    function test_revoke_flips_isVerified_to_false() public {
        EligibilityData memory e = _happyPayload(uint64(block.timestamp + 365 days));
        bytes32 uid = _attestAndRegister(kycProvider, investor, _topicsArray(TOPIC_KYC), e);

        assertTrue(verifier.isVerified(wallet));

        // Attester revokes via EAS
        vm.prank(address(kycProvider));
        eas.revoke(
            RevocationRequest({schema: SCHEMA_INVESTOR_ELIGIBILITY, data: RevocationRequestData({uid: uid, value: 0})})
        );

        assertFalse(verifier.isVerified(wallet));
    }

    function test_removeTrustedAttester_invalidates_all_their_attestations() public {
        address otherInvestor = makeAddr("other");
        address otherWallet = makeAddr("otherWallet");
        _bindWallet(otherWallet, otherInvestor);

        EligibilityData memory e = _happyPayload(uint64(block.timestamp + 365 days));
        _attestAndRegister(kycProvider, investor, _topicsArray(TOPIC_KYC), e);
        _attestAndRegister(kycProvider, otherInvestor, _topicsArray(TOPIC_KYC), e);

        assertTrue(verifier.isVerified(wallet));
        assertTrue(verifier.isVerified(otherWallet));

        vm.prank(tokenIssuer);
        adapter.removeTrustedAttester(address(kycProvider));

        assertFalse(verifier.isVerified(wallet));
        assertFalse(verifier.isVerified(otherWallet));
    }

    function test_reattestation_restores_verification() public {
        EligibilityData memory e = _happyPayload(uint64(block.timestamp + 365 days));
        bytes32 uid = _attestAndRegister(kycProvider, investor, _topicsArray(TOPIC_KYC), e);
        assertTrue(verifier.isVerified(wallet));

        vm.prank(address(kycProvider));
        eas.revoke(
            RevocationRequest({schema: SCHEMA_INVESTOR_ELIGIBILITY, data: RevocationRequestData({uid: uid, value: 0})})
        );
        assertFalse(verifier.isVerified(wallet));

        // New attestation from the same attester, registered with a new UID
        _attestAndRegister(kycProvider, investor, _topicsArray(TOPIC_KYC), e);
        assertTrue(verifier.isVerified(wallet));
    }

    function test_data_level_expiration_fails_verification() public {
        vm.warp(100_000);
        EligibilityData memory e = _happyPayload(uint64(block.timestamp + 1 days));
        _attestAndRegister(kycProvider, investor, _topicsArray(TOPIC_KYC), e);
        assertTrue(verifier.isVerified(wallet));

        vm.warp(block.timestamp + 2 days);
        assertFalse(verifier.isVerified(wallet));
    }
}
