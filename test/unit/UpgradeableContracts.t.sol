// SPDX-License-Identifier: Apache-2.0
// Copyright © 2026 Enterprise Ethereum Alliance Inc.
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

import {EASClaimVerifierUpgradeable} from "../../contracts/upgradeable/EASClaimVerifierUpgradeable.sol";
import {EASTrustedIssuersAdapterUpgradeable} from "../../contracts/upgradeable/EASTrustedIssuersAdapterUpgradeable.sol";
import {EASIdentityProxyUpgradeable} from "../../contracts/upgradeable/EASIdentityProxyUpgradeable.sol";

/**
 * @title UpgradeableContractsTest
 * @notice Unit tests for the UUPS variants (follow-up to #55).
 * @dev Verifies:
 *        - initialize() wires the admin into DEFAULT_ADMIN_ROLE and the
 *          contract-specific operational role.
 *        - initialize() with a zero admin reverts.
 *        - Calls via the ERC1967 proxy reach the correct implementation.
 *        - _authorizeUpgrade is DEFAULT_ADMIN_ROLE-gated (a non-admin caller
 *          is rejected before the upgrade lands).
 *
 *      Storage-slot arithmetic is enforced implicitly: changes to `__gap` are
 *      visible as compile-time assertions in the upgradeable contracts
 *      themselves (the Solidity layout is deterministic for fixed-size
 *      arrays); a dedicated test for slot indices would require cheatcodes
 *      that aren't portable across OZ versions, so it is not included here.
 */
contract UpgradeableContractsTest is Test {
    address internal admin = makeAddr("admin");
    address internal outsider = makeAddr("outsider");

    bytes32 internal constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 internal constant AGENT_ROLE = keccak256("AGENT_ROLE");
    bytes32 internal constant DEFAULT_ADMIN_ROLE = 0x00;

    // ============ Verifier ============

    function test_verifier_initialize_grants_roles() public {
        EASClaimVerifierUpgradeable impl = new EASClaimVerifierUpgradeable();
        bytes memory initData = abi.encodeWithSelector(EASClaimVerifierUpgradeable.initialize.selector, admin);
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        EASClaimVerifierUpgradeable v = EASClaimVerifierUpgradeable(address(proxy));

        assertTrue(v.hasRole(DEFAULT_ADMIN_ROLE, admin));
        assertTrue(v.hasRole(OPERATOR_ROLE, admin));
    }

    function test_verifier_initialize_zero_admin_reverts() public {
        EASClaimVerifierUpgradeable impl = new EASClaimVerifierUpgradeable();
        bytes memory initData = abi.encodeWithSelector(EASClaimVerifierUpgradeable.initialize.selector, address(0));
        vm.expectRevert();
        new ERC1967Proxy(address(impl), initData);
    }

    function test_verifier_double_initialize_reverts() public {
        EASClaimVerifierUpgradeable impl = new EASClaimVerifierUpgradeable();
        bytes memory initData = abi.encodeWithSelector(EASClaimVerifierUpgradeable.initialize.selector, admin);
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        EASClaimVerifierUpgradeable v = EASClaimVerifierUpgradeable(address(proxy));

        vm.expectRevert();
        v.initialize(admin);
    }

    function test_verifier_upgrade_requires_default_admin_role() public {
        EASClaimVerifierUpgradeable impl1 = new EASClaimVerifierUpgradeable();
        bytes memory initData = abi.encodeWithSelector(EASClaimVerifierUpgradeable.initialize.selector, admin);
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl1), initData);
        EASClaimVerifierUpgradeable v = EASClaimVerifierUpgradeable(address(proxy));

        EASClaimVerifierUpgradeable impl2 = new EASClaimVerifierUpgradeable();

        vm.prank(outsider);
        vm.expectRevert();
        v.upgradeToAndCall(address(impl2), "");

        vm.prank(admin);
        v.upgradeToAndCall(address(impl2), "");
    }

    // ============ Adapter ============

    function test_adapter_initialize_grants_roles() public {
        EASTrustedIssuersAdapterUpgradeable impl = new EASTrustedIssuersAdapterUpgradeable();
        bytes memory initData = abi.encodeWithSelector(EASTrustedIssuersAdapterUpgradeable.initialize.selector, admin);
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        EASTrustedIssuersAdapterUpgradeable a = EASTrustedIssuersAdapterUpgradeable(address(proxy));

        assertTrue(a.hasRole(DEFAULT_ADMIN_ROLE, admin));
        assertTrue(a.hasRole(OPERATOR_ROLE, admin));
    }

    function test_adapter_initialize_zero_admin_reverts() public {
        EASTrustedIssuersAdapterUpgradeable impl = new EASTrustedIssuersAdapterUpgradeable();
        bytes memory initData =
            abi.encodeWithSelector(EASTrustedIssuersAdapterUpgradeable.initialize.selector, address(0));
        vm.expectRevert();
        new ERC1967Proxy(address(impl), initData);
    }

    function test_adapter_upgrade_requires_default_admin_role() public {
        EASTrustedIssuersAdapterUpgradeable impl1 = new EASTrustedIssuersAdapterUpgradeable();
        bytes memory initData = abi.encodeWithSelector(EASTrustedIssuersAdapterUpgradeable.initialize.selector, admin);
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl1), initData);
        EASTrustedIssuersAdapterUpgradeable a = EASTrustedIssuersAdapterUpgradeable(address(proxy));

        EASTrustedIssuersAdapterUpgradeable impl2 = new EASTrustedIssuersAdapterUpgradeable();

        vm.prank(outsider);
        vm.expectRevert();
        a.upgradeToAndCall(address(impl2), "");

        vm.prank(admin);
        a.upgradeToAndCall(address(impl2), "");
    }

    // ============ Identity Proxy ============

    function test_identityProxy_initialize_grants_roles() public {
        EASIdentityProxyUpgradeable impl = new EASIdentityProxyUpgradeable();
        bytes memory initData = abi.encodeWithSelector(EASIdentityProxyUpgradeable.initialize.selector, admin);
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        EASIdentityProxyUpgradeable p = EASIdentityProxyUpgradeable(address(proxy));

        assertTrue(p.hasRole(DEFAULT_ADMIN_ROLE, admin));
        assertTrue(p.hasRole(AGENT_ROLE, admin));
        assertTrue(p.isAgent(admin));
    }

    function test_identityProxy_initialize_zero_admin_reverts() public {
        EASIdentityProxyUpgradeable impl = new EASIdentityProxyUpgradeable();
        bytes memory initData = abi.encodeWithSelector(EASIdentityProxyUpgradeable.initialize.selector, address(0));
        vm.expectRevert();
        new ERC1967Proxy(address(impl), initData);
    }

    function test_identityProxy_upgrade_requires_default_admin_role() public {
        EASIdentityProxyUpgradeable impl1 = new EASIdentityProxyUpgradeable();
        bytes memory initData = abi.encodeWithSelector(EASIdentityProxyUpgradeable.initialize.selector, admin);
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl1), initData);
        EASIdentityProxyUpgradeable p = EASIdentityProxyUpgradeable(address(proxy));

        EASIdentityProxyUpgradeable impl2 = new EASIdentityProxyUpgradeable();

        vm.prank(outsider);
        vm.expectRevert();
        p.upgradeToAndCall(address(impl2), "");

        vm.prank(admin);
        p.upgradeToAndCall(address(impl2), "");
    }

    // ============ Implementation ctor disables initializers ============

    function test_implementation_contracts_cannot_be_initialized_directly() public {
        EASClaimVerifierUpgradeable impl = new EASClaimVerifierUpgradeable();
        vm.expectRevert();
        impl.initialize(admin);
    }
}
