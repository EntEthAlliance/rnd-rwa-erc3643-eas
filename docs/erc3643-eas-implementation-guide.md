# ERC-3643 + EAS Implementation Guide (GitHub Edition)

A practical, reviewer-friendly guide to understand, validate, and integrate the EAS Identity Verifier module with ERC-3643.

## 1) What this project does

This repository makes **identity verification pluggable** for ERC-3643 security tokens.

- Keep ERC-3643 token + compliance model
- Replace or complement ONCHAINID identity proofs with EAS attestations
- Allow issuers to run **ONCHAINID only**, **EAS only**, or **dual mode**

In OpenZeppelin vocabulary, this repository implements an **Identity Verifier module** for ERC-3643.

---

## 2) Core contracts (what each one is for)

- `contracts/EASClaimVerifier.sol`
  - Main Identity Verifier module (EAS backend)
  - Verifies required topics via mapped EAS schemas
- `contracts/EASTrustedIssuersAdapter.sol`
  - Trusted attester allowlist per claim topic
- `contracts/EASIdentityProxy.sol`
  - Wallet → identity mapping (multi-wallet support)
- `contracts/EASClaimVerifierIdentityWrapper.sol`
  - Wrapper path for zero-modification integration patterns

---

## 3) Minimal integration flow

1. Deploy verifier + adapters
2. Map ERC-3643 claim topics → EAS schema UIDs
3. Register trusted attesters for each topic
4. Link wallet(s) to identity (optional but recommended)
5. Issue EAS attestations (KYC/accreditation/etc.)
6. Run transfer checks through ERC-3643 compliance flow

For full commands and examples: `docs/integration-guide.md`.

---

## 4) Validation path (what to run)

### Local

```bash
forge test
forge test --match-path test/integration/*
forge test --gas-report
# optional
forge coverage
```

### Pilot (Sepolia)

```bash
# in order
script/DeployTestnet.s.sol
script/RegisterSchemas.s.sol
script/SetupPilot.s.sol
```

Expected behavior:
- transfer to verified identity => allowed
- transfer to unverified identity => blocked

---

## 5) Demo and artifacts

- Demo UI repo: https://github.com/claudyfaucant/eas-erc3643-bridge-demo
- Architecture diagrams: `diagrams/*.mmd`
- System docs index: `docs/README.md`

---

## 6) What is production-ready vs pending

### Ready now
- Core contracts and tests
- Dual-mode verifier concept
- Pilot seeding flow for attestations in `SetupPilot.s.sol`

### Still to complete
- Full proxy upgrade path (UUPS/transparent) end-to-end rollout
- Single-command full-stack Sepolia demo (token + identity + transfer UX)

---

## 7) Suggested GitHub review checklist

- [ ] CI green (Build/Lint/Test/Coverage/Gas Report)
- [ ] `forge test` passes locally
- [ ] Claim topic ↔ schema mapping documented
- [ ] Trusted attesters configured
- [ ] Pilot scripts reproducible in sequence
- [ ] Demo repo link and setup instructions present

---

## 8) Quick links

- Main README: `../README.md`
- Integration guide: `integration-guide.md`
- Architecture overview: `architecture/system-architecture.md`
- PRD: `../PRD.md`
- Report: `PRD_EXECUTION_REPORT_2026-04-08.md`
