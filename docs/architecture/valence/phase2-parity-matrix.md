# Phase 2 Parity Matrix — Compatibility Path (EPIC #32)

Status date: 2026-04-08 (updated after EPIC #32 Phase 2 implementation run)

## Progress log (implemented along the way)

- [x] Added and validated negative-path parity suite expansion in `LegacyValenceParity.t.sol`.
- [x] Added `CompatibilityWrapperOrbital` and full wrapper-routing parity integration tests (`WrapperRoutingParity.t.sol`).
- [x] Added governance selector/route artifact generation script and docs (`GovernanceSelectorDiff.s.sol`, `governance-selector-diff.md`).
- [x] Re-ran matrix validation commands successfully: `forge test`, `forge coverage`, `forge test --gas-report`.

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
| Compatibility wrapper zero-mod path | ✅ | ✅ | Done | `CompatibilityWrapperOrbital`, `WrapperRoutingParityTest` |
| Replace/remove semantics | N/A | ✅ | Done | `ValenceEASKernelAdapter.validateSelectorChanges` + `ValenceEASKernelAdapterTest` policy tests (standard/emergency) |
| Storage persistence across upgrades | N/A | ✅ | Done | `ValenceUpgradePersistenceTest` (selector replace/remove then restore with state survival) |
| End-to-end parity suite vs legacy full matrix | ✅ | ✅ (Phase 2 baseline executable) | Done | `LegacyValenceParityTest` (valid/revoked/expired/multi-topic/identity-remap parity) |
| Negative-path edge cases | ✅ | ✅ | Done | `LegacyValenceParityTest` (schema mismatch, trust drift, mixed-validity) |
| Governance selector-diff artifacts | N/A | ✅ | Done | `script/GovernanceSelectorDiff.s.sol`, `governance-selector-diff.md` |

## Edge-Case Negative Parity Tests (NEW)

The following negative-path scenarios are now covered in `LegacyValenceParityTest`:

| Scenario | Test Function | Both Paths Reject? |
|----------|---------------|-------------------|
| Schema mismatch | `test_parity_schemaMismatch` | ✅ |
| Trust drift (attester removed) | `test_parity_trustDrift_attesterRemoved` | ✅ |
| Trust drift (attester re-trusted) | `test_parity_trustDrift_attesterRetrused` | ✅ |
| Mixed validity (one valid, one revoked) | `test_parity_mixedValidity_oneValidOneRevoked` | ✅ |
| Mixed validity (one valid, one expired) | `test_parity_mixedValidity_oneValidOneExpired` | ✅ |
| All attestations invalid (mixed reasons) | `test_parity_mixedValidity_allInvalid` | ✅ |
| No schema mapped for topic | `test_parity_noSchemaMapped` | ✅ |
| No trusted attesters for topic | `test_parity_noTrustedAttesters` | ✅ |

## Wrapper Routing Parity (NEW)

The `CompatibilityWrapperOrbital` provides IIdentity (ERC-735) compatibility for the Valence path. Parity tests in `WrapperRoutingParityTest` cover:

| IIdentity Method | Parity Status | Evidence |
|------------------|---------------|----------|
| `getClaim(bytes32)` | ✅ | `test_wrapperParity_getClaim_*` |
| `getClaimIdsByTopic(uint256)` | ✅ | `test_wrapperParity_getClaimIdsByTopic_*` |
| `isClaimValid(...)` | ✅ | `test_wrapperParity_isClaimValid_*` |
| `getKey(bytes32)` | ✅ | `test_wrapperParity_getKey_*` |
| `keyHasPurpose(...)` | ✅ | `test_wrapperParity_keyHasPurpose` |
| `getKeysByPurpose(uint256)` | ✅ | `test_wrapperParity_getKeysByPurpose` |
| Mutation reverts | ✅ | `test_wrapperParity_*_reverts` |

## Immediate next execution items

1. ~~Extend parity matrix Phase 2 with negative-path permutations~~ ✅ Done
2. ~~Add compatibility-wrapper parity tests~~ ✅ Done
3. ~~Integrate selector diff artifacts into governance runbook templates~~ ✅ Done
4. Prepare Phase 3 migration gate criteria for staged production activation.
5. Gas benchmarking for Valence path vs legacy path.
6. Authorization abuse tests (negative-path hardening for ownership).
