// SPDX-License-Identifier: Apache-2.0
// Copyright © 2026 Enterprise Ethereum Alliance Inc.
pragma solidity ^0.8.24;

import {BridgeHarness} from "../helpers/BridgeHarness.sol";
import {MockAttester} from "../../contracts/mocks/MockAttester.sol";
import {RevocationRequest, RevocationRequestData} from "@eas/IEAS.sol";

/**
 * @title DualModeVerificationTest
 * @notice Multi-provider resiliency (audit fix C-2, follow-up to #54).
 * @dev Confirms the payoff of replacing the single-slot `_activeAttestations`
 *      cache with per-attester iteration: an investor verified by two
 *      providers stays verified when one provider's attestation is revoked or
 *      when that provider is removed from the trusted set, as long as the
 *      other remains live.
 */
contract DualModeVerificationTest is BridgeHarness {
    address internal investor;
    address internal wallet;
    MockAttester internal primary;
    MockAttester internal secondary;

    function setUp() public {
        _setupBridge();
        investor = makeAddr("investor");
        wallet = makeAddr("wallet");
        primary = _createAttester("Primary", _topicsArray(TOPIC_KYC));
        secondary = _createAttester("Secondary", _topicsArray(TOPIC_KYC));
        _bindWallet(wallet, investor);
        _setRequiredTopics(_topicsArray(TOPIC_KYC));
    }

    function test_survives_primary_attestation_revocation() public {
        EligibilityData memory e = _happyPayload(uint64(block.timestamp + 365 days));
        bytes32 primaryUid = _attestAndRegister(primary, investor, _topicsArray(TOPIC_KYC), e);
        _attestAndRegister(secondary, investor, _topicsArray(TOPIC_KYC), e);
        assertTrue(verifier.isVerified(wallet));

        vm.prank(address(primary));
        eas.revoke(
            RevocationRequest({
                schema: SCHEMA_INVESTOR_ELIGIBILITY, data: RevocationRequestData({uid: primaryUid, value: 0})
            })
        );

        assertTrue(verifier.isVerified(wallet), "secondary should still verify");
    }

    function test_survives_primary_attester_removal() public {
        EligibilityData memory e = _happyPayload(uint64(block.timestamp + 365 days));
        _attestAndRegister(primary, investor, _topicsArray(TOPIC_KYC), e);
        _attestAndRegister(secondary, investor, _topicsArray(TOPIC_KYC), e);
        assertTrue(verifier.isVerified(wallet));

        vm.prank(tokenIssuer);
        adapter.removeTrustedAttester(address(primary));

        assertTrue(verifier.isVerified(wallet), "secondary should still verify");
    }

    function test_fails_when_both_providers_revoke() public {
        EligibilityData memory e = _happyPayload(uint64(block.timestamp + 365 days));
        bytes32 primaryUid = _attestAndRegister(primary, investor, _topicsArray(TOPIC_KYC), e);
        bytes32 secondaryUid = _attestAndRegister(secondary, investor, _topicsArray(TOPIC_KYC), e);

        vm.prank(address(primary));
        eas.revoke(
            RevocationRequest({
                schema: SCHEMA_INVESTOR_ELIGIBILITY, data: RevocationRequestData({uid: primaryUid, value: 0})
            })
        );
        vm.prank(address(secondary));
        eas.revoke(
            RevocationRequest({
                schema: SCHEMA_INVESTOR_ELIGIBILITY, data: RevocationRequestData({uid: secondaryUid, value: 0})
            })
        );

        assertFalse(verifier.isVerified(wallet));
    }
}
