// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {EASIdentityProxy} from "../../contracts/EASIdentityProxy.sol";
import {IEASIdentityProxy} from "../../contracts/interfaces/IEASIdentityProxy.sol";

/**
 * @title EASIdentityProxyTest
 * @notice Unit tests for the EASIdentityProxy contract
 */
contract EASIdentityProxyTest is Test {
    EASIdentityProxy public proxy;

    address public owner = address(this);
    address public agent = makeAddr("agent");
    address public wallet1 = makeAddr("wallet1");
    address public wallet2 = makeAddr("wallet2");
    address public wallet3 = makeAddr("wallet3");
    address public identity1 = makeAddr("identity1");
    address public identity2 = makeAddr("identity2");
    address public notAuthorized = makeAddr("notAuthorized");

    event WalletRegistered(address indexed wallet, address indexed identity);
    event WalletRemoved(address indexed wallet, address indexed identity);
    event AgentAdded(address indexed agent);
    event AgentRemoved(address indexed agent);

    function setUp() public {
        proxy = new EASIdentityProxy(owner);
        proxy.addAgent(agent);
    }

    // ============ Constructor Tests ============

    function test_constructor_setsOwner() public view {
        assertEq(proxy.owner(), owner);
    }

    // ============ Agent Management Tests ============

    function test_addAgent_success() public {
        address newAgent = address(0xA6E2);

        vm.expectEmit(true, false, false, false);
        emit AgentAdded(newAgent);

        proxy.addAgent(newAgent);
        assertTrue(proxy.isAgent(newAgent));
    }

    function test_addAgent_revertsIfZeroAddress() public {
        vm.expectRevert(IEASIdentityProxy.ZeroAddressNotAllowed.selector);
        proxy.addAgent(address(0));
    }

    function test_addAgent_revertsIfNotOwner() public {
        vm.prank(notAuthorized);
        vm.expectRevert();
        proxy.addAgent(address(0xA6E3));
    }

    function test_removeAgent_success() public {
        vm.expectEmit(true, false, false, false);
        emit AgentRemoved(agent);

        proxy.removeAgent(agent);
        assertFalse(proxy.isAgent(agent));
    }

    function test_removeAgent_revertsIfNotOwner() public {
        vm.prank(notAuthorized);
        vm.expectRevert();
        proxy.removeAgent(agent);
    }

    // ============ registerWallet Tests ============

    function test_registerWallet_asOwner() public {
        vm.expectEmit(true, true, false, false);
        emit WalletRegistered(wallet1, identity1);

        proxy.registerWallet(wallet1, identity1);

        assertEq(proxy.getIdentity(wallet1), identity1);
        assertTrue(proxy.isRegistered(wallet1));
    }

    function test_registerWallet_asAgent() public {
        vm.prank(agent);
        proxy.registerWallet(wallet1, identity1);

        assertEq(proxy.getIdentity(wallet1), identity1);
    }

    function test_registerWallet_asIdentity() public {
        vm.prank(identity1);
        proxy.registerWallet(wallet1, identity1);

        assertEq(proxy.getIdentity(wallet1), identity1);
    }

    function test_registerWallet_revertsIfNotAuthorized() public {
        vm.prank(notAuthorized);
        vm.expectRevert(IEASIdentityProxy.NotAuthorized.selector);
        proxy.registerWallet(wallet1, identity1);
    }

    function test_registerWallet_revertsIfWalletZero() public {
        vm.expectRevert(IEASIdentityProxy.ZeroAddressNotAllowed.selector);
        proxy.registerWallet(address(0), identity1);
    }

    function test_registerWallet_revertsIfIdentityZero() public {
        vm.expectRevert(IEASIdentityProxy.ZeroAddressNotAllowed.selector);
        proxy.registerWallet(wallet1, address(0));
    }

    function test_registerWallet_revertsIfAlreadyRegisteredToDifferentIdentity() public {
        proxy.registerWallet(wallet1, identity1);

        vm.expectRevert(abi.encodeWithSelector(
            IEASIdentityProxy.WalletAlreadyRegistered.selector,
            wallet1,
            identity1
        ));
        proxy.registerWallet(wallet1, identity2);
    }

    function test_registerWallet_noOpIfSameIdentity() public {
        proxy.registerWallet(wallet1, identity1);

        // Should not revert, no-op
        proxy.registerWallet(wallet1, identity1);

        assertEq(proxy.getIdentity(wallet1), identity1);
    }

    // ============ removeWallet Tests ============

    function test_removeWallet_asOwner() public {
        proxy.registerWallet(wallet1, identity1);

        vm.expectEmit(true, true, false, false);
        emit WalletRemoved(wallet1, identity1);

        proxy.removeWallet(wallet1);

        assertFalse(proxy.isRegistered(wallet1));
        // After removal, getIdentity returns wallet itself
        assertEq(proxy.getIdentity(wallet1), wallet1);
    }

    function test_removeWallet_asAgent() public {
        proxy.registerWallet(wallet1, identity1);

        vm.prank(agent);
        proxy.removeWallet(wallet1);

        assertFalse(proxy.isRegistered(wallet1));
    }

    function test_removeWallet_asIdentity() public {
        proxy.registerWallet(wallet1, identity1);

        vm.prank(identity1);
        proxy.removeWallet(wallet1);

        assertFalse(proxy.isRegistered(wallet1));
    }

    function test_removeWallet_revertsIfNotAuthorized() public {
        proxy.registerWallet(wallet1, identity1);

        vm.prank(notAuthorized);
        vm.expectRevert(IEASIdentityProxy.NotAuthorized.selector);
        proxy.removeWallet(wallet1);
    }

    function test_removeWallet_noOpIfNotRegistered() public {
        // Should not revert, just no-op
        proxy.removeWallet(wallet1);
        assertFalse(proxy.isRegistered(wallet1));
    }

    // ============ getIdentity Tests ============

    function test_getIdentity_returnsWalletIfNotRegistered() public view {
        assertEq(proxy.getIdentity(wallet1), wallet1);
    }

    function test_getIdentity_returnsMappedIdentity() public {
        proxy.registerWallet(wallet1, identity1);
        assertEq(proxy.getIdentity(wallet1), identity1);
    }

    // ============ getWallets Tests ============

    function test_getWallets_returnsAllLinkedWallets() public {
        proxy.registerWallet(wallet1, identity1);
        proxy.registerWallet(wallet2, identity1);
        proxy.registerWallet(wallet3, identity1);

        address[] memory wallets = proxy.getWallets(identity1);
        assertEq(wallets.length, 3);
    }

    function test_getWallets_returnsEmptyIfNoWallets() public view {
        address[] memory wallets = proxy.getWallets(identity1);
        assertEq(wallets.length, 0);
    }

    function test_getWallets_updatesAfterRemoval() public {
        proxy.registerWallet(wallet1, identity1);
        proxy.registerWallet(wallet2, identity1);
        proxy.registerWallet(wallet3, identity1);

        proxy.removeWallet(wallet2);

        address[] memory wallets = proxy.getWallets(identity1);
        assertEq(wallets.length, 2);
    }

    // ============ isRegistered Tests ============

    function test_isRegistered_returnsTrueIfRegistered() public {
        proxy.registerWallet(wallet1, identity1);
        assertTrue(proxy.isRegistered(wallet1));
    }

    function test_isRegistered_returnsFalseIfNotRegistered() public view {
        assertFalse(proxy.isRegistered(wallet1));
    }

    // ============ batchRegisterWallets Tests ============

    function test_batchRegisterWallets_success() public {
        address[] memory wallets = new address[](3);
        wallets[0] = wallet1;
        wallets[1] = wallet2;
        wallets[2] = wallet3;

        proxy.batchRegisterWallets(wallets, identity1);

        assertEq(proxy.getIdentity(wallet1), identity1);
        assertEq(proxy.getIdentity(wallet2), identity1);
        assertEq(proxy.getIdentity(wallet3), identity1);

        address[] memory linkedWallets = proxy.getWallets(identity1);
        assertEq(linkedWallets.length, 3);
    }

    function test_batchRegisterWallets_revertsIfIdentityZero() public {
        address[] memory wallets = new address[](1);
        wallets[0] = wallet1;

        vm.expectRevert(IEASIdentityProxy.ZeroAddressNotAllowed.selector);
        proxy.batchRegisterWallets(wallets, address(0));
    }

    function test_batchRegisterWallets_revertsIfWalletZero() public {
        address[] memory wallets = new address[](2);
        wallets[0] = wallet1;
        wallets[1] = address(0);

        vm.expectRevert(IEASIdentityProxy.ZeroAddressNotAllowed.selector);
        proxy.batchRegisterWallets(wallets, identity1);
    }

    function test_batchRegisterWallets_skipsAlreadyRegistered() public {
        proxy.registerWallet(wallet1, identity1);

        address[] memory wallets = new address[](2);
        wallets[0] = wallet1;
        wallets[1] = wallet2;

        // Should not revert, just skip wallet1
        proxy.batchRegisterWallets(wallets, identity1);

        address[] memory linkedWallets = proxy.getWallets(identity1);
        assertEq(linkedWallets.length, 2);
    }

    function test_batchRegisterWallets_revertsIfDifferentIdentity() public {
        proxy.registerWallet(wallet1, identity1);

        address[] memory wallets = new address[](2);
        wallets[0] = wallet1;
        wallets[1] = wallet2;

        vm.expectRevert(abi.encodeWithSelector(
            IEASIdentityProxy.WalletAlreadyRegistered.selector,
            wallet1,
            identity1
        ));
        proxy.batchRegisterWallets(wallets, identity2);
    }

    function test_batchRegisterWallets_asIdentity() public {
        address[] memory wallets = new address[](2);
        wallets[0] = wallet1;
        wallets[1] = wallet2;

        vm.prank(identity1);
        proxy.batchRegisterWallets(wallets, identity1);

        assertEq(proxy.getIdentity(wallet1), identity1);
        assertEq(proxy.getIdentity(wallet2), identity1);
    }

    // ============ Edge Cases ============

    function test_removeWallet_correctlyUpdatesArrayIndexes() public {
        proxy.registerWallet(wallet1, identity1);
        proxy.registerWallet(wallet2, identity1);
        proxy.registerWallet(wallet3, identity1);

        // Remove middle wallet
        proxy.removeWallet(wallet2);

        // Check remaining wallets are still correctly linked
        assertEq(proxy.getIdentity(wallet1), identity1);
        assertFalse(proxy.isRegistered(wallet2));
        assertEq(proxy.getIdentity(wallet3), identity1);

        address[] memory wallets = proxy.getWallets(identity1);
        assertEq(wallets.length, 2);
    }
}
