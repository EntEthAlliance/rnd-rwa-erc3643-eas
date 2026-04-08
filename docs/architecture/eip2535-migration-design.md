# EIP-2535 Migration Design — ERC-3643 + EAS Identity Verifier

## Purpose

Define a migration path from the current monolithic verifier contracts to an **EIP-2535 Diamond** architecture, while preserving ERC-3643 integration semantics and minimizing disruption.

## Scope

In scope:
- EAS verifier system architecture migration to Diamond
- Function selector and facet partitioning
- Storage migration strategy
- Upgrade governance model
- Testing and rollout plan

Out of scope:
- New compliance policy semantics
- New claim topic standards
- Full off-chain attestation proof system

---

## Current State (Baseline)

Current contracts:
- `EASClaimVerifier.sol`
- `EASTrustedIssuersAdapter.sol`
- `EASIdentityProxy.sol`
- `EASClaimVerifierIdentityWrapper.sol`

Current strengths:
- Functional verification path works
- Good tests + scripts + docs
- Path A / Path B integration narrative is clear

Current architectural gaps vs EIP-2535:
- No `diamondCut`
- No Loupe interface implementation
- No selector routing through fallback/delegatecall
- No shared diamond storage pattern
- No upgrade policy guardrails at diamond level

---

## Target Architecture (Diamond)

### Raw EIP-2535 vs Valence Kernel (Migration Position)

| Dimension | Raw EIP-2535 Diamond | Valence Kernel + Orbitals (Target Spike Direction) |
|---|---|---|
| Routing model | Diamond fallback + selector table | Kernel-mediated selector/module routing |
| Module shape | Facets | Orbitals (domain modules) |
| Storage discipline | Diamond storage libraries | Per-orbital storage slot conventions |
| Upgrade operations | `diamondCut` directly | Kernel-governed module registration / selector binding |
| Team ergonomics | Low-level selector management | Higher-level module semantics and ownership boundaries |
| Current repo status | Design documented | **Spike scaffold implemented** (`contracts/valence/*`) |

**Decision:** keep current production verifier contracts as-is; run Valence migration as an additive spike path first, then evaluate cutover once selector and storage compatibility are proven.

### Target Module Mapping (Current Contracts → Valence Orbitals)

| Current responsibility | Existing contract | Valence target module |
|---|---|---|
| Topic-level verification (`isVerified`, topic checks) | `EASClaimVerifier.sol` | `VerificationOrbital.sol` |
| Topic-schema + attestation registry | `EASClaimVerifier.sol` | `RegistryOrbital.sol` |
| Trusted attester administration | `EASTrustedIssuersAdapter.sol` | Future `AttesterOrbital` (TODO) |
| Wallet→identity mapping | `EASIdentityProxy.sol` | Future `IdentityOrbital` (TODO) |
| Compatibility wrapper | `EASClaimVerifierIdentityWrapper.sol` | Adapter layer retained during spike |

The initial spike implements the first two modules and a `ValenceEASKernelAdapter` that exposes module metadata/bindings without touching production flow.

### Diamond contracts
- `EASVerifierDiamond.sol` (proxy + fallback)
- `DiamondCutFacet.sol`
- `DiamondLoupeFacet.sol`
- `OwnershipFacet.sol`

### Domain facets
- `VerifierConfigFacet.sol`
  - set/get EAS, claim topics registry, adapters, mappings
- `VerificationFacet.sol`
  - `isVerified`, internal topic checks
- `AttestationRegistryFacet.sol`
  - register/get attestation UIDs
- `TrustedAttestersFacet.sol`
  - attester allowlist + topic relationships
- `IdentityMappingFacet.sol`
  - wallet ↔ identity mapping functions

### Storage libraries
- `LibDiamond.sol` (EIP-2535 core)
- `LibEASVerifierStorage.sol` (domain state)

All facets use deterministic storage slots and avoid inline state declarations.

---

## Interface Compatibility

### External compatibility objective
Keep current integration surface as stable as possible:
- Preserve existing public/external function signatures used by scripts/tests
- Preserve event names where feasible
- Keep `EASClaimVerifierIdentityWrapper` integration path operational (or provide adapter layer)

### Selector policy
- Maintain a selector mapping table from legacy contracts to facet functions
- Explicitly mark deprecated selectors
- Ensure no selector collisions across facets

---

## Governance & Security Model

- `diamondCut` restricted to owner/multisig
- Prefer timelock for production cuts
- Required events:
  - `DiamondCut`
  - domain-level config change events
- Change policy:
  - no direct state migration in same cut as major logic replacement unless dry-run validated
  - emergency pause strategy documented (if introduced)

Security checks:
- delegatecall safety review
- storage slot collision tests
- selector collision tests
- ownership/authorization tests for every mutation path

---

## Migration Strategy

## Phase 0 — Design freeze
Deliverables:
- Selector inventory from current contracts
- Storage schema map
- facet/function allocation matrix

Exit criteria:
- Approved architecture diagram + selector map

## Phase 1 — Diamond scaffolding
Deliverables:
- Diamond + core facets (Cut/Loupe/Ownership)
- `LibDiamond`

Exit criteria:
- Loupe tests pass
- diamondCut tests pass

## Phase 2 — Domain facets port
Deliverables:
- Verifier/Registry/Attester/Identity facets
- `LibEASVerifierStorage`

Exit criteria:
- Functional parity tests pass against baseline scenarios

## Phase 3 — Compatibility layer + scripts
Deliverables:
- Adapter/wrapper compatibility checks
- deploy/upgrade scripts for Diamond

Exit criteria:
- Existing pilot flow still works with diamond deployment path

## Phase 4 — Hardening
Deliverables:
- Fuzz/invariant tests
- Gas comparison baseline vs diamond
- docs update (integration + operations)

Exit criteria:
- CI green + migration checklist complete

---

## Testing Plan (Minimum)

Unit:
- each facet mutation/view behavior
- auth boundaries per facet

Integration:
- full ERC-3643 transfer verification using Diamond
- dual mode (ONCHAINID + EAS)
- revocation and expiration behavior

Diamond-specific:
- selector collision tests
- loupe consistency tests
- upgrade adds/replaces/removes selectors safely
- storage persistence across upgrades

---

## Data / State Migration Options

Option A (recommended for early stage):
- redeploy fresh diamond + re-register configs/attestations via scripts
- simpler and lower risk while adoption is early

Option B:
- snapshot old state and replay into diamond facets
- needed only if live state volume becomes large

---

## Risks and Mitigations

1. **Storage collision risk**
   - Mitigation: strict storage libraries + slot constants + tests

2. **Upgrade misuse risk**
   - Mitigation: multisig + timelock + explicit cut review checklist

3. **Operational complexity increase**
   - Mitigation: clear deployment runbooks and rollback playbook

4. **Gas overhead uncertainty**
   - Mitigation: benchmark parity and optimize hotspot selectors

---

## Deliverables Checklist

- [ ] Migration architecture approved
- [ ] Diamond scaffolding implemented
- [ ] Domain facets implemented
- [ ] Compatibility path validated
- [ ] Deployment/upgrade scripts added
- [ ] Security tests added
- [ ] Gas benchmarks updated
- [ ] Integration docs updated

---

## Recommendation

Proceed with Diamond migration only if the priority is:
- long-term modular upgradeability,
- explicit standard alignment (EIP-2535), and
- multi-team extension velocity.

If speed-to-demo is the immediate goal, keep current architecture for PoC and run this migration as a tracked Phase 2 productization stream.
