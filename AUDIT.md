# AUDIT.md — Security Audit Scope and Mainnet Readiness Gate

## Purpose
This file defines the mandatory audit scope and launch gates for mainnet deployment.

Mainnet deployment is blocked by default until audit readiness is explicitly acknowledged.

---

## 1) Audit Scope

## In-scope contracts (production path)
- `contracts/EASClaimVerifier.sol`
- `contracts/EASTrustedIssuersAdapter.sol`
- `contracts/EASIdentityProxy.sol`
- `contracts/EASClaimVerifierIdentityWrapper.sol`

## In-scope integration paths
- Path A: direct verifier integration in ERC-3643 identity flow
- Path B: identity wrapper compatibility path
- Deployment scripts used for production (`script/DeployMainnet.s.sol`)

## Out-of-scope
- Non-production experiments and archived research branches
- UI/demo frontends not used for on-chain control

---

## 2) Threat Model (minimum required)

1. **Attester compromise**
   - Threat: a trusted attester key is compromised and malicious attestations are issued.
   - Required controls: revocation response, attester removal, monitoring, incident runbook.

2. **Registration manipulation**
   - Threat: unauthorized actor registers or overwrites attestation references.
   - Required controls: strict registration authorization checks and audit trail guarantees.

3. **Gas griefing / cost amplification**
   - Threat: attacker or misconfiguration forces expensive verification paths.
   - Required controls: bounded data structures, predictable verification complexity, gas regression tests.

4. **Privilege misuse / admin key risk**
   - Threat: privileged functions misused or compromised owner key.
   - Required controls: multisig ownership, role minimization, documented emergency controls.

5. **Schema/config drift**
   - Threat: schema-topic mismatch or trust config drift causes false positives/negatives.
   - Required controls: explicit validation checks, config reviews, reproducible setup scripts.

---

## 3) Audit Timeline (proposed)

- **Week 0:** scope freeze, code freeze candidate, artifacts handoff
- **Week 1–2:** auditor review + issue triage
- **Week 3:** remediation and re-review of critical/high findings
- **Week 4:** final report, launch recommendation, sign-off

Mainnet deployment should not proceed before:
- all critical/high findings resolved or formally accepted,
- final audit report published internally,
- deployment checklist approved by owners.

---

## 4) Mainnet Deployment Gate

`script/DeployMainnet.s.sol` enforces a hard gate:
- requires env var `AUDIT_ACKNOWLEDGED=true`
- script reverts if the flag is absent or false

This is intentional to prevent accidental unaudited mainnet deployment.

### Required environment values for production run
- `PRIVATE_KEY`
- `MULTISIG_ADDRESS`
- `CLAIM_TOPICS_REGISTRY`
- `AUDIT_ACKNOWLEDGED=true`

---

## 5) Pre-Launch Checklist

- [ ] Audit scope approved
- [ ] Audit completed and report reviewed
- [ ] Critical/high findings resolved or explicitly accepted
- [ ] Mainnet deployment runbook reviewed
- [ ] Multisig signers aligned and available
- [ ] Rollback plan documented and tested
