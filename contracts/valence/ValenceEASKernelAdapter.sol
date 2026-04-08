// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {VerificationOrbital} from "./modules/VerificationOrbital.sol";
import {RegistryOrbital} from "./modules/RegistryOrbital.sol";
import {TrustedAttestersOrbital} from "./modules/TrustedAttestersOrbital.sol";
import {IdentityMappingOrbital} from "./modules/IdentityMappingOrbital.sol";

interface IValenceKernelRouting {
    struct SelectorRoute {
        bytes4 selector;
        address module;
    }

    function applySelectorRoutes(SelectorRoute[] calldata routes) external;
}

/**
 * @title ValenceEASKernelAdapter
 * @notice Phase-2-ready adapter exposing orbital boundaries, governance assumptions, and selector routing plan.
 * @dev This contract does not alter the production verifier path; it is an isolated Valence-native scaffold.
 */
contract ValenceEASKernelAdapter {
    struct OrbitalBinding {
        string orbitalId;
        address orbital;
        bytes32 storageSlot;
    }

    struct GovernanceProfile {
        address cutMultisig;
        uint8 minApprovals;
        uint48 standardCutTimelock;
        uint48 emergencyCutTimelock;
    }

    struct RouteBinding {
        bytes4 selector;
        address orbital;
        bytes32 orbitalStorageSlot;
    }

    enum SelectorChangeKind {
        Add,
        Replace,
        Remove
    }

    enum CutPath {
        Standard,
        Emergency
    }

    struct SelectorChange {
        bytes4 selector;
        address module;
        SelectorChangeKind kind;
    }

    error Unauthorized();
    error GovernanceInvariantViolation(string reason);

    uint8 public constant MIN_MULTISIG_APPROVALS = 2;
    uint48 public constant MIN_STANDARD_CUT_TIMELOCK = 24 hours;
    uint48 public constant MIN_EMERGENCY_CUT_TIMELOCK = 1 hours;

    address public immutable kernelOwner;
    VerificationOrbital public immutable verificationOrbital;
    RegistryOrbital public immutable registryOrbital;
    TrustedAttestersOrbital public immutable trustedAttestersOrbital;
    IdentityMappingOrbital public immutable identityMappingOrbital;

    GovernanceProfile private _governanceProfile;

    bytes32 public constant ADAPTER_STORAGE_SLOT = keccak256("eea.valence.adapter.storage.v1");
    bytes32 public constant VERIFICATION_STORAGE_SLOT = keccak256("eea.valence.orbital.verification.storage.v1");
    bytes32 public constant REGISTRY_STORAGE_SLOT = keccak256("eea.valence.orbital.registry.storage.v1");
    bytes32 public constant TRUSTED_ATTESTERS_STORAGE_SLOT =
        keccak256("eea.valence.orbital.trusted-attesters.storage.v1");
    bytes32 public constant IDENTITY_MAPPING_STORAGE_SLOT =
        keccak256("eea.valence.orbital.identity-mapping.storage.v1");

    event GovernanceProfileConfigured(
        address indexed cutMultisig, uint8 minApprovals, uint48 standardCutTimelock, uint48 emergencyCutTimelock
    );
    event KernelRoutesApplied(address indexed kernel, uint256 routeCount);

    constructor(address owner_, GovernanceProfile memory profile_) {
        require(owner_ != address(0), "owner=0");
        kernelOwner = owner_;

        _validateGovernanceProfile(profile_);
        _governanceProfile = profile_;

        registryOrbital = new RegistryOrbital(owner_);
        trustedAttestersOrbital = new TrustedAttestersOrbital(owner_);
        identityMappingOrbital = new IdentityMappingOrbital(owner_);
        verificationOrbital = new VerificationOrbital(
            owner_,
            address(0),
            address(registryOrbital),
            address(trustedAttestersOrbital),
            address(identityMappingOrbital)
        );

        emit GovernanceProfileConfigured(
            profile_.cutMultisig, profile_.minApprovals, profile_.standardCutTimelock, profile_.emergencyCutTimelock
        );
    }

    function getGovernanceProfile() external view returns (GovernanceProfile memory) {
        return _governanceProfile;
    }

    function getOrbitalBindings() external view returns (OrbitalBinding[] memory bindings) {
        bindings = new OrbitalBinding[](4);
        bindings[0] = OrbitalBinding({
            orbitalId: "verification", orbital: address(verificationOrbital), storageSlot: VERIFICATION_STORAGE_SLOT
        });
        bindings[1] = OrbitalBinding({
            orbitalId: "registry", orbital: address(registryOrbital), storageSlot: REGISTRY_STORAGE_SLOT
        });
        bindings[2] = OrbitalBinding({
            orbitalId: "trusted-attesters",
            orbital: address(trustedAttestersOrbital),
            storageSlot: TRUSTED_ATTESTERS_STORAGE_SLOT
        });
        bindings[3] = OrbitalBinding({
            orbitalId: "identity-mapping",
            orbital: address(identityMappingOrbital),
            storageSlot: IDENTITY_MAPPING_STORAGE_SLOT
        });
    }

    function exportedSelectors() external view returns (bytes4[] memory selectors) {
        RouteBinding[] memory routes = exportedRouteBindings();
        selectors = new bytes4[](routes.length);
        for (uint256 i = 0; i < routes.length; i++) {
            selectors[i] = routes[i].selector;
        }
    }

    function exportedRouteBindings() public view returns (RouteBinding[] memory routes) {
        bytes4[] memory verificationSelectors = verificationOrbital.exportedSelectors();
        bytes4[] memory registrySelectors = registryOrbital.exportedSelectors();
        bytes4[] memory trustedSelectors = trustedAttestersOrbital.exportedSelectors();
        bytes4[] memory identitySelectors = identityMappingOrbital.exportedSelectors();

        routes = new RouteBinding[](
            verificationSelectors.length + registrySelectors.length + trustedSelectors.length + identitySelectors.length
        );

        uint256 idx;
        idx = _append(routes, idx, verificationSelectors, address(verificationOrbital), VERIFICATION_STORAGE_SLOT);
        idx = _append(routes, idx, registrySelectors, address(registryOrbital), REGISTRY_STORAGE_SLOT);
        idx = _append(routes, idx, trustedSelectors, address(trustedAttestersOrbital), TRUSTED_ATTESTERS_STORAGE_SLOT);
        _append(routes, idx, identitySelectors, address(identityMappingOrbital), IDENTITY_MAPPING_STORAGE_SLOT);
    }

    function exportedKernelRoutePayload() external view returns (IValenceKernelRouting.SelectorRoute[] memory routes) {
        RouteBinding[] memory bindings = exportedRouteBindings();
        routes = new IValenceKernelRouting.SelectorRoute[](bindings.length);

        for (uint256 i = 0; i < bindings.length; i++) {
            routes[i] =
                IValenceKernelRouting.SelectorRoute({selector: bindings[i].selector, module: bindings[i].orbital});
        }
    }

    function applyRoutesToKernel(address kernel) external {
        _onlyKernelOwner();
        require(kernel != address(0), "kernel=0");

        IValenceKernelRouting.SelectorRoute[] memory routes = this.exportedKernelRoutePayload();
        IValenceKernelRouting(kernel).applySelectorRoutes(routes);

        emit KernelRoutesApplied(kernel, routes.length);
    }

    function validateSelectorChanges(
        SelectorChange[] calldata changes,
        CutPath path,
        uint48 queuedDelay,
        bool incidentDeclared
    ) external view returns (bool) {
        for (uint256 i = 0; i < changes.length; i++) {
            _validateSelectorChange(changes[i].kind, path, queuedDelay, incidentDeclared);

            if (changes[i].kind != SelectorChangeKind.Remove && changes[i].module == address(0)) {
                revert GovernanceInvariantViolation("module=0");
            }
        }

        return true;
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

    function _onlyKernelOwner() internal view {
        if (msg.sender != kernelOwner) revert Unauthorized();
    }

    function _validateGovernanceProfile(GovernanceProfile memory profile_) internal pure {
        if (profile_.cutMultisig == address(0)) {
            revert GovernanceInvariantViolation("multisig=0");
        }
        if (profile_.minApprovals < MIN_MULTISIG_APPROVALS) {
            revert GovernanceInvariantViolation("minApprovals<2");
        }
        if (profile_.standardCutTimelock < MIN_STANDARD_CUT_TIMELOCK) {
            revert GovernanceInvariantViolation("standardTimelock<24h");
        }
        if (profile_.emergencyCutTimelock < MIN_EMERGENCY_CUT_TIMELOCK) {
            revert GovernanceInvariantViolation("emergencyTimelock<1h");
        }
        if (profile_.emergencyCutTimelock > profile_.standardCutTimelock) {
            revert GovernanceInvariantViolation("emergency>standard");
        }
    }

    function _validateSelectorChange(SelectorChangeKind kind, CutPath path, uint48 queuedDelay, bool incidentDeclared)
        internal
        view
    {
        uint48 requiredDelay =
            path == CutPath.Standard ? _governanceProfile.standardCutTimelock : _governanceProfile.emergencyCutTimelock;

        if (queuedDelay < requiredDelay) {
            revert GovernanceInvariantViolation("queuedDelay<required");
        }

        if (kind == SelectorChangeKind.Remove && path != CutPath.Emergency) {
            revert GovernanceInvariantViolation("remove=emergency-only");
        }

        if ((kind == SelectorChangeKind.Replace || kind == SelectorChangeKind.Remove) && path == CutPath.Emergency) {
            if (!incidentDeclared) {
                revert GovernanceInvariantViolation("incident-required");
            }
        }
    }

    function _append(
        RouteBinding[] memory output,
        uint256 idx,
        bytes4[] memory selectors,
        address orbital,
        bytes32 orbitalStorageSlot
    ) internal pure returns (uint256) {
        for (uint256 i = 0; i < selectors.length; i++) {
            output[idx++] = RouteBinding({
                selector: selectors[i], orbital: orbital, orbitalStorageSlot: orbitalStorageSlot
            });
        }
        return idx;
    }
}
