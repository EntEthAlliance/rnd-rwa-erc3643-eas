# Shibui (MVP) — Test Plan (Simple + Practical)

**Repo:** https://github.com/EntEthAlliance/rnd-rwa-erc3643-eas/

**Goal (MVP):** prove, with minimal effort, that an ERC-3643 issuer can **allow** eligible investors and **block** ineligible investors using **EAS attestations** as a pluggable identity backend.

**MVP Defaults**
- **Mode:** Identity-mode (wallet → identity) via `EASIdentityProxy`.
- **Canonical demo topic set:** **KYC only** (Topic `1`).
  - Optional extension: add Topic `7` (Accreditation) to show multi-topic gating.

---

## 1) Acceptance Criteria (what must be true)

### A) Eligibility verification
- `isVerified(wallet)` returns **true** only when **all required topics** resolve to **valid attestations** from **trusted attesters**.
- It returns **false** for: missing, revoked, expired, schema mismatch, untrusted attester.

### B) Trusted attester controls
- Attesters are configurable **per topic**.
- Removing an attester changes verification outcome **immediately**.

### C) Identity mapping
- Wallet→identity mapping works.
- Authorized agent semantics work (registering attestations / linking wallets as agent).

### D) Compatibility mode (wrapper)
- Wrapper path provides ONCHAINID-like interface without changing existing registry flow.

### E) Upgrade path (UUPS)
- Upgradeable contracts can be deployed and upgraded with state preserved.

---

## 2) What to Run (3 tiers)

### Tier 0 — Smoke (fast)
```bash
forge --version
forge install
forge build
forge test
```
**Pass condition:** all tests pass.

### Tier 1 — MVP acceptance (reviewer-friendly)
Run scenario + integration suites that directly reflect the Shibui MVP stories:
```bash
forge test --match-path "test/integration/*"
forge test --match-path "test/scenarios/*"
```

### Tier 2 — Optional (if reviewer asks)
Gas + upgrade coverage:
```bash
forge test --match-contract GasBenchmark -vvv
forge test --match-path "test/unit/UpgradeableContracts.t.sol"
```

---

## 3) Mapping: MVP Stories → Existing Tests

These are the MVP proof points a reviewer should look for.

### Core “Allow / Block”
- **Allow path (verified investor):**
  - `test/integration/BridgeIntegration.t.sol` (complete flows)
  - `test/integration/FullTransferLifecycle.t.sol` (end-to-end lifecycle)

- **Block path (missing / revoked / expired):**
  - `test/integration/AttestationRevocation.t.sol` (revocation + expiration)
  - `test/scenarios/InvestorLifecycle.t.sol` (expiration + renewal)

### Trusted attesters (per-topic + removal)
- `test/unit/EASTrustedIssuersAdapter.t.sol`
- `test/integration/DualModeVerification.t.sol` (fallback and removal behavior)

### Identity-mode (wallet → identity) + agents
- `test/unit/EASIdentityProxy.t.sol`
- `test/scenarios/InvestorLifecycle.t.sol` (multi-wallet scenarios)

### Wrapper (compatibility mode)
- `test/unit/EASClaimVerifierIdentityWrapper.t.sol`

### UUPS upgrade path
- `test/unit/UpgradeableContracts.t.sol`

---

## 4) Evidence to Capture (for PR / review)

Keep it short:
- The exact commands executed
- Test summary line: `229 tests passed, 0 failed, 0 skipped`
- (Optional) one-liner gas summary from `GasBenchmark` if asked

---

## 5) MVP “Done” Gate

MVP is acceptable when:
1) Tier 0 smoke passes
2) Tier 1 suites pass
3) Demo script (`docs/shibui-mvp-demo-script.md`) can be executed without undocumented steps
