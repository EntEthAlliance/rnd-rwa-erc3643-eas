# PRD + EPIC #32 Backlog (Concrete)

Source of truth: `PRD.md` + GitHub EPIC #32.

## Phase 0 — Architecture Freeze
- [x] Freeze selector map (`phase0-selector-map.md`)
- [x] Freeze storage map + version policy (`phase0-storage-map.md`)
- [x] Freeze orbital boundaries (`phase0-orbital-boundaries.md`)
- [x] Governance profile draft (timelock/multisig cut policy) (`governance-profile-runbook.md`)

## Phase 1 — Kernel + Base Orbitals
- [x] Kernel adapter scaffold with orbital composition
- [x] VerificationOrbital upgraded from metadata-only to functional topic verification scaffold
- [x] RegistryOrbital upgraded to actionable schema + attestation index state
- [x] Selector collision guard (`hasSelectorCollisions` + unit test)
- [x] Add base tests for Valence-native components
- [~] Wire to final Valence kernel routing/cut API (assumed `applySelectorRoutes` binding scaffold implemented; final upstream lock still pending)

## Phase 2 — Full Identity Surface
- [x] Add TrustedAttestersOrbital scaffold + core state/actions
- [x] Add IdentityMappingOrbital scaffold + core state/actions
- [x] CompatibilityWrapperOrbital for zero-mod integration path (`CompatibilityWrapperOrbital.sol`)
- [x] Parity matrix execution for compatibility path (`phase2-parity-matrix.md`)
- [x] End-to-end parity suite against legacy verifier for full scenario matrix (`LegacyValenceParityTest`)
- [x] Negative-path edge case tests (schema mismatch, trust drift, mixed-validity) (`LegacyValenceParityTest`)
- [x] Wrapper routing parity tests (`WrapperRoutingParityTest`)
- [x] Governance selector-diff artifacts (`GovernanceSelectorDiff.s.sol`, `governance-selector-diff.md`)

## Phase 3 — Hardening
- [x] Selector replacement/removal policy tests (`ValenceEASKernelAdapterTest`)
- [x] Storage persistence across upgrades (`ValenceUpgradePersistenceTest`)
- [ ] Authorization abuse tests (negative-path hardening)
- [ ] Gas/complexity benchmarking for orbital path
- [ ] Upgrade + rollback runbooks

## Phase 4 — Pilot / Cutover
- [ ] Reproducible testnet pilot using Valence-native path
- [ ] Production readiness report
- [ ] Explicit go/no-go decision
