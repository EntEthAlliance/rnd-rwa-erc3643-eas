# Governance Selector-Diff Artifacts

Status: **Active** | EPIC #32 Phase 2

## Overview

This document describes the reproducible selector-diff artifacts for DAO cut proposals targeting the Valence kernel. These artifacts enable governance participants to verify, audit, and execute selector changes with confidence.

## Quick Start

### Generate Current Selector Inventory

```bash
# Run the selector diff script (no broadcast needed - read-only)
forge script script/GovernanceSelectorDiff.s.sol --sig "run()"
```

### Compare Two Adapter Versions

```bash
# Compare old vs new adapter selectors for upgrade proposals
forge script script/GovernanceSelectorDiff.s.sol:SelectorDiffCompare \
  --sig "compare(address,address)" \
  <OLD_ADAPTER_ADDRESS> \
  <NEW_ADAPTER_ADDRESS>
```

## Output Sections

The `GovernanceSelectorDiff` script outputs five sections:

### 1. Selector Inventory

Lists all exported selectors by orbital module:

| Orbital | Selector Count | Description |
|---------|----------------|-------------|
| VerificationOrbital | 6 | Core verification logic |
| RegistryOrbital | 4 | Topic/schema mapping + attestation registry |
| TrustedAttestersOrbital | 3 | Attester allowlisting |
| IdentityMappingOrbital | 2 | Wallet→identity resolution |
| **Total** | **15** | |

### 2. Route Bindings

Maps each selector to its target orbital address:

```
Selector -> Orbital Mapping:
  0x12345678 -> 0xVerificationOrbitalAddress
  0xabcdef01 -> 0xRegistryOrbitalAddress
  ...
```

### 3. Kernel Route Payload

EIP-2535 compatible payload for `applySelectorRoutes`:

```solidity
[
  { selector: 0x12345678, module: 0xVerificationOrbitalAddress },
  { selector: 0xabcdef01, module: 0xRegistryOrbitalAddress },
  ...
]
```

### 4. Governance Profile

Validates governance invariants:

- Cut multisig ≠ address(0)
- Minimum approvals ≥ 2
- Standard cut timelock ≥ 24 hours
- Emergency cut timelock ≥ 1 hour
- Emergency timelock ≤ standard timelock

### 5. DAO Proposal Template

Ready-to-use markdown template for governance proposals with:
- Summary
- Selector change table (ADD/REPLACE/REMOVE)
- Timelock requirements
- Risk assessment

## Frozen Selector Map (Phase 0)

The following selectors are frozen and cannot be changed without a formal governance proposal:

### VerificationOrbital (6 selectors)

| Selector | Function Signature |
|----------|-------------------|
| `0x3bde7d2e` | `setDependencies(address,address,address,address)` |
| `0xfc774ce8` | `setRequiredClaimTopics(uint256[])` |
| `0x1a03a5ac` | `getRequiredClaimTopics()` |
| `0xb9209e33` | `isVerified(address)` |
| `0x41dcd5a0` | `verifyTopic(address,uint256)` |
| `0x0719ac0c` | `isAttestationValid(bytes32,bytes32)` |

### RegistryOrbital (4 selectors)

| Selector | Function Signature |
|----------|-------------------|
| `0xfa7ddc86` | `setTopicSchemaMapping(uint256,bytes32)` |
| `0x0325232a` | `getSchemaUID(uint256)` |
| `0x4b1f34c1` | `registerAttestation(address,uint256,address,bytes32)` |
| `0xa167cfe6` | `getRegisteredAttestation(address,uint256,address)` |

### TrustedAttestersOrbital (3 selectors)

| Selector | Function Signature |
|----------|-------------------|
| `0x0c167018` | `setTrustedAttester(uint256,address,bool)` |
| `0xd858916c` | `isAttesterTrusted(address,uint256)` |
| `0x4c8b18b5` | `getTrustedAttestersForTopic(uint256)` |

### IdentityMappingOrbital (2 selectors)

| Selector | Function Signature |
|----------|-------------------|
| `0x60ee7938` | `setIdentity(address,address)` |
| `0x2fea7b81` | `getIdentity(address)` |

## Governance Cut Paths

### Standard Path (ADD operations)

1. Queue proposal with 24h+ timelock
2. Require 2+ multisig approvals
3. Execute after timelock expires

### Emergency Path (REPLACE/REMOVE operations)

1. Declare incident (documented justification required)
2. Queue with 1h+ timelock
3. Require 2+ multisig approvals
4. Execute after timelock expires

## Proposal Validation

Before submitting a governance proposal:

1. **Run selector diff**: `forge script script/GovernanceSelectorDiff.s.sol`
2. **Check collisions**: Verify `hasSelectorCollisions() == false`
3. **Validate timelock**: Ensure `queuedDelay >= requiredDelay`
4. **Verify module addresses**: All non-REMOVE changes must have `module != address(0)`
5. **Document incident** (if emergency path): Provide justification in proposal

## Integration with CI

The selector inventory is validated in CI via:

```solidity
// test/unit/ValenceEASKernelAdapterTest.t.sol
function test_hasSelectorCollisions_returnsFalse() public view {
    assertFalse(adapter.hasSelectorCollisions());
}

function test_exportedSelectors_containsExpectedCount() public view {
    bytes4[] memory selectors = adapter.exportedSelectors();
    assertEq(selectors.length, 15);
}
```

## Related Documentation

- [Phase 0 Selector Map](./phase0-selector-map.md)
- [Governance Profile Runbook](./governance-profile-runbook.md)
- [Phase 2 Parity Matrix](./phase2-parity-matrix.md)
