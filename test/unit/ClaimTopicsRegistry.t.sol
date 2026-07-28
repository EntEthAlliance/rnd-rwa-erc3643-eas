// SPDX-License-Identifier: Apache-2.0
// Copyright © 2026 Enterprise Ethereum Alliance Inc.
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {ClaimTopicsRegistry} from "../../contracts/ClaimTopicsRegistry.sol";
import {IClaimTopicsRegistry} from "../../contracts/interfaces/IClaimTopicsRegistry.sol";

/**
 * @title ClaimTopicsRegistryTest
 * @notice Unit tests for the production claim topics registry.
 */
contract ClaimTopicsRegistryTest is Test {
    ClaimTopicsRegistry internal registry;
    address internal admin;
    address internal stranger;

    function setUp() public {
        admin = makeAddr("admin");
        stranger = makeAddr("stranger");
        registry = new ClaimTopicsRegistry(admin);
    }

    // ============ Construction ============

    function test_constructor_grantsRolesToAdmin() public view {
        assertTrue(registry.hasRole(registry.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(registry.hasRole(registry.OPERATOR_ROLE(), admin));
    }

    function test_constructor_revertsOnZeroAdmin() public {
        vm.expectRevert(ClaimTopicsRegistry.ZeroAddressNotAllowed.selector);
        new ClaimTopicsRegistry(address(0));
    }

    // ============ addClaimTopic ============

    function test_addClaimTopic_addsAndEmits() public {
        vm.prank(admin);
        vm.expectEmit(true, false, false, false);
        emit IClaimTopicsRegistry.ClaimTopicAdded(1);
        registry.addClaimTopic(1);

        assertTrue(registry.hasClaimTopic(1));
        uint256[] memory topics = registry.getClaimTopics();
        assertEq(topics.length, 1);
        assertEq(topics[0], 1);
    }

    function test_addClaimTopic_revertsOnDuplicate() public {
        vm.startPrank(admin);
        registry.addClaimTopic(1);
        vm.expectRevert(abi.encodeWithSelector(ClaimTopicsRegistry.TopicAlreadyExists.selector, 1));
        registry.addClaimTopic(1);
        vm.stopPrank();
    }

    function test_addClaimTopic_revertsAtMaxTopics() public {
        vm.startPrank(admin);
        for (uint256 i = 0; i < registry.MAX_TOPICS(); i++) {
            registry.addClaimTopic(i);
        }
        vm.expectRevert(ClaimTopicsRegistry.MaxTopicsReached.selector);
        registry.addClaimTopic(999);
        vm.stopPrank();
    }

    function test_addClaimTopic_revertsForNonOperator() public {
        bytes32 operatorRole = registry.OPERATOR_ROLE();
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, stranger, operatorRole)
        );
        registry.addClaimTopic(1);
    }

    // ============ removeClaimTopic ============

    function test_removeClaimTopic_removesAndEmits() public {
        vm.startPrank(admin);
        registry.addClaimTopic(1);
        registry.addClaimTopic(2);
        registry.addClaimTopic(13);

        vm.expectEmit(true, false, false, false);
        emit IClaimTopicsRegistry.ClaimTopicRemoved(2);
        registry.removeClaimTopic(2);
        vm.stopPrank();

        assertFalse(registry.hasClaimTopic(2));
        assertTrue(registry.hasClaimTopic(1));
        assertTrue(registry.hasClaimTopic(13));
        assertEq(registry.getClaimTopics().length, 2);
    }

    function test_removeClaimTopic_revertsWhenAbsent() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(ClaimTopicsRegistry.TopicDoesNotExist.selector, 7));
        registry.removeClaimTopic(7);
    }

    function test_removeClaimTopic_revertsForNonOperator() public {
        vm.prank(admin);
        registry.addClaimTopic(1);

        bytes32 operatorRole = registry.OPERATOR_ROLE();
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, stranger, operatorRole)
        );
        registry.removeClaimTopic(1);
    }

    // ============ Re-add after removal ============

    function test_topicCanBeReaddedAfterRemoval() public {
        vm.startPrank(admin);
        registry.addClaimTopic(1);
        registry.removeClaimTopic(1);
        registry.addClaimTopic(1);
        vm.stopPrank();

        assertTrue(registry.hasClaimTopic(1));
        assertEq(registry.getClaimTopics().length, 1);
    }
}
