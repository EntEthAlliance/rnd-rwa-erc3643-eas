# MVP Validation + Demo Guide (Quick Path)

Use this guide to validate and demo the MVP with minimal setup.

## Audience
- Product reviewer
- Engineer validating claims quickly
- Presenter running a short live demo

---

## 1) Quick Validation (non-expert)

## Prerequisites
- Foundry installed
- Repo dependencies installed

## Commands
```bash
# from repo root
forge install
forge build
forge test
```

Optional focused checks (recommended for review confidence):
```bash
# run parity/integration slices (adjust match pattern to current suite naming)
forge test --match-test "*Parity*"
forge test --match-path "test/integration/*"
```

## What “good” looks like
- Build completes with no errors
- Test suite passes
- No unexpected failures in parity-focused tests

---

## 2) MVP Demo Script (8–12 min)

## Objective
Show that the modular stack can both:
- allow eligible investors,
- block ineligible investors,
while keeping component responsibilities clear.

## Demo flow
1. **Explain architecture (1 min)**
   - Kernel adapter + orbitals (verification/registry/trusted attesters/identity mapping).

2. **Run setup (2 min)**
```bash
forge script script/SetupPilot.s.sol:SetupPilot --rpc-url http://127.0.0.1:8545 --broadcast
```

3. **Show success path (2 min)**
   - Investor with valid trusted attestations is verified.

4. **Show failure path (2 min)**
   - Missing/revoked/expired/untrusted attestation returns not verified.

5. **Show modularity (2 min)**
   - Map each observed behavior to responsible orbital.

6. **Business close (1 min)**
   - “Same compliance semantics, lower coupling, credible modular evolution path.”

---

## 3) Evidence to include in PR

- Exact commands executed
- Build/test results summary
- Demo proof points (success + failure outcomes)
- Any caveats / skipped checks

---

## 4) Common Failure Modes

1. Missing local RPC/anvil endpoint
2. Missing dependencies
3. Test name patterns differ from suggested match filters

If these occur, run full `forge test` and capture output in PR notes.

---

## 5) MVP Gate

Validation is complete when:
- quick path commands run successfully,
- demo flow can be executed without undocumented setup,
- evidence is attached in PR in reviewer-friendly format.
