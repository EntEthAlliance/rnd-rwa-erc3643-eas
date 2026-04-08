# Phase 0 Artifact — Orbital Boundaries

Status: **Frozen for Phase 1 implementation**

## Kernel Adapter
- Composes orbitals and exposes boundary metadata.
- Owns selector inventory + collision checks.
- Does **not** replace production verifier path.

## VerificationOrbital
- Verification orchestration only:
  - resolve wallet → identity
  - enumerate required topics
  - verify topic satisfaction via trusted attester attestations
- No direct management of schema mappings/trusted lists/identity writes.

## RegistryOrbital
- Canonical mapping surface:
  - claim topic → schema UID
  - identity/topic/attester → attestation UID
- No policy decisions about trusted attesters or verification thresholds.

## TrustedAttestersOrbital
- Policy list for topic-scoped trusted attesters.
- No attestation registry mutation.

## IdentityMappingOrbital
- Wallet → identity projection.
- No schema/attestation policy.

## Compatibility Boundary
- Existing `EASClaimVerifier` path remains the production default.
- Valence orbitals are additive and test-scaffolded until explicit cutover phase.
