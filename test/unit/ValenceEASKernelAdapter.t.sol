// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {ValenceEASKernelAdapter} from "../../contracts/valence/ValenceEASKernelAdapter.sol";
import {VerificationOrbital} from "../../contracts/valence/modules/VerificationOrbital.sol";
import {RegistryOrbital} from "../../contracts/valence/modules/RegistryOrbital.sol";
import {TrustedAttestersOrbital} from "../../contracts/valence/modules/TrustedAttestersOrbital.sol";
import {IdentityMappingOrbital} from "../../contracts/valence/modules/IdentityMappingOrbital.sol";
import {MockValenceKernelRouting} from "../../contracts/mocks/MockValenceKernelRouting.sol";

contract ValenceEASKernelAdapterTest is Test {
    ValenceEASKernelAdapter internal adapter;

    address internal cutMultisig = address(0xA11CE);

    function setUp() public {
        ValenceEASKernelAdapter.GovernanceProfile memory profile = ValenceEASKernelAdapter.GovernanceProfile({
            cutMultisig: cutMultisig,
            minApprovals: 2,
            standardCutTimelock: 24 hours,
            emergencyCutTimelock: 1 hours
        });

        adapter = new ValenceEASKernelAdapter(address(this), profile);
    }

    function test_deploysKernelAdapterAndOrbitals() public view {
        assertEq(adapter.kernelOwner(), address(this));
        assertTrue(address(adapter.verificationOrbital()) != address(0));
        assertTrue(address(adapter.registryOrbital()) != address(0));
        assertTrue(address(adapter.trustedAttestersOrbital()) != address(0));
        assertTrue(address(adapter.identityMappingOrbital()) != address(0));
    }

    function test_governanceProfile_isExposedWithExpectedAssumptions() public view {
        ValenceEASKernelAdapter.GovernanceProfile memory profile = adapter.getGovernanceProfile();

        assertEq(profile.cutMultisig, cutMultisig);
        assertEq(profile.minApprovals, 2);
        assertEq(profile.standardCutTimelock, 24 hours);
        assertEq(profile.emergencyCutTimelock, 1 hours);
    }

    function test_constructor_revertsWhenGovernanceAssumptionsInvalid() public {
        ValenceEASKernelAdapter.GovernanceProfile memory badProfile = ValenceEASKernelAdapter.GovernanceProfile({
            cutMultisig: address(0),
            minApprovals: 1,
            standardCutTimelock: 1 hours,
            emergencyCutTimelock: 2 hours
        });

        vm.expectRevert(
            abi.encodeWithSelector(ValenceEASKernelAdapter.GovernanceInvariantViolation.selector, "multisig=0")
        );
        new ValenceEASKernelAdapter(address(this), badProfile);
    }

    function test_orbitalMetadata_isExposed() public view {
        VerificationOrbital.ModuleMetadata memory verificationMeta = adapter.verificationOrbital().moduleMetadata();
        RegistryOrbital.ModuleMetadata memory registryMeta = adapter.registryOrbital().moduleMetadata();
        TrustedAttestersOrbital.ModuleMetadata memory trustedMeta = adapter.trustedAttestersOrbital().moduleMetadata();
        IdentityMappingOrbital.ModuleMetadata memory identityMeta = adapter.identityMappingOrbital().moduleMetadata();

        assertEq(verificationMeta.id, "verification");
        assertEq(verificationMeta.version, "0.2.0-phase1");

        assertEq(registryMeta.id, "registry");
        assertEq(registryMeta.version, "0.2.0-phase1");

        assertEq(trustedMeta.id, "trusted-attesters");
        assertEq(identityMeta.id, "identity-mapping");
    }

    function test_exportedSelectors_containsExpectedCoreSelectors() public view {
        bytes4[] memory selectors = adapter.exportedSelectors();
        assertEq(selectors.length, 15);

        assertEq(selectors[0], VerificationOrbital.setDependencies.selector);
        assertEq(selectors[3], VerificationOrbital.isVerified.selector);
        assertEq(selectors[6], RegistryOrbital.setTopicSchemaMapping.selector);
        assertEq(selectors[10], TrustedAttestersOrbital.setTrustedAttester.selector);
        assertEq(selectors[13], IdentityMappingOrbital.setIdentity.selector);
    }

    function test_exportedRouteBindings_mapsSelectorsToCorrectOrbitals() public view {
        ValenceEASKernelAdapter.RouteBinding[] memory routes = adapter.exportedRouteBindings();
        assertEq(routes.length, 15);

        assertEq(routes[0].selector, VerificationOrbital.setDependencies.selector);
        assertEq(routes[0].orbital, address(adapter.verificationOrbital()));
        assertEq(routes[0].orbitalStorageSlot, adapter.VERIFICATION_STORAGE_SLOT());

        assertEq(routes[6].selector, RegistryOrbital.setTopicSchemaMapping.selector);
        assertEq(routes[6].orbital, address(adapter.registryOrbital()));
        assertEq(routes[6].orbitalStorageSlot, adapter.REGISTRY_STORAGE_SLOT());

        assertEq(routes[10].selector, TrustedAttestersOrbital.setTrustedAttester.selector);
        assertEq(routes[10].orbital, address(adapter.trustedAttestersOrbital()));
        assertEq(routes[10].orbitalStorageSlot, adapter.TRUSTED_ATTESTERS_STORAGE_SLOT());
    }

    function test_applyRoutesToKernel_bindsAllSelectorsForKernelApi() public {
        MockValenceKernelRouting kernel = new MockValenceKernelRouting();

        adapter.applyRoutesToKernel(address(kernel));

        assertEq(kernel.routeCount(), 15);

        (bytes4 selector0, address module0) = kernel.routeAt(0);
        assertEq(selector0, VerificationOrbital.setDependencies.selector);
        assertEq(module0, address(adapter.verificationOrbital()));

        (bytes4 selector14, address module14) = kernel.routeAt(14);
        assertEq(selector14, IdentityMappingOrbital.getIdentity.selector);
        assertEq(module14, address(adapter.identityMappingOrbital()));
    }

    function test_applyRoutesToKernel_revertsForNonOwner() public {
        MockValenceKernelRouting kernel = new MockValenceKernelRouting();

        vm.prank(address(0xBEEF));
        vm.expectRevert(ValenceEASKernelAdapter.Unauthorized.selector);
        adapter.applyRoutesToKernel(address(kernel));
    }

    function test_getOrbitalBindings_hasExpectedMapping() public view {
        ValenceEASKernelAdapter.OrbitalBinding[] memory bindings = adapter.getOrbitalBindings();
        assertEq(bindings.length, 4);

        assertEq(bindings[0].orbitalId, "verification");
        assertEq(bindings[0].orbital, address(adapter.verificationOrbital()));

        assertEq(bindings[1].orbitalId, "registry");
        assertEq(bindings[2].orbitalId, "trusted-attesters");
        assertEq(bindings[3].orbitalId, "identity-mapping");
    }

    function test_hasSelectorCollisions_returnsFalse() public view {
        assertFalse(adapter.hasSelectorCollisions());
    }
}
