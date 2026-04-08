// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {VerificationOrbital} from "./modules/VerificationOrbital.sol";
import {RegistryOrbital} from "./modules/RegistryOrbital.sol";
import {TrustedAttestersOrbital} from "./modules/TrustedAttestersOrbital.sol";
import {IdentityMappingOrbital} from "./modules/IdentityMappingOrbital.sol";

/**
 * @title ValenceEASKernelAdapter
 * @notice Phase-1 adapter exposing orbital boundaries, selector inventory, and collision controls.
 * @dev This contract does not alter the production verifier path; it is an isolated Valence-native scaffold.
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
    TrustedAttestersOrbital public immutable trustedAttestersOrbital;
    IdentityMappingOrbital public immutable identityMappingOrbital;

    bytes32 public constant ADAPTER_STORAGE_SLOT = keccak256("eea.valence.adapter.storage.v1");

    constructor(address owner_) {
        require(owner_ != address(0), "owner=0");
        kernelOwner = owner_;

        registryOrbital = new RegistryOrbital(owner_);
        trustedAttestersOrbital = new TrustedAttestersOrbital(owner_);
        identityMappingOrbital = new IdentityMappingOrbital(owner_);
        verificationOrbital = new VerificationOrbital(
            owner_, address(0), address(registryOrbital), address(trustedAttestersOrbital), address(identityMappingOrbital)
        );
    }

    function getOrbitalBindings() external view returns (OrbitalBinding[] memory bindings) {
        bindings = new OrbitalBinding[](4);
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
        bindings[2] = OrbitalBinding({
            orbitalId: "trusted-attesters",
            orbital: address(trustedAttestersOrbital),
            storageSlot: keccak256("eea.valence.orbital.trusted-attesters.storage.v1")
        });
        bindings[3] = OrbitalBinding({
            orbitalId: "identity-mapping",
            orbital: address(identityMappingOrbital),
            storageSlot: keccak256("eea.valence.orbital.identity-mapping.storage.v1")
        });
    }

    function exportedSelectors() external view returns (bytes4[] memory selectors) {
        bytes4[] memory verificationSelectors = verificationOrbital.exportedSelectors();
        bytes4[] memory registrySelectors = registryOrbital.exportedSelectors();
        bytes4[] memory trustedSelectors = trustedAttestersOrbital.exportedSelectors();
        bytes4[] memory identitySelectors = identityMappingOrbital.exportedSelectors();

        selectors = new bytes4[](
            verificationSelectors.length + registrySelectors.length + trustedSelectors.length + identitySelectors.length
        );

        uint256 idx;
        idx = _append(selectors, idx, verificationSelectors);
        idx = _append(selectors, idx, registrySelectors);
        idx = _append(selectors, idx, trustedSelectors);
        _append(selectors, idx, identitySelectors);
    }

    function hasSelectorCollisions() external view returns (bool) {
        bytes4[] memory selectors = this.exportedSelectors();
        for (uint256 i = 0; i < selectors.length; i++) {
            for (uint256 j = i + 1; j < selectors.length; j++) {
                if (selectors[i] == selectors[j]) {
                    return true;
                }
            }
        }
        return false;
    }

    function _append(bytes4[] memory output, uint256 idx, bytes4[] memory source) internal pure returns (uint256) {
        for (uint256 i = 0; i < source.length; i++) {
            output[idx++] = source[i];
        }
        return idx;
    }
}
