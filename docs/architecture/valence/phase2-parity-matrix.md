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
| Replace/remove semantics | N/A | ❌ | Pending | policy/docs + tests not implemented |
| Storage persistence across upgrades | N/A | ❌ | Pending | upgrade simulation tests not implemented |
| End-to-end parity suite vs legacy full matrix | ✅ | ⚠️ partial | In progress | baseline orbital tests only |

## Immediate next execution items

1. Add selector **replace/remove** governance policy tests (standard vs emergency cut constraints).
2. Add upgrade persistence tests proving orbital state survives route updates.
3. Extend parity suite to compare legacy verifier and orbital path across the full scenario matrix (revocation, expiration, multi-topic, identity remap).
4. Bind compatibility wrapper path to kernel routing once final wrapper orbital strategy is frozen.
