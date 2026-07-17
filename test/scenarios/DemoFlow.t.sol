// SPDX-License-Identifier: Apache-2.0
// Copyright © 2026 Enterprise Ethereum Alliance Inc.
pragma solidity ^0.8.24;

import {BridgeHarness} from "../helpers/BridgeHarness.sol";
import {MockAttester} from "../../contracts/mocks/MockAttester.sol";
import {DemoERC3643Token} from "../../contracts/demo/DemoERC3643Token.sol";
import {RevocationRequest, RevocationRequestData} from "@eas/IEAS.sol";

/**
 * @title DemoFlowTest
 * @notice End-to-end regression suite for the demo storyline shipped by the
 *         demo UI and `script/SeedDemo.s.sol`. Locks the three investor
 *         narratives from `deployments/sepolia.json#demo` to on-chain
 *         behavior:
 *           Alice — fully verified: transfers clear
 *           Bob   — accreditationType = 0: ACCREDITATION fails, blocked
 *           Carol — verified, then attestation revoked live: blocked next call
 *
 * @dev Mirrors the SeedDemo flow exactly (single attester trusted for the
 *      demo topic set, one InvestorEligibility attestation per investor,
 *      identity = wallet via the proxy's self-identity fallback), then gates
 *      DemoERC3643Token transfers on the resulting `isVerified()` states.
 *      If any of these tests break, the public demo breaks.
 */
contract DemoFlowTest is BridgeHarness {
    DemoERC3643Token internal token;
    MockAttester internal demoKYC;

    address internal alice;
    address internal bob;
    address internal carol;

    bytes32 internal carolUID;

    uint256[] internal demoTopics;

    function setUp() public {
        _setupBridge();

        alice = makeAddr("alice");
        bob = makeAddr("bob");
        carol = makeAddr("carol");

        // Demo required-topic set: KYC, AML, ACCREDITATION, SANCTIONS.
        // ACCREDITATION is required so Bob's story (missing accreditation)
        // is enforced on-chain, not just narrated.
        demoTopics = _topicsArray(TOPIC_KYC, TOPIC_AML, TOPIC_ACCREDITATION, TOPIC_SANCTIONS);
        _setRequiredTopics(demoTopics);

        demoKYC = _createAttester("DemoKYC", demoTopics);

        // Alice — happy path (accreditationType 2 = ACCREDITED, in allow-set).
        EligibilityData memory e = _happyPayload(uint64(block.timestamp + 365 days));
        _attestAndRegister(demoKYC, alice, demoTopics, e);

        // Bob — identical except accreditationType = 0 (none).
        e = _happyPayload(uint64(block.timestamp + 365 days));
        e.accreditationType = 0;
        _attestAndRegister(demoKYC, bob, demoTopics, e);

        // Carol — happy path; her UID is revoked live in the demo.
        e = _happyPayload(uint64(block.timestamp + 365 days));
        carolUID = _attestAndRegister(demoKYC, carol, demoTopics, e);

        // Demo token bound to the verifier; issuer mints (mints skip the gate).
        vm.startPrank(tokenIssuer);
        token = new DemoERC3643Token("Shibui Demo Token", "sDEMO", address(verifier), tokenIssuer);
        token.mint(alice, 100 ether);
        token.mint(carol, 100 ether);
        vm.stopPrank();
    }

    // ============ Verification states ============

    function test_alice_isVerified() public view {
        assertTrue(verifier.isVerified(alice));
    }

    function test_bob_isNotVerified_missingAccreditation() public view {
        assertFalse(verifier.isVerified(bob));
    }

    function test_carol_isVerified_untilRevoked() public {
        assertTrue(verifier.isVerified(carol));
        _revokeCarol();
        assertFalse(verifier.isVerified(carol));
    }

    // ============ Transfer gating (the demo's visible moments) ============

    function test_transfer_aliceToCarol_clears() public {
        vm.prank(alice);
        token.transfer(carol, 10 ether);
        assertEq(token.balanceOf(carol), 110 ether);
    }

    function test_transfer_aliceToBob_reverts_recipientNotVerified() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(DemoERC3643Token.DemoTransferBlocked.selector, bob, "Recipient not verified")
        );
        token.transfer(bob, 10 ether);
    }

    function test_transfer_afterLiveRevocation_reverts() public {
        // Carol can transfer before revocation...
        vm.prank(carol);
        token.transfer(alice, 5 ether);

        // ...the attester revokes on EAS (the demo's live moment)...
        _revokeCarol();

        // ...and the very next transfer is blocked. No sync step, no delay.
        vm.prank(carol);
        vm.expectRevert(
            abi.encodeWithSelector(DemoERC3643Token.DemoTransferBlocked.selector, carol, "Sender not verified")
        );
        token.transfer(alice, 5 ether);

        // Receiving is blocked too.
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(DemoERC3643Token.DemoTransferBlocked.selector, carol, "Recipient not verified")
        );
        token.transfer(carol, 1 ether);
    }

    function test_mint_toUnverified_reverts() public {
        // T-REX semantics: tokens can only ever be delivered to verified
        // investors — mints skip the sender check, not the recipient check.
        vm.prank(tokenIssuer);
        vm.expectRevert(
            abi.encodeWithSelector(DemoERC3643Token.DemoTransferBlocked.selector, bob, "Recipient not verified")
        );
        token.mint(bob, 1 ether);
    }

    // ============ Helpers ============

    function _revokeCarol() internal {
        vm.prank(address(demoKYC));
        eas.revoke(
            RevocationRequest({
                schema: SCHEMA_INVESTOR_ELIGIBILITY,
                data: RevocationRequestData({uid: carolUID, value: 0})
            })
        );
    }
}
