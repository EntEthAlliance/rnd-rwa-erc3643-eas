# Shibui Demo UI

A first-party, in-repo demo of the Shibui attestation lifecycle on Sepolia.

Three screens, three actors, one decision surface:

| Screen | Actor | Primary action |
|---|---|---|
| `/admin` | Issuer / EEA | Register schemas, add trusted attesters |
| `/attester` | KYC provider | Issue + revoke investor attestations |
| `/transfer` | Reviewer | Watch Alice succeed, Bob revert, Carol flip after revoke |

Full product spec: [`docs/PRD_DEMO_UI.md`](../../docs/PRD_DEMO_UI.md).

---

## Prerequisites

- Node.js 20+
- A funded Sepolia wallet (MetaMask, Rabby, etc.)
- A WalletConnect Cloud projectId (free at https://cloud.walletconnect.com)
- The Shibui stack deployed on Sepolia — see [root `README.md`](../../README.md) testnet section

## Local run

```bash
cd demo/shibui-app
cp .env.example .env.local
# Edit .env.local: add NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID and your Sepolia RPC
npm install
npm run dev
```

Open http://localhost:3000.

## Environment

| Var | Default | Purpose |
|---|---|---|
| `NEXT_PUBLIC_SEPOLIA_RPC_URL` | `https://rpc.sepolia.org` | Read/write RPC endpoint |
| `NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID` | — | Required for RainbowKit walletconnect connector |

## Deployment addresses

All on-chain addresses are resolved from [`deployments/sepolia.json`](../../deployments/sepolia.json) at the repo root. The `predev` / `prebuild` hook syncs that file into `lib/_deployments.generated.json` so TypeScript can type-check the import.

**To wire the UI to a fresh Sepolia deployment:**

1. Deploy the Shibui stack:
   ```bash
   forge script script/DeployTestnet.s.sol:DeployTestnet \
     --rpc-url $RPC_SEPOLIA --broadcast
   ```
2. Register schemas (outputs UIDs):
   ```bash
   forge script script/RegisterSchemas.s.sol:RegisterSchemas \
     --rpc-url $RPC_SEPOLIA --broadcast
   ```
3. Deploy the demo ERC-3643 token:
   ```bash
   EAS_CLAIM_VERIFIER=0x... DEPLOYER_PRIVATE_KEY=0x... \
     forge script script/deploy/DeployDemo.s.sol:DeployDemo \
     --rpc-url $RPC_SEPOLIA --broadcast
   ```
4. Copy every address + schema UID + demo-token address into `deployments/sepolia.json`.
5. Seed Alice / Bob / Carol (wallets, identities, attestations) into the `demo.investors` and `demo.attestations` blocks.
6. Run `npm run dev` — the configuration-gate banners will disappear as fields fill in.

## Scripts

- `npm run dev` — Next.js dev server on :3000
- `npm run build` — production build
- `npm run typecheck` — `tsc --noEmit`
- `npm run lint` — Next.js ESLint

## Stack

- Next.js 14 (app router)
- wagmi v2 + viem + RainbowKit for wallet + tx
- `@ethereum-attestation-service/eas-sdk` for schema encoding
- Tailwind CSS
- React Query (transitively via wagmi)

## What this demo is *not*

- Not mainnet-ready. `DemoERC3643Token` is labeled demo-only and skips ModularCompliance, OnchainID, recovery, partial freeze.
- Not a production admin console. No multi-sig, no RBAC UI.
- Not a replacement for the audited `isVerified()` path — this UI visualizes it, the contracts enforce it.

## Deprecation of the external demo

This app supersedes `claudyfaucant.github.io/eas-erc3643-bridge-demo/`. That external site is not tied to the canonical contracts; this one is.
