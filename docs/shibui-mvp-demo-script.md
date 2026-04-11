# Shibui (MVP) — Demo Script (8–12 minutes)

**Objective:** show the Shibui identity layer can both:
1) **allow** an eligible investor, and
2) **block** an ineligible (revoked/expired/untrusted) investor,
using EAS attestations.

**MVP defaults:** identity-mode (wallet→identity) + Topic `1` (KYC).

---

## 0) Setup (1 minute)

Prereqs:
- Foundry installed (`anvil`, `forge`)

Start a local chain:
```bash
anvil
```

---

## 1) 60-second product framing (talk track)

- ERC-3643 defines **what** needs to be checked (claim topics like KYC/accreditation).
- Shibui makes **how** verification happens pluggable.
- Here we use **EAS** as the credential backend:
  - issuers choose trusted attesters (banks/KYC providers)
  - investors can reuse attestations across tokens that trust the attester
  - revocation is immediate on-chain.

---

## 2) Run the pilot script (2 minutes)

In a second terminal:
```bash
# from repo root
forge script script/SetupPilot.s.sol:SetupPilot \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast
```

What it does (high level):
- deploys verifier + adapter + identity proxy + mocks
- configures KYC topic
- seeds a small set of investor identities + attestations

---

## 3) Show the “ALLOW” case (2 minutes)

Narrate:
- “This investor has a valid KYC attestation from a trusted attester → verified.”

(If the script prints addresses, point to the investor wallet + the `isVerified` result. If not printed, use the repo’s integration tests as the canonical evidence.)

---

## 4) Show the “BLOCK” case (2 minutes)

Pick one simple block reason (MVP):
- revoke the attestation, OR
- remove the attester from trusted list.

Narrate:
- “Nothing changed in the token. We changed the trust/attestation state. Verification flips immediately.”

---

## 5) 60-second modularity close (why it matters)

- Issuers keep ERC-3643 semantics.
- Attesters compete (multiple providers per topic).
- Investors reuse credentials.
- Upgradeability exists (UUPS path) but **mainnet usage is gated by audit readiness**.

---

## Optional extension (60–90 seconds)

Add a second topic (Topic `7` Accreditation):
- investor now needs **two** attestations (KYC + Accreditation)
- show verification fails until both are present.

---

## What to show a reviewer as evidence

- `forge test` summary (pass/fail)
- One demo run output (the script broadcast output)
- If asked: `GasBenchmark` summary
