# Phase 0 Artifact — Valence Selector Map

Status: **Frozen for Phase 1 scaffold** (subject to Phase 2 additive updates only)

## VerificationOrbital
- `setDependencies(address,address,address,address)`
- `setRequiredClaimTopics(uint256[])`
- `getRequiredClaimTopics()`
- `isVerified(address)`
- `verifyTopic(address,uint256)`
- `isAttestationValid(bytes32,bytes32)`

## RegistryOrbital
- `setTopicSchemaMapping(uint256,bytes32)`
- `getSchemaUID(uint256)`
- `registerAttestation(address,uint256,address,bytes32)`
- `getRegisteredAttestation(address,uint256,address)`

## TrustedAttestersOrbital
- `setTrustedAttester(uint256,address,bool)`
- `isAttesterTrusted(address,uint256)`
- `getTrustedAttestersForTopic(uint256)`

## IdentityMappingOrbital
- `setIdentity(address,address)`
- `getIdentity(address)`

## CompatibilityWrapperOrbital (Phase 2 Addition)

Per-identity wrapper implementing IIdentity for zero-mod Path B integration:

- `getClaim(bytes32)` — ERC-735 claim lookup
- `getClaimIdsByTopic(uint256)` — ERC-735 claim enumeration
- `isClaimValid(address,uint256,bytes,bytes)` — ERC-735 claim validation
- `getIdentityAddress()` — Helper to retrieve wrapped identity

**Note:** The CompatibilityWrapperOrbital is deployed per-identity and not routed through the kernel. It directly references the other orbitals for state access.

## Collision Policy
- Collisions are blocked by CI test gate on `ValenceEASKernelAdapter.hasSelectorCollisions() == false`.
- Any new selector in Phase 2+ must update this map and pass collision test.
