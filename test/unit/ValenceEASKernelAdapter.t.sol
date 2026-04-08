// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {ValenceEASKernelAdapter} from "../../contracts/valence/ValenceEASKernelAdapter.sol";
import {VerificationOrbital} from "../../contracts/valence/modules/VerificationOrbital.sol";
import {RegistryOrbital} from "../../contracts/valence/modules/RegistryOrbital.sol";

contract ValenceEASKernelAdapterTest is Test {
    ValenceEASKernelAdapter internal adapter;

    function setUp() public {
        adapter = new ValenceEASKernelAdapter(address(this));
    }

    function test_deploysKernelAdapterAndOrbitals() public view {
        assertEq(adapter.kernelOwner(), address(this));
        assertTrue(address(adapter.verificationOrbital()) != address(0));
        assertTrue(address(adapter.registryOrbital()) != address(0));
    }

    function test_orbitalMetadata_isExposed() public view {
        VerificationOrbital.ModuleMetadata memory verificationMeta = adapter.verificationOrbital().moduleMetadata();
        RegistryOrbital.ModuleMetadata memory registryMeta = adapter.registryOrbital().moduleMetadata();

        assertEq(verificationMeta.id, "verification");
        assertEq(verificationMeta.version, "0.1.0-spike");

        assertEq(registryMeta.id, "registry");
        assertEq(registryMeta.version, "0.1.0-spike");
    }

    function test_exportedSelectors_containsExpectedCoreSelectors() public view {
        bytes4[] memory selectors = adapter.exportedSelectors();

        assertEq(selectors.length, 5);
        assertEq(selectors[0], VerificationOrbital.isVerified.selector);
        assertEq(selectors[1], VerificationOrbital.verifyTopic.selector);
        assertEq(selectors[2], RegistryOrbital.setTopicSchemaMapping.selector);
        assertEq(selectors[3], RegistryOrbital.getSchemaUID.selector);
        assertEq(selectors[4], RegistryOrbital.registerAttestation.selector);
    }

    function test_getOrbitalBindings_hasExpectedMapping() public view {
        ValenceEASKernelAdapter.OrbitalBinding[] memory bindings = adapter.getOrbitalBindings();
        assertEq(bindings.length, 2);

        assertEq(bindings[0].orbitalId, "verification");
        assertEq(bindings[0].orbital, address(adapter.verificationOrbital()));

        assertEq(bindings[1].orbitalId, "registry");
        assertEq(bindings[1].orbital, address(adapter.registryOrbital()));
    }
}
