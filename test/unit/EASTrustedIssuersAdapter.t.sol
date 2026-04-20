// SPDX-License-Identifier: Apache-2.0
// Copyright © 2026 Enterprise Ethereum Alliance Inc.
pragma solidity ^0.8.24;

import {BridgeHarness} from "../helpers/BridgeHarness.sol";
import {IEASTrustedIssuersAdapter} from "../../contracts/interfaces/IEASTrustedIssuersAdapter.sol";
import {MockAttester} from "../../contracts/mocks/MockAttester.sol";

/**
 * @title EASTrustedIssuersAdapterTest
 * @notice Unit tests for Schema-2-gated attester trust management (audit C-5).
 */
contract EASTrustedIssuersAdapterTest is BridgeHarness {
    function setUp() public {
        _setupBridge();
    }

    function test_addTrustedAttester_with_valid_authUID() public {
        MockAttester kyc = _createAttester("KYC", _topicsArray(TOPIC_KYC));
        assertTrue(adapter.isAttesterTrusted(address(kyc), TOPIC_KYC));
    }

    function test_addTrustedAttester_rejects_missing_authUID() public {
        MockAttester kyc = new MockAttester(address(eas), "KYC");
        uint256[] memory topics = _topicsArray(TOPIC_KYC);
        vm.prank(tokenIssuer);
        vm.expectRevert(IEASTrustedIssuersAdapter.IssuerAuthAttestationMissing.selector);
        adapter.addTrustedAttester(address(kyc), topics, bytes32(uint256(0xBAD)));
    }

    function test_addTrustedAttester_rejects_recipient_mismatch() public {
        MockAttester kyc = new MockAttester(address(eas), "KYC");
        address otherAddr = makeAddr("other");
        uint256[] memory topics = _topicsArray(TOPIC_KYC);
        bytes32 authUID =
            authorizer.attestIssuerAuthorization(SCHEMA_ISSUER_AUTHORIZATION, otherAddr, topics, "mismatch");

        vm.prank(tokenIssuer);
        vm.expectRevert(IEASTrustedIssuersAdapter.IssuerAuthRecipientMismatch.selector);
        adapter.addTrustedAttester(address(kyc), topics, authUID);
    }

    function test_addTrustedAttester_rejects_topic_not_in_authorization() public {
        MockAttester kyc = new MockAttester(address(eas), "KYC");
        uint256[] memory authorized = _topicsArray(TOPIC_KYC);
        uint256[] memory requested = _topicsArray(TOPIC_KYC, TOPIC_ACCREDITATION);
        bytes32 authUID =
            authorizer.attestIssuerAuthorization(SCHEMA_ISSUER_AUTHORIZATION, address(kyc), authorized, "partial");

        vm.prank(tokenIssuer);
        vm.expectRevert(IEASTrustedIssuersAdapter.IssuerAuthTopicsNotAuthorized.selector);
        adapter.addTrustedAttester(address(kyc), requested, authUID);
    }

    function test_addTrustedAttester_requires_operator_role() public {
        MockAttester kyc = new MockAttester(address(eas), "KYC");
        uint256[] memory topics = _topicsArray(TOPIC_KYC);
        bytes32 authUID = authorizer.attestIssuerAuthorization(SCHEMA_ISSUER_AUTHORIZATION, address(kyc), topics, "KYC");

        address outsider = makeAddr("outsider");
        vm.prank(outsider);
        vm.expectRevert();
        adapter.addTrustedAttester(address(kyc), topics, authUID);
    }

    function test_removeTrustedAttester_clears_topic_assignments() public {
        MockAttester kyc = _createAttester("KYC", _topicsArray(TOPIC_KYC));
        vm.prank(tokenIssuer);
        adapter.removeTrustedAttester(address(kyc));
        assertFalse(adapter.isAttesterTrusted(address(kyc), TOPIC_KYC));
        assertFalse(adapter.isTrustedAttester(address(kyc)));
    }

    function test_updateAttesterTopics_requires_authUID() public {
        MockAttester kyc = _createAttester("KYC", _topicsArray(TOPIC_KYC));
        uint256[] memory newTopics = _topicsArray(TOPIC_KYC, TOPIC_ACCREDITATION);
        bytes32 newAuth =
            authorizer.attestIssuerAuthorization(SCHEMA_ISSUER_AUTHORIZATION, address(kyc), newTopics, "KYC-expanded");
        vm.prank(tokenIssuer);
        adapter.updateAttesterTopics(address(kyc), newTopics, newAuth);
        assertTrue(adapter.isAttesterTrusted(address(kyc), TOPIC_ACCREDITATION));
    }

    function test_setIssuerAuthSchemaUID_requires_admin() public {
        address outsider = makeAddr("outsider");
        vm.prank(outsider);
        vm.expectRevert();
        adapter.setIssuerAuthSchemaUID(bytes32(uint256(0x1)));
    }

    function test_setEASAddress_emits_event() public {
        // The harness already wired EAS in setUp; point to a different contract
        // address to produce a state change and observable event.
        address newEAS = address(new MockAttester(address(eas), "DummyEAS"));

        vm.expectEmit(true, false, false, false, address(adapter));
        emit IEASTrustedIssuersAdapter.EASAddressSet(newEAS);

        vm.prank(tokenIssuer);
        adapter.setEASAddress(newEAS);

        assertEq(adapter.getEASAddress(), newEAS);
    }

    function test_setEASAddress_zero_reverts() public {
        vm.prank(tokenIssuer);
        vm.expectRevert(IEASTrustedIssuersAdapter.ZeroAddressNotAllowed.selector);
        adapter.setEASAddress(address(0));
    }

    function test_setEASAddress_requires_admin() public {
        address outsider = makeAddr("outsider");
        address dummy = address(new MockAttester(address(eas), "Dummy"));
        vm.prank(outsider);
        vm.expectRevert();
        adapter.setEASAddress(dummy);
    }
}
