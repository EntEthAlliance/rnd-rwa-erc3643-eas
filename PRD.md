# PRD — MVP Package: Monolithic ERC-3643 + EAS Bridge (UUPS Proxy Path)

**Version:** v3 (single-architecture)
**Status:** PR-ready
**Primary tracker:** EPIC #32 (consolidated)

---

## Product Direction (Frozen)

This project now has **one production architecture**:
- Monolithic bridge contracts
- UUPS proxy deployment model for upgradeability
- One integration path, one deployable stack, one docs surface

The Valence/Diamond spike is archived for research only on branch: `research/valence-spike`.

---

## Problem Statement

ERC-3643 deployments need a practical way to use EAS attestations without fragmenting the integration path or introducing architectural ambiguity.

We solve this by shipping a single, credible, demoable MVP path institutions can evaluate directly.

---

## Target Users

1. Token issuers integrating ERC-3643 compliance checks
2. Engineering teams implementing the verifier stack
3. Compliance operators demonstrating allow/block behavior

---

## MVP Scope

## In Scope
- `EASClaimVerifier` (core verification)
- `EASTrustedIssuersAdapter` (attester trust controls)
- `EASIdentityProxy` (wallet↔identity mapping)
- `EASClaimVerifierIdentityWrapper` (zero-mod integration mode)
- UUPS proxy-based deployment path and operational docs
- Validation and demo flow

## Out of Scope
- Valence/Diamond migration implementation in mainline code
- Multi-architecture parity work in this repo path
- Mainnet launch prior to audit completion gates

---

## Modular Architecture (Production)

Despite monolithic deployment, responsibilities remain modular by contract boundary:

1. **Verifier** — topic-level eligibility checks from EAS attestations
2. **Trusted Issuers Adapter** — per-topic attester trust policy
3. **Identity Proxy** — identity ownership and wallet delegation
4. **Wrapper** — compatibility for no-modification integration

Design goals:
- clear boundaries,
- minimal coupling,
- replaceable internals behind stable interfaces.

---

## Capability Acceptance Criteria

### A) Eligibility Verification
- `isVerified(wallet)` returns `true` only when all required topics resolve to valid attestations from trusted attesters.
- Missing, revoked, expired, schema-mismatch, or untrusted attestation returns `false`.

### B) Trusted Attester Controls
- Attesters are configurable per claim topic.
- Removal immediately affects verification outcomes.

### C) Identity Mapping
- Wallet→identity mapping works with owner + authorized agent semantics.
- Verification correctly resolves identity before topic checks.

### D) Compatibility Mode
- Wrapper path supports integration where registry changes are constrained.

### E) Upgrade Path
- UUPS deployment and admin flow documented and testable.

---

## Validation Plan (Quick)

1. `forge install`
2. `forge build`
3. `forge test`
4. Run pilot setup script
5. Demonstrate one allow + one block scenario

See: `docs/mvp-validation-and-demo.md`

---

## Demo Flow (8–12 minutes)

1. Explain architecture and trust boundaries
2. Deploy/configure bridge stack
3. Register trusted attester + identity + attestations
4. Show successful verification
5. Revoke or invalidate attestation and show blocked verification
6. Close with operational value + rollout constraints

---

## Risks / Assumptions

### Risks
- Attester trust misconfiguration
- Registration misuse without strict caller controls
- Gas growth from unbounded trust sets
- Operational risk if unaudited deployment scripts are executed on mainnet

### Assumptions
- EAS endpoint and schema governance are available
- UUPS path is implemented and tested before production promotion

---

## Definition of Done (MVP)

MVP is done when:
1. Single architecture is reflected in contracts/docs/scripts
2. Validation and demo run without ambiguity
3. UUPS upgrade path + safety checks are documented
4. Remaining pre-mainnet dependencies are explicit and gated
