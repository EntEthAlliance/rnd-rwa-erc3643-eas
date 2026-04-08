// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {ValenceEASKernelAdapter} from "../../contracts/valence/ValenceEASKernelAdapter.sol";
import {VerificationOrbital} from "../../contracts/valence/modules/VerificationOrbital.sol";
import {RegistryOrbital} from "../../contracts/valence/modules/RegistryOrbital.sol";
import {TrustedAttestersOrbital} from "../../contracts/valence/modules/TrustedAttestersOrbital.sol";
import {IdentityMappingOrbital} from "../../contracts/valence/modules/IdentityMappingOrbital.sol";

contract ValenceEASKernelAdapterTest is Test {
    ValenceEASKernelAdapter internal adapter;

    function setUp() public {
        adapter = new ValenceEASKernelAdapter(address(this));
    }

    function test_deploysKernelAdapterAndOrbitals() public view {
        assertEq(adapter.kernelOwner(), address(this));
        assertTrue(address(adapter.verificationOrbital()) != address(0));
        assertTrue(address(adapter.registryOrbital()) != address(0));
        assertTrue(address(adapter.trustedAttestersOrbital()) != address(0));
        assertTrue(address(adapter.identityMappingOrbital()) != address(0));
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
