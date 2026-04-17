// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BridgeHarness} from "../helpers/BridgeHarness.sol";
import {IEASIdentityProxy} from "../../contracts/interfaces/IEASIdentityProxy.sol";

/**
 * @title EASIdentityProxyTest
 * @notice Unit tests for the AccessControl-gated identity proxy.
 */
contract EASIdentityProxyTest is BridgeHarness {
    address internal investor;
    address internal wallet;

    function setUp() public {
        _setupBridge();
        investor = makeAddr("investor");
        wallet = makeAddr("wallet");
    }

    function test_registerWallet_requires_agent_role() public {
        vm.prank(investor);
        vm.expectRevert(IEASIdentityProxy.NotAuthorized.selector);
        identityProxy.registerWallet(wallet, investor);
    }

    function test_registerWallet_rejects_self_identity_registration() public {
        // audit C-3 consequence: the identity cannot register itself.
        vm.prank(investor);
        vm.expectRevert(IEASIdentityProxy.NotAuthorized.selector);
        identityProxy.registerWallet(wallet, investor);
    }

    function test_registerWallet_succeeds_as_agent() public {
        vm.prank(tokenIssuer);
        identityProxy.registerWallet(wallet, investor);
        assertEq(identityProxy.getIdentity(wallet), investor);
    }

    function test_addAgent_grants_role() public {
        address agent = makeAddr("agent");
        vm.prank(tokenIssuer);
        identityProxy.addAgent(agent);
        assertTrue(identityProxy.isAgent(agent));

        vm.prank(agent);
        identityProxy.registerWallet(wallet, investor);
        assertEq(identityProxy.getIdentity(wallet), investor);
    }

    function test_removeAgent_revokes_role() public {
        address agent = makeAddr("agent");
        vm.prank(tokenIssuer);
        identityProxy.addAgent(agent);
        vm.prank(tokenIssuer);
        identityProxy.removeAgent(agent);

        vm.prank(agent);
        vm.expectRevert(IEASIdentityProxy.NotAuthorized.selector);
        identityProxy.registerWallet(wallet, investor);
    }

    function test_batchRegisterWallets() public {
        address w1 = makeAddr("w1");
        address w2 = makeAddr("w2");
        address[] memory wallets = new address[](2);
        wallets[0] = w1;
        wallets[1] = w2;

        vm.prank(tokenIssuer);
        identityProxy.batchRegisterWallets(wallets, investor);

        assertEq(identityProxy.getIdentity(w1), investor);
        assertEq(identityProxy.getIdentity(w2), investor);
        address[] memory got = identityProxy.getWallets(investor);
        assertEq(got.length, 2);
    }

    function test_removeWallet() public {
        vm.prank(tokenIssuer);
        identityProxy.registerWallet(wallet, investor);
        vm.prank(tokenIssuer);
        identityProxy.removeWallet(wallet);

        assertEq(identityProxy.getIdentity(wallet), wallet); // fallback to wallet itself
        assertFalse(identityProxy.isRegistered(wallet));
    }

    function test_addAgent_requires_admin() public {
        address outsider = makeAddr("outsider");
        vm.prank(outsider);
        vm.expectRevert();
        identityProxy.addAgent(outsider);
    }
}
