# Gas Benchmarks

Measured on Foundry (Solidity 0.8.24, optimizer 200 runs).

## Verification (isVerified)

The core verification function checks if a wallet has valid attestations for all required claim topics.

| Operation | Gas Cost | Notes |
|-----------|----------|-------|
| `isVerified()` — 1 topic | ~27,878 | Single KYC attestation check |
| `isVerified()` — 3 topics | ~57,309 | KYC + accreditation + country |
| `isVerified()` — 5 topics | ~86,808 | Full compliance suite |

Gas scales linearly with the number of required topics (~15,000 gas per additional topic).

## Attestation Operations

| Operation | Gas Cost | Notes |
|-----------|----------|-------|
| Create EAS attestation | ~217,853 | KYC provider creates attestation via EAS |
| Register attestation | ~33,907 | Register attestation UID in EASClaimVerifier |

## Identity Operations

| Operation | Gas Cost | Notes |
|-----------|----------|-------|
| Register wallet | ~76,019 | Link wallet to identity in EASIdentityProxy |

## Trusted Attester Management

| Operation | Gas Cost | Notes |
|-----------|----------|-------|
| Add trusted attester | ~151,711 | Add KYC provider to trusted list |

## Cost Estimates at 30 gwei

| Operation | Gas | Cost (30 gwei) | Cost (USD @ $3000 ETH) |
|-----------|-----|----------------|------------------------|
| Verify (1 topic) | 27,878 | 0.00084 ETH | $2.51 |
| Verify (3 topics) | 57,309 | 0.00172 ETH | $5.16 |
| Verify (5 topics) | 86,808 | 0.00260 ETH | $7.81 |
| Create attestation | 217,853 | 0.00654 ETH | $19.61 |
| Register attestation | 33,907 | 0.00102 ETH | $3.05 |
| Register wallet | 76,019 | 0.00228 ETH | $6.84 |
| Add trusted attester | 151,711 | 0.00455 ETH | $13.65 |

**Note:** Costs are significantly lower on L2s (Base, Arbitrum, Optimism) — typically 10-100x cheaper.

## EAS vs ONCHAINID Comparison

| Operation | EAS Bridge | ONCHAINID | Notes |
|-----------|------------|-----------|-------|
| Deploy identity | Not required | ~500,000 | EAS attestations don't require per-user contracts |
| Verification (1 topic) | ~27,878 | ~35,000 | Similar, slight EAS advantage |
| Verification (3 topics) | ~57,309 | ~80,000 | EAS more efficient for multiple topics |
| Create attestation | ~217,853 | ~150,000 | ONCHAINID simpler claim storage |

**Key insight:** EAS eliminates the per-user identity contract deployment cost (~500,000 gas), making it significantly cheaper for onboarding new investors.

## L2 Cost Comparison

At typical L2 gas prices (0.01-0.1 gwei effective):

| Operation | L1 (30 gwei) | Base/Arbitrum | Savings |
|-----------|--------------|---------------|---------|
| Verify (3 topics) | $5.16 | $0.02-0.17 | 97-99% |
| Create attestation | $19.61 | $0.07-0.65 | 97-99% |
| Register wallet | $6.84 | $0.03-0.23 | 97-99% |

## Optimization Opportunities (V2)

The current implementation prioritizes simplicity and correctness. Future optimizations could include:

- **Batch attestation queries** — Reduce external calls by batching EAS reads
- **Attestation caching** — Configurable TTL cache for frequently-verified addresses
- **Merkle proof verification** — For off-chain attestation batches
- **Bitmap topic checking** — Pack multiple topic checks into single storage reads

## Running Benchmarks

To reproduce these benchmarks:

```bash
# Run gas benchmark tests
forge test --match-contract GasBenchmark -vvv

# Generate gas report
forge test --gas-report
```
