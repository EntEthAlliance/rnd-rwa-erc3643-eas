# EAS-ERC3643: Open Identity Infrastructure for Security Tokens

A modular identity layer for ERC-3643 security tokens using EAS attestations.

## Architecture Decision (Frozen)

This repository now ships a **single production architecture**:
- Monolithic bridge contracts (no competing Valence/Diamond code in mainline)
- UUPS proxy deployment path
- One integration guide and one deployable stack

Valence/Diamond exploratory work is archived on branch **`research/valence-spike`** and is not part of production implementation.

## Core Contracts

| Contract | Role |
|---|---|
| `EASClaimVerifier` | Core topic-based verification against EAS attestations |
| `EASTrustedIssuersAdapter` | Per-topic trusted attester management |
| `EASIdentityProxy` | Wallet↔identity mapping and agent support |
| `EASClaimVerifierIdentityWrapper` | Zero-modification compatibility wrapper |

## Quickstart

```bash
forge install
forge build
forge test
```

## Validation + Demo

- `docs/mvp-validation-and-demo.md`

## Documentation

- `PRD.md` — single-source MVP product definition
- `docs/integration-guide.md` — integration path
- `docs/gas-benchmarks.md` — gas behavior
- `docs/erc3643-eas-implementation-guide.md` — implementation summary

## Security Note

Mainnet usage must be gated by explicit audit readiness controls (see `AUDIT.md` once introduced).

## License

MIT
