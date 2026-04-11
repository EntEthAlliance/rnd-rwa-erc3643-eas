# Shibui (EAS ↔ ERC-3643)

Shibui is an open-source identity layer for ERC-3643 security tokens using EAS attestations.

It keeps ERC-3643 compliance semantics intact (topics like KYC / accreditation), while making the **verification backend pluggable**.

## Architecture Decision (Frozen)

This repository ships a **single production architecture**:
- Monolithic bridge contracts (no competing Valence/Diamond code in mainline)
- UUPS proxy deployment path
- One integration guide and one deployable stack

Valence/Diamond exploratory work is archived on branch **`research/valence-spike`** and is not part of production implementation.

## Core Contracts

| Contract | Role |
|---|---|
| `EASClaimVerifier` | Topic-based verification against EAS attestations |
| `EASTrustedIssuersAdapter` | Per-topic trusted attester management |
| `EASIdentityProxy` | Wallet↔identity mapping and agent support |
| `EASClaimVerifierIdentityWrapper` | Zero-modification compatibility wrapper |

## Validate (MVP)

Prereq: Foundry installed (`forge`, `anvil`).

```bash
forge install
forge build
forge test
```

Expected: **all tests pass** (current baseline: 229 tests, 0 failures).

## Demo (MVP, 8–12 min)

```bash
anvil
# in another terminal
forge script script/SetupPilot.s.sol:SetupPilot \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast
```

Presenter guide: `docs/shibui-mvp-demo-script.md`

## Documentation (Start Here)

- `PRD.md` — MVP scope + acceptance criteria
- `docs/shibui-mvp-test-plan.md` — simple MVP test plan + commands
- `docs/shibui-mvp-demo-script.md` — presenter-ready demo script
- `docs/integration-guide.md` — integration paths (pluggable verifier vs wrapper)
- `docs/gas-benchmarks.md` — gas behavior
- `docs/erc3643-eas-implementation-guide.md` — implementation summary

## Security Note

Mainnet usage must be gated by explicit audit readiness controls (see `AUDIT.md`).

## License

MIT
