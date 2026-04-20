// SPDX-License-Identifier: Apache-2.0
// Copyright © 2026 Enterprise Ethereum Alliance Inc.
pragma solidity ^0.8.24;

import {BridgeHarness} from "../helpers/BridgeHarness.sol";
import {MockAttester} from "../../contracts/mocks/MockAttester.sol";
import {RevocationRequest, RevocationRequestData} from "@eas/IEAS.sol";

/**
 * @title InvestorLifecycleTest
 * @notice Lifecycle scenarios that exercise the identity proxy beyond single
 *         wallet/identity pairs (follow-up to #55).
 * @dev Covers:
 *        - Multi-wallet: a single identity bound to multiple wallets; every
 *          wallet sees the same verification outcome.
 *        - Renewal: an expired attestation fails verification, and
 *          re-attesting with a later expiration restores it.
 *        - Wallet removal: `removeWallet` correctly unbinds and the wallet
 *          falls back to being its own identity (which then has no
 *          attestations, so `isVerified` → false).
 *        - Attester retirement: removing a trusted attester correctly
 *          invalidates every investor covered by that attester without
 *          affecting investors covered by a different attester.
 */
contract InvestorLifecycleTest is BridgeHarness {
    MockAttester internal kyc;

    function setUp() public {
        _setupBridge();
        kyc = _createAttester("KYC", _topicsArray(TOPIC_KYC));
        _setRequiredTopics(_topicsArray(TOPIC_KYC));
    }

    // ----- Multi-wallet ------------------------------------------------------

    function test_multi_wallet_all_verify_the_same_identity() public {
        address investor = makeAddr("investor");
        address walletA = makeAddr("walletA");
        address walletB = makeAddr("walletB");
        address walletC = makeAddr("walletC");

        address[] memory wallets = new address[](3);
        wallets[0] = walletA;
        wallets[1] = walletB;
        wallets[2] = walletC;

        vm.prank(tokenIssuer);
        identityProxy.batchRegisterWallets(wallets, investor);

        EligibilityData memory e = _happyPayload(uint64(block.timestamp + 365 days));
        _attestAndRegister(kyc, investor, _topicsArray(TOPIC_KYC), e);

        assertTrue(verifier.isVerified(walletA));
        assertTrue(verifier.isVerified(walletB));
        assertTrue(verifier.isVerified(walletC));
    }

    function test_multi_wallet_all_fail_when_identity_attestation_revoked() public {
        address investor = makeAddr("investor");
        address walletA = makeAddr("walletA");
        address walletB = makeAddr("walletB");
        _bindWallet(walletA, investor);
        _bindWallet(walletB, investor);

        EligibilityData memory e = _happyPayload(uint64(block.timestamp + 365 days));
        bytes32 uid = _attestAndRegister(kyc, investor, _topicsArray(TOPIC_KYC), e);

        assertTrue(verifier.isVerified(walletA));
        assertTrue(verifier.isVerified(walletB));

        vm.prank(address(kyc));
        eas.revoke(
            RevocationRequest({schema: SCHEMA_INVESTOR_ELIGIBILITY, data: RevocationRequestData({uid: uid, value: 0})})
        );

        assertFalse(verifier.isVerified(walletA));
        assertFalse(verifier.isVerified(walletB));
    }

    // ----- Renewal -----------------------------------------------------------

    function test_renewal_flow() public {
        address investor = makeAddr("investor");
        address wallet = makeAddr("wallet");
        _bindWallet(wallet, investor);

        // Attestation valid for 1 day
        vm.warp(1_000_000);
        EligibilityData memory e = _happyPayload(uint64(block.timestamp + 1 days));
        _attestAndRegister(kyc, investor, _topicsArray(TOPIC_KYC), e);
        assertTrue(verifier.isVerified(wallet));

        // Advance past expiration
        vm.warp(block.timestamp + 2 days);
        assertFalse(verifier.isVerified(wallet));

        // Renew with a fresh attestation (later expiration)
        EligibilityData memory renewed = _happyPayload(uint64(block.timestamp + 365 days));
        _attestAndRegister(kyc, investor, _topicsArray(TOPIC_KYC), renewed);
        assertTrue(verifier.isVerified(wallet));
    }

    // ----- Wallet removal ----------------------------------------------------

    function test_removeWallet_drops_the_mapping() public {
        address investor = makeAddr("investor");
        address wallet = makeAddr("wallet");
        _bindWallet(wallet, investor);

        EligibilityData memory e = _happyPayload(uint64(block.timestamp + 365 days));
        _attestAndRegister(kyc, investor, _topicsArray(TOPIC_KYC), e);
        assertTrue(verifier.isVerified(wallet));

        vm.prank(tokenIssuer);
        identityProxy.removeWallet(wallet);

        // After removal, getIdentity(wallet) returns wallet itself — which
        // has no attestations of its own, so verification fails.
        assertFalse(verifier.isVerified(wallet));
    }

    // ----- Attester retirement -----------------------------------------------

    function test_attester_retirement_scoped_to_affected_investors() public {
        MockAttester backupKyc = _createAttester("BackupKYC", _topicsArray(TOPIC_KYC));

        address investorA = makeAddr("investorA");
        address walletA = makeAddr("walletA");
        _bindWallet(walletA, investorA);

        address investorB = makeAddr("investorB");
        address walletB = makeAddr("walletB");
        _bindWallet(walletB, investorB);

        EligibilityData memory e = _happyPayload(uint64(block.timestamp + 365 days));

        // investorA covered only by `kyc`, investorB covered only by `backupKyc`.
        _attestAndRegister(kyc, investorA, _topicsArray(TOPIC_KYC), e);
        _attestAndRegister(backupKyc, investorB, _topicsArray(TOPIC_KYC), e);

        assertTrue(verifier.isVerified(walletA));
        assertTrue(verifier.isVerified(walletB));

        // Retire `kyc`. investorA loses verification, investorB does not.
        vm.prank(tokenIssuer);
        adapter.removeTrustedAttester(address(kyc));

        assertFalse(verifier.isVerified(walletA));
        assertTrue(verifier.isVerified(walletB));
    }
}
