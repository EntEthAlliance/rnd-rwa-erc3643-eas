# PRD — Valence-Native ERC-3643 + EAS Identity Architecture

## Executive Summary

This project will be built as a **Valence-native architecture** (kernel + orbitals) for ERC-3643 identity verification using EAS attestations.

We are **not** treating Valence as a migration destination for the current monolithic contracts. Instead, we define a new canonical architecture and use the legacy implementation only as a behavioral reference for parity testing.

Goal:
- Deliver a modular, upgradeable, EIP-2535-aligned identity layer for ERC-3643
- Preserve ERC-3643 compliance semantics
- Enable ONCHAINID-only, EAS-only, or dual-mode verification

---

## Product Outcomes

1. **Valence-first modularity**
   - Kernel-governed module lifecycle
   - Independent orbitals for verification, registry, identity mapping, and trusted attesters

2. **Stable ERC-3643 compatibility surface**
   - Existing ERC-3643 integrations can consume the verifier without changing compliance policy logic

3. **Operational safety**
   - Upgrade governance, selector controls, storage discipline, and reproducible deployment paths

---

## Non-Goals

- Extending ERC-3643 compliance semantics beyond identity backend abstraction
- Shipping full off-chain proof systems in this phase
- Maintaining monolithic contracts as long-term production architecture

---

## Target Architecture (Valence-Native)

### Core
- **ValenceDiamond / Kernel**
  - module install/upgrade/remove
  - authorization and cut governance

### Orbitals (modules)
1. **VerificationOrbital**
   - `isVerified` and topic-level verification flow
2. **RegistryOrbital**
   - topic→schema mapping, attestation UID registry
3. **TrustedAttestersOrbital**
   - attester allowlisting + topic authorization
4. **IdentityMappingOrbital**
   - wallet↔identity resolution
5. **CompatibilityOrbital (optional)**
   - wrappers for zero-modification integration paths

### Storage model
- Namespaced storage slots per orbital
- Explicit schema/version hash discipline
- No shared mutable state without formal storage library

---

## Integration Modes

- **Mode A: Valence verifier direct path**
  - ERC-3643 calls Valence-based verification path directly
- **Mode B: Compatibility wrapper path**
  - Wrapper provides zero-modification compatibility where needed
- **Mode C: Dual mode**
  - ONCHAINID + EAS/Valence in coexistence/fallback model

---

## Functional Requirements

1. Verify required claim topics via EAS schema mappings
2. Validate attestation status (existence, schema, expiration, revocation)
3. Restrict accepted attestations to trusted attesters per topic
4. Support wallet→identity mapping for multi-wallet users
5. Support dual-mode verification policy
6. Emit events for all state-changing operations

---

## Upgrade / Governance Requirements

- Module lifecycle control must be owner/multisig-governed
- Production profile should support timelocked upgrades
- Selector collision and storage collision protections required
- Upgrade runbook and rollback runbook required before production declaration

---

## Validation Strategy

### Local
- Unit tests for each orbital
- Integration tests for full ERC-3643 transfer checks
- Selector and storage safety tests

### CI
- Build / Lint / Test / Coverage / Gas report all green

### Pilot
- Reproducible testnet script path:
  1. Deploy kernel + orbitals
  2. Register schemas and topic mappings
  3. Configure trusted attesters + identity mappings
  4. Seed attestations
  5. Validate pass/fail transfer behavior

---

## Delivery Phases

## Phase 0 — Architecture Freeze
Deliverables:
- module boundaries + selector map
- storage map + versioning policy
- governance profile draft

Exit:
- architecture sign-off

## Phase 1 — Kernel + Base Orbitals
Deliverables:
- kernel integration scaffold
- VerificationOrbital + RegistryOrbital compile-safe implementation

Exit:
- baseline tests green

## Phase 2 — Full Identity Surface
Deliverables:
- TrustedAttestersOrbital
- IdentityMappingOrbital
- compatibility orbital/wrapper path

Exit:
- parity scenarios pass against legacy behavior suite

## Phase 3 — Hardening
Deliverables:
- security tests (selector/storage/authorization)
- gas and complexity benchmarking
- operational runbooks

Exit:
- release-candidate quality gate passed

## Phase 4 — Pilot and Cutover Decision
Deliverables:
- testnet pilot evidence
- production readiness report
- cutover recommendation (go/no-go)

Exit:
- explicit human approval for production cutover

---

## Success Criteria

- Valence-native path is default architecture in docs/code
- ERC-3643 functional parity is demonstrated in tests
- CI fully green on architecture branch
- Pilot runbook executes end-to-end without manual patching
- Upgrade and rollback procedures are documented and tested

---

## Risks & Mitigations

1. **Architecture churn risk**
   - Mitigation: Phase 0 freeze + strict scope control

2. **Selector/storage safety risk**
   - Mitigation: dedicated safety tests and checklist gate

3. **Compatibility drift risk**
   - Mitigation: parity suite against legacy behavior

4. **Over-engineering risk**
   - Mitigation: orbitals delivered in thin vertical slices

---

## Deliverables Checklist

Progress note (2026-04-08): EPIC #32 Phase 2 parity expansion completed on branch `feat/epic32-phase2-parity-wrapper` with new negative parity tests, Path B compatibility wrapper parity suite, and governance selector-diff artifacts.

- [ ] Valence-native architecture spec approved
- [x] Orbitals implemented (verification/registry/trusted-attesters/identity-mapping)
- [x] Compatibility path documented and tested
- [x] CI quality gates green
- [ ] Pilot scripts + evidence published
- [ ] Production go/no-go decision documented
