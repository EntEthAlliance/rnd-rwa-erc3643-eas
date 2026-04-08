# Phase 2 Parity Matrix — Compatibility Path (EPIC #32)

Status date: 2026-04-08

## Matrix

| Capability | Legacy path (current prod) | Valence path (spike) | Status | Evidence |
|---|---|---|---|---|
| Selector inventory freeze | ✅ | ✅ | Done | `phase0-selector-map.md`, `ValenceEASKernelAdapterTest::test_exportedSelectors_containsExpectedCoreSelectors` |
| Selector collision guard | N/A | ✅ | Done | `ValenceEASKernelAdapter.hasSelectorCollisions()` + test |
| Topic/schema mapping | ✅ | ✅ | Done | `RegistryOrbital`, `ValenceVerificationOrbitalTest` |
| Trusted attester management | ✅ | ✅ | Done | `TrustedAttestersOrbital`, `ValenceVerificationOrbitalTest` |
| Wallet→identity mapping | ✅ | ✅ | Done | `IdentityMappingOrbital`, `ValenceVerificationOrbitalTest` |
| Verification evaluation (`isVerified`) | ✅ | ✅ | Baseline parity complete | `ValenceVerificationOrbitalTest` |
| Kernel route binding API | N/A | ✅ (assumed final API binding scaffold) | In progress | `exportedRouteBindings`, `applyRoutesToKernel`, `ValenceEASKernelAdapterTest` |
| Governance cut assumptions (multisig/timelock) | Process-only | ✅ (enforced constructor assumptions) | In progress | `getGovernanceProfile`, constructor invariants, tests |
| Compatibility wrapper zero-mod path | ✅ | ⚠️ not yet bound through kernel | Pending | wrapper tests exist; no kernel wrapper routing yet |
| Replace/remove semantics | N/A | ✅ | Done | `ValenceEASKernelAdapter.validateSelectorChanges` + `ValenceEASKernelAdapterTest` policy tests (standard/emergency) |
| Storage persistence across upgrades | N/A | ✅ | Done | `ValenceUpgradePersistenceTest` (selector replace/remove then restore with state survival) |
| End-to-end parity suite vs legacy full matrix | ✅ | ✅ (Phase 2 baseline executable) | Done | `LegacyValenceParityTest` (valid/revoked/expired/multi-topic/identity-remap parity) |

## Immediate next execution items

1. Extend parity matrix Phase 2 with negative-path permutations (schema mismatch, untrusted attester drift, mixed-validity attestations).
2. Add compatibility-wrapper parity tests once wrapper orbital routing is finalized.
3. Integrate selector diff artifacts into governance runbook templates for real cut proposals.
4. Prepare Phase 3 migration gate criteria for staged production activation.
