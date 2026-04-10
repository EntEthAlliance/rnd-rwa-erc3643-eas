# PRD — MVP Package: Valence-Native ERC-3643 + EAS Identity Layer

**Version:** v2 (PR-ready)
**Status:** Draft for product/design/engineering review
**Primary tracker:** EPIC #32
**Superseded tracks:** EIP-2535 migration track (#27) and PR #26 (closed)

---

## 1) Product Narrative (Why this matters)

ERC-3643 is strong for regulated token compliance, but identity backends are often tightly coupled to a specific implementation path. This creates onboarding friction, higher integration cost, and limited provider flexibility.

This MVP proves a simpler model:
- Keep ERC-3643 compliance semantics intact
- Make identity verification modular and replaceable
- Demonstrate an end-to-end, demoable flow with minimal operational overhead

**MVP Promise:** A token issuer can validate investor eligibility through a modular Valence-native verification stack, using EAS attestations, without rewriting compliance logic.

---

## 2) Problem Statement

### Current pain
1. Identity coupling reduces flexibility in provider choice.
2. Integration paths are fragmented and hard to demo quickly.
3. Architecture and delivery artifacts are spread across docs/tests/issues, making execution harder.

### MVP objective
Ship a coherent, testable, demo-ready package that unifies:
- product story,
- modular architecture,
- acceptance criteria,
- validation and demo flow,
- rollout readiness and gaps.

---

## 3) Target Users

1. **Token Issuer / Product Owner**
   - Needs compliant investor eligibility checks with optional backend flexibility.
2. **Protocol Engineer / Integrator**
   - Needs clear component boundaries, interfaces, and fast validation steps.
3. **Compliance Operator / Demo Presenter**
   - Needs a reproducible “allow + block” proof flow for stakeholders.

---

## 4) Core Use Cases (MVP)

1. Configure required claim topics and schema mappings.
2. Register trusted attesters by topic.
3. Map investor wallet to identity.
4. Register attestations per required topic.
5. Verify investor eligibility (`isVerified`) for transfer gating.
6. Demonstrate failure path (revoked/expired/missing claim).

---

## 5) MVP Scope

## In Scope (must have)
- Valence-native modular contracts for:
  - verification,
  - registry,
  - trusted attesters,
  - identity mapping.
- Functional parity for core verification behavior.
- Clear quick validation path (non-expert runnable).
- Short live demo script proving value end-to-end.
- Acceptance criteria per major capability.

## Out of Scope (for this MVP cycle)
- Production cutover and migration of live token deployments.
- Full governance automation beyond MVP runbook and guardrails.
- Full proxy upgrade architecture retrofit for all legacy contracts.
- Complex off-chain compliance workflows beyond attestation checks.

---

## 6) Modular Architecture (Single Source of Truth)

## Design principles
- **Low coupling:** modules own their domain data/logic.
- **Replaceability:** verification backend internals can evolve without changing caller semantics.
- **Simple interfaces:** explicit, narrow entry points.
- **Operational clarity:** every state-changing capability has tests + runbook notes.

## Components

1. **Kernel Adapter (orchestrator boundary)**
   - Routes calls to orbitals.
   - Enforces route ownership/governance assumptions.

2. **VerificationOrbital**
   - Evaluates required topics and attestation validity.
   - Public semantic boundary: investor eligibility result.

3. **RegistryOrbital**
   - Maintains topic→schema mapping and attestation registration references.

4. **TrustedAttestersOrbital**
   - Controls topic-specific attester authorization.

5. **IdentityMappingOrbital**
   - Resolves wallet↔identity relationships.

6. **Compatibility Wrapper (optional path)**
   - Provides zero-modification integration where required.

## Minimal interface contracts (conceptual)
- `isVerified(address wallet) -> bool`
- `setTopicSchemaMapping(uint256 topic, bytes32 schema)`
- `addTrustedAttester(address attester, uint256[] topics)`
- `registerIdentity(address wallet, address identity)`
- `registerAttestation(address identity, uint256 topic, bytes32 uid)`

---

## 7) Capability Acceptance Criteria

## A) Verification correctness
- Given all required valid attestations from trusted attesters, `isVerified` returns `true`.
- Given any missing/expired/revoked/untrusted-topic attestation, `isVerified` returns `false`.
- Must pass parity scenarios against baseline legacy expectations.

## B) Registry and schema mapping
- Topic-to-schema mapping can be configured and retrieved deterministically.
- Invalid or mismatched schema references are rejected in verification flow.

## C) Trusted attester control
- Authorized attesters can be added/removed per topic.
- Verification rejects attestations from non-trusted attesters.

## D) Identity mapping
- Wallet-to-identity links resolve correctly.
- Multi-wallet identity support works for verification checks.

## E) Operational quality
- CI checks pass (build, tests, coverage/gas where configured).
- Validation and demo scripts run without manual interpretation.

---

## 8) Validation Plan (non-expert friendly)

## Fast path (5–10 minutes)
1. Install dependencies (`forge install`) and build (`forge build`).
2. Run core tests (`forge test`).
3. Run targeted parity tests (match Valence/orbital parity suite).
4. Execute pilot setup script on local anvil profile.
5. Confirm expected pass/fail outputs from script logs.

## Evidence required for PR approval
- Command list + outputs in PR description.
- Which parity scenarios were executed.
- Any skipped checks explicitly listed.

---

## 9) Demo Script (presenter-ready, 8–12 minutes)

1. **Context (1 min):** “ERC-3643 compliance semantics, modular backend.”
2. **Setup (2 min):** run pilot script to deploy/configure modules and seed sample identities/attestations.
3. **Success proof (2 min):** show eligible investor path returns verified.
4. **Failure proof (2 min):** show revoked/invalid/missing claim returns not verified.
5. **Modularity proof (2 min):** highlight component boundaries and replaceable module model.
6. **Close (1 min):** summarize business value (faster onboarding, lower coupling, credible governance path).

Demo success = audience can see both allow/block behavior and understand which module owns what.

---

## 10) Testing Strategy

1. **Unit tests:** each orbital behavior boundaries.
2. **Integration tests:** end-to-end verification path across modules.
3. **Parity tests:** compare critical outcomes with legacy reference behavior.
4. **Safety tests:** selector collision, authorization guards, storage discipline.
5. **Smoke script tests:** pilot/demo command path remains runnable.

---

## 11) Rollout Readiness Gates (MVP)

Progress note (2026-04-08): EPIC #32 Phase 2 parity expansion completed (negative parity tests, Path B compatibility parity, governance selector-diff artifacts).

Before calling MVP “demo-ready”:
- [ ] PRD sections fully aligned with implementation artifacts.
- [ ] Fast validation path succeeds on clean environment.
- [ ] Demo script runs without undocumented manual steps.
- [ ] Known risks/assumptions documented and accepted.
- [ ] Remaining non-MVP items are explicitly deferred.

Current status snapshot:
- [x] Orbitals implemented (verification/registry/trusted-attesters/identity-mapping)
- [x] Compatibility path documented and tested
- [x] CI quality gates green
- [ ] Pilot scripts + evidence published
- [ ] Production go/no-go decision documented

---

## 12) Risks and Assumptions

## Risks
1. **Architecture drift** between docs and code.
2. **Parity blind spots** in edge cases.
3. **Governance ambiguity** if route policy changes late.
4. **Demo fragility** if scripts require hidden setup.

## Assumptions
1. EAS dependencies and test environment are accessible.
2. Current Valence path remains primary architecture.
3. MVP success is demoability + functional credibility, not production rollout.

Mitigation: keep one canonical PRD, one validation guide, and one demo script.

---

## 13) Concise Gap Analysis (what is still missing)

1. **Single-command validation UX**
   - Need one canonical `validate` entrypoint or documented minimal command set.

2. **Demo artifact consistency**
   - Ensure script outputs and docs use the same expected evidence format.

3. **Hardening completion criteria**
   - Finalize explicit threshold for “enough parity” and “enough safety” for MVP sign-off.

4. **Runbook cohesion**
   - Consolidate governance/rollback essentials into one operator-facing section.

---

## 14) Execution Plan (next two weeks)

### Week 1
- PRD/package alignment pass (this document + validation/demo guide)
- Parity coverage review and gap closure
- Demo dry-run and output normalization

### Week 2
- Hardening checklist completion for MVP gate
- Final reviewer packet (product + engineering + presenter)
- PR merge with evidence and go/no-go recommendation for next phase

---

## 15) Definition of Done (MVP)

MVP is done when:
1. A non-expert can run the validation path and see pass/fail outcomes.
2. A presenter can run the demo script without extra interpretation.
3. Product/design/engineering can use this PRD as execution reference.
4. Open gaps are explicit and bounded (no hidden work).

---

## 16) Reviewer Checklist (for PR)

- [ ] Narrative is clear and consistent with current architecture.
- [ ] Scope boundaries are explicit (in/out).
- [ ] Acceptance criteria are testable.
- [ ] Validation and demo sections are runnable.
- [ ] Risks/assumptions/gaps are visible and realistic.
- [ ] EPIC #32 remains the single source of tracking truth.
