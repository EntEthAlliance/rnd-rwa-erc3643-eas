# Valence Migration Spike — Implementation Checklist

> Status: Spike only (not production cutover)

## Scope for this spike

- [x] Create feature branch `feat/valence-migration-spike`
- [x] Add initial Valence adapter + orbital skeletons
- [x] Add compile/deploy tests for Valence skeleton path
- [x] Document EIP-2535 raw vs Valence mapping
- [x] Document coexistence with current production flow

## Next implementation steps

### Kernel + selector routing
- [ ] Bind orbital selectors through final Valence kernel routing API
- [ ] Add selector collision guardrails vs current/legacy surface
- [ ] Define replace/remove semantics for incremental migration

### Storage migration
- [ ] Define canonical storage slot constants and structs per orbital
- [ ] Design migration scripts for topic-schema mappings and attestation registry
- [ ] Add storage persistence tests across module upgrades

### Functional parity
- [ ] Port `isVerified` logic into `VerificationOrbital`
- [ ] Port topic/schema and registration logic into `RegistryOrbital`
- [ ] Add trusted attester + identity mapping orbitals
- [ ] Run parity tests against current `EASClaimVerifier` behavior

### Cutover readiness
- [ ] Add deployment/upgrade runbook for staging
- [ ] Add rollback playbook back to current production path
- [ ] Complete security review (auth, delegatecall/routing, storage collisions)
- [ ] Gate production move on CI parity + benchmark review
