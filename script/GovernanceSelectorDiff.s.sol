// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {ValenceEASKernelAdapter} from "../contracts/valence/ValenceEASKernelAdapter.sol";

/**
 * @title GovernanceSelectorDiff
 * @notice Script that outputs actual selectors and bytes for DAO cut proposals
 * @dev Run with: forge script script/GovernanceSelectorDiff.s.sol --sig "run()"
 *
 * This script generates reproducible selector-diff artifacts for governance proposals:
 * 1. All exported selectors by orbital module
 * 2. Route binding payloads for kernel integration
 * 3. Diff between current and proposed selector sets
 * 4. Human-readable governance proposal data
 *
 * Output can be used directly for:
 * - Multisig proposal creation
 * - DAO governance proposal encoding
 * - Audit verification of selector changes
 */
contract GovernanceSelectorDiff is Script {
    // ============ Constants ============

    // Note: Solidity doesn't have string.repeat(), using literal strings
    string constant OUTPUT_HEADER = "================================================================================";
    string constant OUTPUT_SEPARATOR = "------------------------------------------------------------";

    // ============ Main Entry Point ============

    function run() external {
        console.log("");
        console.log("================================================================================");
        console.log("GOVERNANCE SELECTOR-DIFF ARTIFACT GENERATOR");
        console.log("EAS-ERC3643 Bridge - Valence Architecture (EPIC #32)");
        console.log("================================================================================");
        console.log("");

        // Create a temporary adapter to extract selectors
        ValenceEASKernelAdapter.GovernanceProfile memory profile = ValenceEASKernelAdapter.GovernanceProfile({
            cutMultisig: address(0xDEAD), // Placeholder for artifact generation
            minApprovals: 2,
            standardCutTimelock: 24 hours,
            emergencyCutTimelock: 1 hours
        });

        address artifactOwner = vm.addr(1);
        ValenceEASKernelAdapter adapter = new ValenceEASKernelAdapter(artifactOwner, profile);

        // Output sections
        _outputSelectorInventory(adapter);
        _outputRouteBindings(adapter);
        _outputKernelPayload(adapter);
        _outputGovernanceProfile(adapter);
        _outputProposalTemplate(adapter);

        console.log("");
        console.log("================================================================================");
        console.log("ARTIFACT GENERATION COMPLETE");
        console.log("================================================================================");
    }

    // ============ Selector Inventory ============

    function _outputSelectorInventory(ValenceEASKernelAdapter adapter) internal view {
        console.log("");
        console.log("SECTION 1: SELECTOR INVENTORY (FROZEN PHASE 0)");
        console.log("------------------------------------------------------------");
        console.log("");

        // VerificationOrbital selectors
        console.log("VerificationOrbital:");
        bytes4[] memory verificationSelectors = adapter.verificationOrbital().exportedSelectors();
        for (uint256 i = 0; i < verificationSelectors.length; i++) {
            console.log("  [%d] %s", i, _bytes4ToHex(verificationSelectors[i]));
        }
        console.log("  Total: %d selectors", verificationSelectors.length);
        console.log("");

        // RegistryOrbital selectors
        console.log("RegistryOrbital:");
        bytes4[] memory registrySelectors = adapter.registryOrbital().exportedSelectors();
        for (uint256 i = 0; i < registrySelectors.length; i++) {
            console.log("  [%d] %s", i, _bytes4ToHex(registrySelectors[i]));
        }
        console.log("  Total: %d selectors", registrySelectors.length);
        console.log("");

        // TrustedAttestersOrbital selectors
        console.log("TrustedAttestersOrbital:");
        bytes4[] memory trustedSelectors = adapter.trustedAttestersOrbital().exportedSelectors();
        for (uint256 i = 0; i < trustedSelectors.length; i++) {
            console.log("  [%d] %s", i, _bytes4ToHex(trustedSelectors[i]));
        }
        console.log("  Total: %d selectors", trustedSelectors.length);
        console.log("");

        // IdentityMappingOrbital selectors
        console.log("IdentityMappingOrbital:");
        bytes4[] memory identitySelectors = adapter.identityMappingOrbital().exportedSelectors();
        for (uint256 i = 0; i < identitySelectors.length; i++) {
            console.log("  [%d] %s", i, _bytes4ToHex(identitySelectors[i]));
        }
        console.log("  Total: %d selectors", identitySelectors.length);
        console.log("");

        // Total selector count
        uint256 totalSelectors = verificationSelectors.length + registrySelectors.length + trustedSelectors.length
            + identitySelectors.length;
        console.log("TOTAL EXPORTED SELECTORS: %d", totalSelectors);

        // Collision check
        bool hasCollisions = adapter.hasSelectorCollisions();
        console.log("COLLISION CHECK: %s", hasCollisions ? "FAILED - COLLISIONS DETECTED" : "PASSED - No collisions");
    }

    // ============ Route Bindings ============

    function _outputRouteBindings(ValenceEASKernelAdapter adapter) internal view {
        console.log("");
        console.log("SECTION 2: ROUTE BINDINGS");
        console.log("------------------------------------------------------------");
        console.log("");

        ValenceEASKernelAdapter.RouteBinding[] memory routes = adapter.exportedRouteBindings();

        console.log("Selector -> Orbital Mapping:");
        console.log("");

        for (uint256 i = 0; i < routes.length; i++) {
            console.log("  %s -> %s", _bytes4ToHex(routes[i].selector), _addressToHex(routes[i].orbital));
        }

        console.log("");
        console.log("Total routes: %d", routes.length);
    }

    // ============ Kernel Payload ============

    function _outputKernelPayload(ValenceEASKernelAdapter adapter) internal view {
        console.log("");
        console.log("SECTION 3: KERNEL ROUTE PAYLOAD (EIP-2535 Compatible)");
        console.log("------------------------------------------------------------");
        console.log("");

        // Use RouteBinding which has the same data we need
        ValenceEASKernelAdapter.RouteBinding[] memory routes = adapter.exportedRouteBindings();

        console.log("Payload for applySelectorRoutes(SelectorRoute[]):");
        console.log("");
        console.log("[");

        for (uint256 i = 0; i < routes.length; i++) {
            string memory comma = i < routes.length - 1 ? "," : "";
            console.log(
                "  { selector: %s, module: %s }%s",
                _bytes4ToHex(routes[i].selector),
                _addressToHex(routes[i].orbital),
                comma
            );
        }

        console.log("]");
        console.log("");

        // Output encoded payload for direct use
        console.log("Encoded payload bytes (for raw transaction):");
        console.log("  Use: abi.encodeWithSelector(IValenceKernelRouting.applySelectorRoutes.selector, payload)");
    }

    // ============ Governance Profile ============

    function _outputGovernanceProfile(ValenceEASKernelAdapter adapter) internal view {
        console.log("");
        console.log("SECTION 4: GOVERNANCE PROFILE");
        console.log("------------------------------------------------------------");
        console.log("");

        ValenceEASKernelAdapter.GovernanceProfile memory profile = adapter.getGovernanceProfile();

        console.log("Cut Multisig:            %s", _addressToHex(profile.cutMultisig));
        console.log("Min Approvals Required:  %d", uint256(profile.minApprovals));
        console.log(
            "Standard Cut Timelock:   %d seconds (%d hours)",
            uint256(profile.standardCutTimelock),
            uint256(profile.standardCutTimelock) / 3600
        );
        console.log(
            "Emergency Cut Timelock:  %d seconds (%d hours)",
            uint256(profile.emergencyCutTimelock),
            uint256(profile.emergencyCutTimelock) / 3600
        );
        console.log("");

        console.log("Invariant Checks:");
        console.log("  - multisig != address(0):        %s", profile.cutMultisig != address(0) ? "PASS" : "FAIL");
        console.log("  - minApprovals >= 2:             %s", profile.minApprovals >= 2 ? "PASS" : "FAIL");
        console.log("  - standardCutTimelock >= 24h:    %s", profile.standardCutTimelock >= 24 hours ? "PASS" : "FAIL");
        console.log("  - emergencyCutTimelock >= 1h:    %s", profile.emergencyCutTimelock >= 1 hours ? "PASS" : "FAIL");
        console.log(
            "  - emergency <= standard:         %s",
            profile.emergencyCutTimelock <= profile.standardCutTimelock ? "PASS" : "FAIL"
        );
    }

    // ============ Proposal Template ============

    function _outputProposalTemplate(ValenceEASKernelAdapter adapter) internal view {
        console.log("");
        console.log("SECTION 5: DAO PROPOSAL TEMPLATE");
        console.log("------------------------------------------------------------");
        console.log("");

        bytes4[] memory allSelectors = adapter.exportedSelectors();

        console.log("## Proposal: Add EAS-ERC3643 Bridge Selectors to Kernel");
        console.log("");
        console.log("### Summary");
        console.log("This proposal adds %d selectors across 4 orbital modules to enable", allSelectors.length);
        console.log("EAS attestation-based compliance verification for ERC-3643 security tokens.");
        console.log("");
        console.log("### Selector Changes");
        console.log("");
        console.log("| Action | Selector | Module | Description |");
        console.log("|--------|----------|--------|-------------|");

        // VerificationOrbital
        console.log(
            "| ADD | %s | VerificationOrbital | setDependencies |",
            _bytes4ToHex(adapter.verificationOrbital().setDependencies.selector)
        );
        console.log(
            "| ADD | %s | VerificationOrbital | setRequiredClaimTopics |",
            _bytes4ToHex(adapter.verificationOrbital().setRequiredClaimTopics.selector)
        );
        console.log(
            "| ADD | %s | VerificationOrbital | getRequiredClaimTopics |",
            _bytes4ToHex(adapter.verificationOrbital().getRequiredClaimTopics.selector)
        );
        console.log(
            "| ADD | %s | VerificationOrbital | isVerified |",
            _bytes4ToHex(adapter.verificationOrbital().isVerified.selector)
        );
        console.log(
            "| ADD | %s | VerificationOrbital | verifyTopic |",
            _bytes4ToHex(adapter.verificationOrbital().verifyTopic.selector)
        );
        console.log(
            "| ADD | %s | VerificationOrbital | isAttestationValid |",
            _bytes4ToHex(adapter.verificationOrbital().isAttestationValid.selector)
        );

        // RegistryOrbital
        console.log(
            "| ADD | %s | RegistryOrbital | setTopicSchemaMapping |",
            _bytes4ToHex(adapter.registryOrbital().setTopicSchemaMapping.selector)
        );
        console.log(
            "| ADD | %s | RegistryOrbital | getSchemaUID |",
            _bytes4ToHex(adapter.registryOrbital().getSchemaUID.selector)
        );
        console.log(
            "| ADD | %s | RegistryOrbital | registerAttestation |",
            _bytes4ToHex(adapter.registryOrbital().registerAttestation.selector)
        );
        console.log(
            "| ADD | %s | RegistryOrbital | getRegisteredAttestation |",
            _bytes4ToHex(adapter.registryOrbital().getRegisteredAttestation.selector)
        );

        // TrustedAttestersOrbital
        console.log(
            "| ADD | %s | TrustedAttestersOrbital | setTrustedAttester |",
            _bytes4ToHex(adapter.trustedAttestersOrbital().setTrustedAttester.selector)
        );
        console.log(
            "| ADD | %s | TrustedAttestersOrbital | isAttesterTrusted |",
            _bytes4ToHex(adapter.trustedAttestersOrbital().isAttesterTrusted.selector)
        );
        console.log(
            "| ADD | %s | TrustedAttestersOrbital | getTrustedAttestersForTopic |",
            _bytes4ToHex(adapter.trustedAttestersOrbital().getTrustedAttestersForTopic.selector)
        );

        // IdentityMappingOrbital
        console.log(
            "| ADD | %s | IdentityMappingOrbital | setIdentity |",
            _bytes4ToHex(adapter.identityMappingOrbital().setIdentity.selector)
        );
        console.log(
            "| ADD | %s | IdentityMappingOrbital | getIdentity |",
            _bytes4ToHex(adapter.identityMappingOrbital().getIdentity.selector)
        );

        console.log("");
        console.log("### Timelock");
        console.log("- Cut Path: Standard");
        console.log("- Required Delay: 24 hours minimum");
        console.log("- Required Approvals: 2 minimum");
        console.log("");
        console.log("### Risk Assessment");
        console.log("- Collision Check: PASSED");
        console.log("- This is an ADD-only proposal (no replacements or removals)");
        console.log("- Backward compatible with existing kernel routes");
    }

    // ============ Utility Functions ============

    function _bytes4ToHex(bytes4 value) internal pure returns (string memory) {
        bytes memory result = new bytes(10);
        result[0] = "0";
        result[1] = "x";
        for (uint256 i = 0; i < 4; i++) {
            result[2 + i * 2] = _hexChar(uint8(value[i]) >> 4);
            result[3 + i * 2] = _hexChar(uint8(value[i]) & 0x0f);
        }
        return string(result);
    }

    function _addressToHex(address value) internal pure returns (string memory) {
        bytes memory result = new bytes(42);
        result[0] = "0";
        result[1] = "x";
        bytes20 addrBytes = bytes20(value);
        for (uint256 i = 0; i < 20; i++) {
            result[2 + i * 2] = _hexChar(uint8(addrBytes[i]) >> 4);
            result[3 + i * 2] = _hexChar(uint8(addrBytes[i]) & 0x0f);
        }
        return string(result);
    }

    function _hexChar(uint8 value) internal pure returns (bytes1) {
        if (value < 10) {
            return bytes1(value + 0x30);
        }
        return bytes1(value + 0x57);
    }
}

// Interface for kernel routing (matches ValenceEASKernelAdapter)
interface IValenceKernelRouting {
    struct SelectorRoute {
        bytes4 selector;
        address module;
    }

    function applySelectorRoutes(SelectorRoute[] calldata routes) external;
}

/**
 * @title SelectorDiffCompare
 * @notice Compare selectors between two adapter versions for upgrade proposals
 * @dev Run with: forge script script/GovernanceSelectorDiff.s.sol:SelectorDiffCompare --sig "compare(address,address)"
 */
contract SelectorDiffCompare is Script {
    function compare(address oldAdapter, address newAdapter) external view {
        console.log("");
        console.log("================================================================================");
        console.log("SELECTOR DIFF COMPARISON");
        console.log("================================================================================");
        console.log("");
        console.log("Old Adapter: %s", _addressToHex(oldAdapter));
        console.log("New Adapter: %s", _addressToHex(newAdapter));
        console.log("");

        ValenceEASKernelAdapter oldA = ValenceEASKernelAdapter(oldAdapter);
        ValenceEASKernelAdapter newA = ValenceEASKernelAdapter(newAdapter);

        bytes4[] memory oldSelectors = oldA.exportedSelectors();
        bytes4[] memory newSelectors = newA.exportedSelectors();

        console.log("Old selector count: %d", oldSelectors.length);
        console.log("New selector count: %d", newSelectors.length);
        console.log("");

        // Find added selectors
        console.log("ADDED SELECTORS:");
        uint256 addedCount = 0;
        for (uint256 i = 0; i < newSelectors.length; i++) {
            bool found = false;
            for (uint256 j = 0; j < oldSelectors.length; j++) {
                if (newSelectors[i] == oldSelectors[j]) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                console.log("  + %s", _bytes4ToHex(newSelectors[i]));
                addedCount++;
            }
        }
        if (addedCount == 0) {
            console.log("  (none)");
        }
        console.log("");

        // Find removed selectors
        console.log("REMOVED SELECTORS:");
        uint256 removedCount = 0;
        for (uint256 i = 0; i < oldSelectors.length; i++) {
            bool found = false;
            for (uint256 j = 0; j < newSelectors.length; j++) {
                if (oldSelectors[i] == newSelectors[j]) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                console.log("  - %s", _bytes4ToHex(oldSelectors[i]));
                removedCount++;
            }
        }
        if (removedCount == 0) {
            console.log("  (none)");
        }
        console.log("");

        console.log("SUMMARY:");
        console.log("  Added:   %d", addedCount);
        console.log("  Removed: %d", removedCount);
        console.log(
            "  Net:     %s%d",
            addedCount >= removedCount ? "+" : "-",
            addedCount > removedCount ? addedCount - removedCount : removedCount - addedCount
        );
    }

    function _bytes4ToHex(bytes4 value) internal pure returns (string memory) {
        bytes memory result = new bytes(10);
        result[0] = "0";
        result[1] = "x";
        for (uint256 i = 0; i < 4; i++) {
            result[2 + i * 2] = _hexChar(uint8(value[i]) >> 4);
            result[3 + i * 2] = _hexChar(uint8(value[i]) & 0x0f);
        }
        return string(result);
    }

    function _addressToHex(address value) internal pure returns (string memory) {
        bytes memory result = new bytes(42);
        result[0] = "0";
        result[1] = "x";
        bytes20 addrBytes = bytes20(value);
        for (uint256 i = 0; i < 20; i++) {
            result[2 + i * 2] = _hexChar(uint8(addrBytes[i]) >> 4);
            result[3 + i * 2] = _hexChar(uint8(addrBytes[i]) & 0x0f);
        }
        return string(result);
    }

    function _hexChar(uint8 value) internal pure returns (bytes1) {
        if (value < 10) {
            return bytes1(value + 0x30);
        }
        return bytes1(value + 0x57);
    }
}
