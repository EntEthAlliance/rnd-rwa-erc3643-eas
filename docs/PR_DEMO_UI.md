# feat(demo): add first-party Shibui demo UI for Sepolia

**Type:** Feature
**Scope:** `/demo/shibui-app` (new), `/contracts/demo/DemoERC3643Token.sol` (new), `/script/deploy/DeployDemo.s.sol` (new), `/deployments/sepolia.json` (new), `README.md`, `.github/workflows/demo-build.yml` (new), `docs/PRD_DEMO_UI.md` (new)
**Status:** Ready — scaffolding + working UI + PRD + demo token in this PR

Closes #TBD
Related: `docs/PRD_EXECUTION_REPORT_2026-04-08.md` (follow-up item 2)

---

## Why

The repo ships working contracts and a scripted pilot, but institutional reviewers evaluating Shibui cannot see the decision surface — who authorizes attesters, who issues attestations, how revocation resolves in real time. The external demo at `claudyfaucant.github.io/eas-erc3643-bridge-demo/` sits outside the repo, which violates the project's own rule: *"If it is not in Git, it does not exist."*

This PR brings the demo in-house so the repo is self-contained and institutionally presentable.

## What this PR does

1. Adds `docs/PRD_DEMO_UI.md` — full product spec for the demo UI.
2. Scaffolds `/demo/shibui-app` as a Next.js 14 app with three wired routes: `/admin`, `/attester`, `/transfer`.
3. Wires wagmi v2 + viem + RainbowKit + `@ethereum-attestation-service/eas-sdk`.
4. Adds `deployments/sepolia.json` — single source of truth for contract addresses, consumed by the UI at build time via a sync hook.
5. Adds `contracts/demo/DemoERC3643Token.sol` — minimal ERC-3643-shaped token that gates transfers on `EASClaimVerifier.isVerified()`.
6. Adds `script/deploy/DeployDemo.s.sol` — forge script to deploy + mint the demo token on Sepolia.
7. Adds `.github/workflows/demo-build.yml` — CI check for typecheck, lint, and build on every demo-path change.
8. Updates root `README.md` with a "Live demo" section pointing at the in-repo path.
9. Leaves the existing `demo/shibui-static/` presentation site intact (no route collision).

## Architecture

Three screens map 1:1 to the three actors in the compliance lifecycle:

| Screen | Actor | Primary action |
|---|---|---|
| `/admin` | Issuer / EEA | Register schemas, add trusted attesters |
| `/attester` | KYC provider | Issue + revoke investor attestations |
| `/transfer` | Reviewer | Watch Alice succeed, Bob revert, Carol flip after revoke |

All contract interactions run against Sepolia. The UI reads every address from `deployments/sepolia.json` — there is one source of truth. Until that file is populated, each page renders a `ConfigurationGate` banner listing exactly which addresses / schema UIDs are still missing.

Full design rationale, user stories, and acceptance criteria: `docs/PRD_DEMO_UI.md`.

## Test plan

- `npm run build` in `/demo/shibui-app` → passes in CI.
- `forge build` → `DemoERC3643Token.sol` compiles cleanly.
- `forge test` → existing 200/200 still passes (no changes to audited contracts).
- Manual: connect wallet on Sepolia → each of three routes renders; admin flow produces two schema UIDs; attester flow issues + revokes an attestation; transfer flow shows live `isVerified` state and reverts Bob.

## Reproducibility

```bash
git clone git@github.com:EntEthAlliance/rnd-rwa-erc3643-eas.git
cd rnd-rwa-erc3643-eas

# 1. Deploy contracts on Sepolia (see root README "Testnet pipeline")
forge script script/DeployTestnet.s.sol:DeployTestnet --rpc-url $RPC_SEPOLIA --broadcast
forge script script/RegisterSchemas.s.sol:RegisterSchemas --rpc-url $RPC_SEPOLIA --broadcast
EAS_CLAIM_VERIFIER=0x... forge script script/deploy/DeployDemo.s.sol:DeployDemo --rpc-url $RPC_SEPOLIA --broadcast

# 2. Populate deployments/sepolia.json with the output addresses
# 3. Run the UI
cd demo/shibui-app
cp .env.example .env.local
npm install
npm run dev
```

Opens `localhost:3000` with the three-screen demo against Sepolia.

## Files added

```
docs/PRD_DEMO_UI.md
docs/PR_DEMO_UI.md
contracts/demo/DemoERC3643Token.sol
script/deploy/DeployDemo.s.sol
deployments/sepolia.json
demo/shibui-app/
  app/
    admin/page.tsx
    attester/page.tsx
    transfer/page.tsx
    layout.tsx
    page.tsx
    providers.tsx
    globals.css
  components/
    Nav.tsx
    StatusBadge.tsx
    TxFeedback.tsx
    ConfigurationGate.tsx
    InvestorCard.tsx
  lib/
    abis.ts
    constants.ts
    contracts.ts
    deployments.ts
    eas.ts
    format.ts
    schemas.ts
    wagmi.ts
  scripts/
    sync-deployments.mjs
  README.md
  package.json
  next.config.js
  tsconfig.json
  tailwind.config.ts
  postcss.config.js
  .eslintrc.json
  .env.example
  .gitignore
.github/workflows/demo-build.yml
```

## Files changed

- `README.md` — new "Live demo" section pointing to `/demo/shibui-app`.

## Reviewer checklist

- [ ] PRD scope matches the three user stories we actually need
- [ ] No mainnet paths touched
- [ ] No audited contracts modified — only `contracts/demo/` is new
- [ ] CI passes (forge + demo build)
- [ ] README "Live demo" section consistent with new `/demo/shibui-app`
- [ ] `DemoERC3643Token` clearly labeled demo-only in name and revert message
- [ ] `deployments/sepolia.json` zero-values documented and gated in the UI

## Rollout plan

1. **This PR** — PRD + scaffolding + working UI + demo token + CI (reversible, no production impact).
2. **Next PR** — populate `deployments/sepolia.json` with actual Sepolia addresses after a clean testnet deployment.
3. **Next PR** — host the Sepolia-connected UI on GitHub Pages off this repo (or EEA infra).
4. **Next PR** — replace the external `claudyfaucant.github.io` link site-wide.

## Risks

- `DemoERC3643Token` is deliberately not a full T-REX implementation. Risk is mitigated by the name, revert messages, and explicit docs. It must never be deployed to mainnet.
- `deployments/sepolia.json` being committed with zero addresses is intentional — the UI gates on this and the CI build survives it. After real deployment, the file gets overwritten.
- The demo signs real Sepolia transactions from the operator's wallet. The README explicitly warns never to reuse that wallet on mainnet.

## References

- PRD: `docs/PRD_DEMO_UI.md`
- Demo README: `demo/shibui-app/README.md`
- Existing external demo (superseded): `claudyfaucant.github.io/eas-erc3643-bridge-demo/`
- Gap flagged in `docs/PRD_EXECUTION_REPORT_2026-04-08.md`, follow-up 2
- EAS Sepolia: `0xC2679fBD37d54388Ce493F1DB75320D236e1815e`
