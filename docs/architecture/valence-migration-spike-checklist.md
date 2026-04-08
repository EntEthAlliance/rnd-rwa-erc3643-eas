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
- [x] Add selector collision guardrails vs current/legacy surface
- [ ] Define replace/remove semantics for incremental migration

### Storage migration
- [x] Define canonical storage slot constants and structs per orbital
- [ ] Design migration scripts for topic-schema mappings and attestation registry
- [ ] Add storage persistence tests across module upgrades

### Functional parity
- [x] Port `isVerified` logic into `VerificationOrbital`
- [x] Port topic/schema and registration logic into `RegistryOrbital`
- [x] Add trusted attester + identity mapping orbitals
- [x] Run parity-oriented baseline tests against current verifier semantics

### Cutover readiness
- [ ] Add deployment/upgrade runbook for staging
- [ ] Add rollback playbook back to current production path
- [ ] Complete security review (auth, delegatecall/routing, storage collisions)
- [ ] Gate production move on CI parity + benchmark review
