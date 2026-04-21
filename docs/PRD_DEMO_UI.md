# PRD — Shibui Demo UI (Sepolia)

**Status:** Draft
**Owner:** EEA R&D
**Target branch:** `feature/demo-ui`
**Related issue:** TBD
**Last updated:** 2026-04-20

---

## 1. Problem

The Shibui monorepo ships working contracts, 200+ passing tests, and a pilot script that deploys 5 hardcoded investors on Sepolia. A reviewer can inspect Etherscan transactions after the fact, but they cannot **see the decision surface** — who issues an attestation, what fields it carries, who authorizes the attester, how revocation takes effect in real time.

A separately hosted demo exists at `claudyfaucant.github.io/eas-erc3643-bridge-demo/`. It is not in this repository, not tied to the canonical contracts, and not reproducible from the repo alone. That violates the project's own discipline: **"If it is not in Git, it does not exist."**

Institutions evaluating Shibui need a first-party, reproducible UI that renders the three moments that matter:

1. **Admin setup** — register schemas and authorize attesters.
2. **Attestation issuance** — populate investor data and sign.
3. **Transfer verification** — see allow/block resolve on-chain.

Without this, the demo is a terminal window. With it, the demo is an institutional walkthrough.

---

## 2. Goals

- Ship a reproducible demo UI in `/demo` inside this repo.
- Cover the full lifecycle: schema registration → attester authorization → attestation issuance → transfer verification → revocation.
- Run against Sepolia with deployed Shibui contracts — no mock data in the happy path.
- Pass the "laptop test": an EEA member bank can drive the demo themselves in under 10 minutes.

## 3. Non-goals

- Mainnet deployment, multi-sig flows, or production-grade admin UX.
- Replacing the external demo site; this is the canonical one going forward.
- Custody, key management, or wallet creation inside the UI.
- Bulk operations, CSV imports, or analytics dashboards.
- Writing or modifying contracts — this PR is UI-only.

---

## 4. User stories

### 4.1 Admin (EEA / issuer)

> As an issuer, I want to register the Shibui EAS schemas on Sepolia and authorize a KYC provider, so that my token's compliance layer is bootstrapped before any investor interaction.

**Acceptance:**
- Connect admin wallet via wagmi/viem.
- Click "Register schemas" → signs two EAS `register()` transactions → displays the two resulting schema UIDs (Investor Eligibility v2, Issuer Authorization v1).
- Click "Add attester" → form takes attester address + claim topics → creates Schema-2 authorization attestation → calls `addTrustedAttester(attester, topics, authUID)` on `EASTrustedIssuersAdapter`.
- Resulting state renders as a list of active trusted attesters with their authorized topics.

### 4.2 KYC operator (trusted attester)

> As a KYC provider, I want to issue a compliance attestation for a specific investor wallet, so that the investor becomes eligible under the token's compliance rules.

**Acceptance:**
- Form fields: investor wallet, KYC status, AML status, sanctions status, source of funds status, accreditation type, country code, expiration, evidence hash.
- Field values match the Investor Eligibility v2 schema exactly — no renaming, no hidden transforms.
- Click "Sign & issue" → wallet signs EAS `attest()` → attestation UID returned.
- Click "Register in Shibui" → calls `EASClaimVerifier.registerAttestation(identity, topic, uid)`.
- "Revoke" action calls EAS `revoke()` and reflects the new state on next read.

### 4.3 Reviewer (transfer demo)

> As a reviewer, I want to see three pre-seeded investors with different compliance states and watch transfers succeed or fail in real time, so that I can validate Shibui's allow/block behavior without reading Solidity.

**Acceptance:**
- Three investor cards: Alice (fully verified), Bob (missing accreditation), Carol (KYC verified then revoked live during the demo).
- Each card shows live `isVerified()` result read directly from Sepolia.
- "Transfer" button attempts a small transfer of the demo ERC-3643 token → result renders as success (tx hash linked to Etherscan) or revert (with compliance error decoded).
- "Revoke Carol's KYC" button executes the revocation and the card flips from allowed to blocked on the next poll.

---

## 5. Scope

### In scope

- Next.js 14 app in `/demo` (app router).
- Three routes: `/admin`, `/attester`, `/transfer`.
- Wallet connection via wagmi + viem + RainbowKit.
- EAS interactions via `@ethereum-attestation-service/eas-sdk`.
- Read-only contract calls against Sepolia RPC.
- Minimal ERC-3643 demo token contract + deploy script (the known gap flagged in `PRD_EXECUTION_REPORT_2026-04-08.md`, follow-up item 2).
- One SKILL.md-style README documenting local setup and deployment.
- CI check: `demo` builds successfully on every PR.

### Out of scope

- UUPS proxy upgrades (parked — separate workstream per `docs/execution/mvp-uups-execution-plan.md`).
- Mainnet gating (no `AUDIT_ACKNOWLEDGED` path in the UI).
- Dark mode polish, accessibility audit beyond basic keyboard nav.
- Internationalization.

---

## 6. Technical design

### 6.1 Stack

| Layer | Choice | Rationale |
|---|---|---|
| Framework | Next.js 14 (app router) | Static export works on GitHub Pages; keeps demo hosting trivial. |
| Wallet | wagmi v2 + viem + RainbowKit | Current standard for EVM dApps; no vendor lock-in. |
| EAS | `@ethereum-attestation-service/eas-sdk` | Official SDK — aligns with "standard over custom." |
| Styling | Tailwind + minimal component library | No custom design system; keep surface small. |
| State | React Query (built into wagmi) | No Redux, no Zustand — scope is too small. |

### 6.2 Directory layout

```
/demo
  /app
    /admin           → schema + attester management
    /attester        → attestation issuance form
    /transfer        → investor cards + transfer demo
    layout.tsx
    page.tsx         → landing + navigation
  /lib
    contracts.ts     → typed ABIs + Sepolia addresses
    eas.ts           → EAS SDK wrappers
    schemas.ts       → Investor Eligibility v2 encoding
  /public
  README.md
  package.json
  next.config.js
```

### 6.3 Contract interaction surface

| Action | Contract | Function |
|---|---|---|
| Register schema | EAS SchemaRegistry | `register(schema, resolver, revocable)` |
| Add attester | `EASTrustedIssuersAdapter` | `addTrustedAttester(attester, topics, authUID)` |
| Issue attestation | EAS | `attest(AttestationRequest)` |
| Register attestation | `EASClaimVerifier` | `registerAttestation(identity, topic, uid)` |
| Check verification | `EASClaimVerifier` | `isVerified(wallet)` — view |
| Revoke | EAS | `revoke(RevocationRequest)` |
| Demo transfer | `DemoERC3643Token` | `transfer(to, amount)` |

### 6.4 Data populated from users

This directly answers the open question from review: **where does investor data come from?**

- In the current `SetupPilot.s.sol` flow → hardcoded deterministic wallets and fixed KYC values.
- In the demo UI → an operator fills the form in screen 2 (KYC operator). Values are `abi.encode`-packed into the schema shape and signed via the connected wallet.
- For the reviewer walkthrough → three pre-seeded investors are set up by a one-time admin action before the demo; the reviewer drives the transfer screen only.

### 6.5 Network + addresses

- Sepolia EAS: `0xC2679fBD37d54388Ce493F1DB75320D236e1815e`
- Sepolia SchemaRegistry: `0x0a7E2Ff54e76B8E6659aedc9103FB21c038050D0`
- Shibui contract addresses: read from `deployments/sepolia.json` (added by this PR).

---

## 7. Acceptance criteria (definition of done)

**Must pass before merge:**

- [ ] `demo` builds via `pnpm build` with zero warnings.
- [ ] All three routes render against Sepolia with no hardcoded addresses outside `deployments/sepolia.json`.
- [ ] Admin flow: schema registration completes end-to-end on a fresh Sepolia deployment.
- [ ] Attester flow: issuing and revoking an attestation updates `isVerified()` on next read.
- [ ] Transfer flow: Alice succeeds, Bob reverts with compliance error, Carol flips after revoke.
- [ ] `forge test` still passes — no contract regressions.
- [ ] README in `/demo` documents env vars, local run, and Sepolia deploy.
- [ ] CI added to `.github/workflows` for `demo` build check.
- [ ] External demo URL in main README updated or removed, depending on hosting decision.

**Reviewer smoke test:**

Reviewer with a funded Sepolia wallet and no prior repo knowledge can:
1. Clone the repo.
2. Follow the README.
3. Connect their wallet.
4. Drive the transfer demo end-to-end (allow + block + revoke) in under 10 minutes.

---

## 8. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Attester wallet key exposure during live demo | Demo uses testnet-only wallets; README explicitly prohibits reuse on mainnet. |
| Sepolia RPC rate limits during public demo | Fall back to public Alchemy/Infura keys; document BYO key override. |
| ERC-3643 demo token is not audit-gated | Explicitly labeled "demo only" in contract name and deploy script; never deployed to mainnet. |
| UI drift from contract ABIs | Typed ABIs generated from `forge build` output; CI check fails if drift. |
| Demo data is confusing (fake investors look real) | All investor names are obviously placeholder (Alice/Bob/Carol); addresses are deterministic and documented. |

---

## 9. Alignment with project principles

- **Production-first discipline:** UI is scoped, reversible, independent module. No coupling to mainnet paths.
- **Git as source of truth:** Demo lives in-repo, reproducible from clone. Replaces the external demo site.
- **Standard over custom:** Uses official EAS SDK, standard Next.js, wagmi/viem. No bespoke identity tooling.

---

## 10. Open questions

1. Does the existing external demo at `claudyfaucant.github.io/eas-erc3643-bridge-demo/` have source we should port, or start clean?
2. Should the demo token be its own repo, or vendored into `/contracts/demo`?
3. Who hosts the Sepolia-deployed instance — GitHub Pages off this repo, or EEA infrastructure?
4. Do we want a "reset demo" admin button that re-seeds Alice/Bob/Carol for the next presenter?

---

## 11. Follow-ups (not this PR)

- Integrate with the single-script Sepolia token-transfer demo once built (blocker 2 in `PRD_EXECUTION_REPORT_2026-04-08.md`).
- Wire UUPS proxy upgrade flow into admin console once Gate C of the UUPS plan lands.
- Add Base Sepolia, Arbitrum Sepolia as selectable networks — validate multi-chain claim per README.
