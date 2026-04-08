// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {VerificationOrbital} from "./modules/VerificationOrbital.sol";
import {RegistryOrbital} from "./modules/RegistryOrbital.sol";

/**
 * @title ValenceEASKernelAdapter (Spike)
 * @notice Thin adapter that expresses how current EAS verifier responsibilities map into Valence orbitals.
 * @dev Spike-only: no delegatecall/router behavior yet. Keeps production path untouched.
 */
contract ValenceEASKernelAdapter {
    struct OrbitalBinding {
        string orbitalId;
        address orbital;
        bytes32 storageSlot;
    }

    address public immutable kernelOwner;
    VerificationOrbital public immutable verificationOrbital;
    RegistryOrbital public immutable registryOrbital;

    /// @notice TODO(valence): replace with final kernel slot after Valence storage conventions are locked.
    bytes32 public constant ADAPTER_STORAGE_SLOT = keccak256("eea.valence.adapter.storage.v1");

    constructor(address owner_) {
        require(owner_ != address(0), "owner=0");
        kernelOwner = owner_;

        verificationOrbital = new VerificationOrbital();
        registryOrbital = new RegistryOrbital();
    }

    function getOrbitalBindings() external view returns (OrbitalBinding[] memory bindings) {
        bindings = new OrbitalBinding[](2);
        bindings[0] = OrbitalBinding({
            orbitalId: "verification",
            orbital: address(verificationOrbital),
            storageSlot: keccak256("eea.valence.orbital.verification.storage.v1")
        });
        bindings[1] = OrbitalBinding({
            orbitalId: "registry",
            orbital: address(registryOrbital),
            storageSlot: keccak256("eea.valence.orbital.registry.storage.v1")
        });

        // TODO(valence): bind selectors to orbitals once kernel router interface is finalized.
    }

    function exportedSelectors() external view returns (bytes4[] memory selectors) {
        bytes4[] memory verificationSelectors = verificationOrbital.exportedSelectors();
        bytes4[] memory registrySelectors = registryOrbital.exportedSelectors();

        selectors = new bytes4[](verificationSelectors.length + registrySelectors.length);

        for (uint256 i = 0; i < verificationSelectors.length; i++) {
            selectors[i] = verificationSelectors[i];
        }
        for (uint256 j = 0; j < registrySelectors.length; j++) {
            selectors[verificationSelectors.length + j] = registrySelectors[j];
        }

        // TODO(valence): validate collisions against legacy EIP-2535 selector table before cutover.
    }
}
