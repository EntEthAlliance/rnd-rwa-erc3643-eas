// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {EASTrustedIssuersAdapter} from "../../contracts/EASTrustedIssuersAdapter.sol";
import {IEASTrustedIssuersAdapter} from "../../contracts/interfaces/IEASTrustedIssuersAdapter.sol";

/**
 * @title EASTrustedIssuersAdapterTest
 * @notice Unit tests for the EASTrustedIssuersAdapter contract
 * @dev Tests cover all public functions with edge cases for 100% branch coverage
 */
contract EASTrustedIssuersAdapterTest is Test {
    EASTrustedIssuersAdapter public adapter;

    address public owner = address(this);
    address public attester1 = address(0x1111);
    address public attester2 = address(0x2222);
    address public attester3 = address(0x3333);
    address public notOwner = address(0x9999);

    uint256 public constant TOPIC_KYC = 1;
    uint256 public constant TOPIC_ACCREDITATION = 7;
    uint256 public constant TOPIC_COUNTRY = 3;

    event TrustedAttesterAdded(address indexed attester, uint256[] claimTopics);
    event TrustedAttesterRemoved(address indexed attester);
    event AttesterTopicsUpdated(address indexed attester, uint256[] claimTopics);

    function setUp() public {
        adapter = new EASTrustedIssuersAdapter(owner);
    }

    // ============ Constructor Tests ============

    function test_constructor_setsOwner() public view {
        assertEq(adapter.owner(), owner);
    }

    // ============ addTrustedAttester Tests ============

    function test_addTrustedAttester_success() public {
        uint256[] memory topics = new uint256[](2);
        topics[0] = TOPIC_KYC;
        topics[1] = TOPIC_ACCREDITATION;

        vm.expectEmit(true, false, false, true);
        emit TrustedAttesterAdded(attester1, topics);

        adapter.addTrustedAttester(attester1, topics);

        assertTrue(adapter.isTrustedAttester(attester1));
        assertTrue(adapter.isAttesterTrusted(attester1, TOPIC_KYC));
        assertTrue(adapter.isAttesterTrusted(attester1, TOPIC_ACCREDITATION));
        assertFalse(adapter.isAttesterTrusted(attester1, TOPIC_COUNTRY));
    }

    function test_addTrustedAttester_revertsIfZeroAddress() public {
        uint256[] memory topics = new uint256[](1);
        topics[0] = TOPIC_KYC;

        vm.expectRevert(IEASTrustedIssuersAdapter.ZeroAddressNotAllowed.selector);
        adapter.addTrustedAttester(address(0), topics);
    }

    function test_addTrustedAttester_revertsIfAlreadyTrusted() public {
        uint256[] memory topics = new uint256[](1);
        topics[0] = TOPIC_KYC;

        adapter.addTrustedAttester(attester1, topics);

        vm.expectRevert(abi.encodeWithSelector(IEASTrustedIssuersAdapter.AttesterAlreadyTrusted.selector, attester1));
        adapter.addTrustedAttester(attester1, topics);
    }

    function test_addTrustedAttester_revertsIfEmptyTopics() public {
        uint256[] memory topics = new uint256[](0);

        vm.expectRevert(IEASTrustedIssuersAdapter.EmptyClaimTopics.selector);
        adapter.addTrustedAttester(attester1, topics);
    }

    function test_addTrustedAttester_revertsIfNotOwner() public {
        uint256[] memory topics = new uint256[](1);
        topics[0] = TOPIC_KYC;

        vm.prank(notOwner);
        vm.expectRevert();
        adapter.addTrustedAttester(attester1, topics);
    }

    function test_addTrustedAttester_maxAttesters() public {
        uint256[] memory topics = new uint256[](1);
        topics[0] = TOPIC_KYC;

        // Add 50 attesters (max) using makeAddr for safe address generation
        for (uint256 i = 0; i < 50; i++) {
            adapter.addTrustedAttester(makeAddr(string(abi.encodePacked("attester", i))), topics);
        }

        // 51st should fail
        vm.expectRevert("MaxAttestersReached");
        adapter.addTrustedAttester(makeAddr("attester50"), topics);
    }

    function test_addTrustedAttester_maxTopicsPerAttester() public {
        uint256[] memory topics = new uint256[](16);
        for (uint256 i = 0; i < 16; i++) {
            topics[i] = i + 1;
        }

        vm.expectRevert("MaxTopicsPerAttesterReached");
        adapter.addTrustedAttester(attester1, topics);
    }

    // ============ removeTrustedAttester Tests ============

    function test_removeTrustedAttester_success() public {
        uint256[] memory topics = new uint256[](2);
        topics[0] = TOPIC_KYC;
        topics[1] = TOPIC_ACCREDITATION;

        adapter.addTrustedAttester(attester1, topics);
        assertTrue(adapter.isTrustedAttester(attester1));

        vm.expectEmit(true, false, false, false);
        emit TrustedAttesterRemoved(attester1);

        adapter.removeTrustedAttester(attester1);

        assertFalse(adapter.isTrustedAttester(attester1));
        assertFalse(adapter.isAttesterTrusted(attester1, TOPIC_KYC));
        assertFalse(adapter.isAttesterTrusted(attester1, TOPIC_ACCREDITATION));
    }

    function test_removeTrustedAttester_revertsIfNotTrusted() public {
        vm.expectRevert(abi.encodeWithSelector(IEASTrustedIssuersAdapter.AttesterNotTrusted.selector, attester1));
        adapter.removeTrustedAttester(attester1);
    }

    function test_removeTrustedAttester_revertsIfNotOwner() public {
        uint256[] memory topics = new uint256[](1);
        topics[0] = TOPIC_KYC;
        adapter.addTrustedAttester(attester1, topics);

        vm.prank(notOwner);
        vm.expectRevert();
        adapter.removeTrustedAttester(attester1);
    }

    function test_removeTrustedAttester_removesFromTopicArrays() public {
        uint256[] memory topics = new uint256[](1);
        topics[0] = TOPIC_KYC;

        adapter.addTrustedAttester(attester1, topics);
        adapter.addTrustedAttester(attester2, topics);

        address[] memory attesters = adapter.getTrustedAttestersForTopic(TOPIC_KYC);
        assertEq(attesters.length, 2);

        adapter.removeTrustedAttester(attester1);

        attesters = adapter.getTrustedAttestersForTopic(TOPIC_KYC);
        assertEq(attesters.length, 1);
        assertEq(attesters[0], attester2);
    }

    // ============ updateAttesterTopics Tests ============

    function test_updateAttesterTopics_success() public {
        uint256[] memory initialTopics = new uint256[](1);
        initialTopics[0] = TOPIC_KYC;

        adapter.addTrustedAttester(attester1, initialTopics);

        uint256[] memory newTopics = new uint256[](2);
        newTopics[0] = TOPIC_ACCREDITATION;
        newTopics[1] = TOPIC_COUNTRY;

        vm.expectEmit(true, false, false, true);
        emit AttesterTopicsUpdated(attester1, newTopics);

        adapter.updateAttesterTopics(attester1, newTopics);

        assertFalse(adapter.isAttesterTrusted(attester1, TOPIC_KYC));
        assertTrue(adapter.isAttesterTrusted(attester1, TOPIC_ACCREDITATION));
        assertTrue(adapter.isAttesterTrusted(attester1, TOPIC_COUNTRY));
    }

    function test_updateAttesterTopics_revertsIfNotTrusted() public {
        uint256[] memory topics = new uint256[](1);
        topics[0] = TOPIC_KYC;

        vm.expectRevert(abi.encodeWithSelector(IEASTrustedIssuersAdapter.AttesterNotTrusted.selector, attester1));
        adapter.updateAttesterTopics(attester1, topics);
    }

    function test_updateAttesterTopics_revertsIfEmptyTopics() public {
        uint256[] memory initialTopics = new uint256[](1);
        initialTopics[0] = TOPIC_KYC;
        adapter.addTrustedAttester(attester1, initialTopics);

        uint256[] memory emptyTopics = new uint256[](0);

        vm.expectRevert(IEASTrustedIssuersAdapter.EmptyClaimTopics.selector);
        adapter.updateAttesterTopics(attester1, emptyTopics);
    }

    function test_updateAttesterTopics_revertsIfTooManyTopics() public {
        uint256[] memory initialTopics = new uint256[](1);
        initialTopics[0] = TOPIC_KYC;
        adapter.addTrustedAttester(attester1, initialTopics);

        uint256[] memory tooManyTopics = new uint256[](16);
        for (uint256 i = 0; i < 16; i++) {
            tooManyTopics[i] = i + 1;
        }

        vm.expectRevert("MaxTopicsPerAttesterReached");
        adapter.updateAttesterTopics(attester1, tooManyTopics);
    }

    // ============ View Function Tests ============

    function test_getTrustedAttesters_returnsAll() public {
        uint256[] memory topics = new uint256[](1);
        topics[0] = TOPIC_KYC;

        adapter.addTrustedAttester(attester1, topics);
        adapter.addTrustedAttester(attester2, topics);
        adapter.addTrustedAttester(attester3, topics);

        address[] memory attesters = adapter.getTrustedAttesters();
        assertEq(attesters.length, 3);
    }

    function test_getTrustedAttestersForTopic_returnsCorrectList() public {
        uint256[] memory topics1 = new uint256[](1);
        topics1[0] = TOPIC_KYC;

        uint256[] memory topics2 = new uint256[](2);
        topics2[0] = TOPIC_KYC;
        topics2[1] = TOPIC_ACCREDITATION;

        adapter.addTrustedAttester(attester1, topics1);
        adapter.addTrustedAttester(attester2, topics2);

        address[] memory kycAttesters = adapter.getTrustedAttestersForTopic(TOPIC_KYC);
        assertEq(kycAttesters.length, 2);

        address[] memory accreditationAttesters = adapter.getTrustedAttestersForTopic(TOPIC_ACCREDITATION);
        assertEq(accreditationAttesters.length, 1);
        assertEq(accreditationAttesters[0], attester2);
    }

    function test_getAttesterTopics_returnsCorrectTopics() public {
        uint256[] memory topics = new uint256[](3);
        topics[0] = TOPIC_KYC;
        topics[1] = TOPIC_ACCREDITATION;
        topics[2] = TOPIC_COUNTRY;

        adapter.addTrustedAttester(attester1, topics);

        uint256[] memory returnedTopics = adapter.getAttesterTopics(attester1);
        assertEq(returnedTopics.length, 3);
        assertEq(returnedTopics[0], TOPIC_KYC);
        assertEq(returnedTopics[1], TOPIC_ACCREDITATION);
        assertEq(returnedTopics[2], TOPIC_COUNTRY);
    }

    function test_isAttesterTrusted_returnsFalseForUnknownAttester() public view {
        assertFalse(adapter.isAttesterTrusted(attester1, TOPIC_KYC));
    }

    function test_isTrustedAttester_returnsFalseForUnknownAttester() public view {
        assertFalse(adapter.isTrustedAttester(attester1));
    }

    // ============ Edge Cases ============

    function test_multipleAttesters_sameTopics() public {
        uint256[] memory topics = new uint256[](1);
        topics[0] = TOPIC_KYC;

        adapter.addTrustedAttester(attester1, topics);
        adapter.addTrustedAttester(attester2, topics);
        adapter.addTrustedAttester(attester3, topics);

        address[] memory attesters = adapter.getTrustedAttestersForTopic(TOPIC_KYC);
        assertEq(attesters.length, 3);

        // Remove middle attester
        adapter.removeTrustedAttester(attester2);

        attesters = adapter.getTrustedAttestersForTopic(TOPIC_KYC);
        assertEq(attesters.length, 2);
        // Last element moved to removed position
        assertTrue(attesters[0] == attester1 || attesters[0] == attester3);
        assertTrue(attesters[1] == attester1 || attesters[1] == attester3);
    }
}
