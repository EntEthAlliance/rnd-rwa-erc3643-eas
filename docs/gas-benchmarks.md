# Gas Benchmarks

Measured on Foundry (Solidity 0.8.24, optimizer 200 runs).

## Verification (isVerified)

| Operation | Gas Cost | Notes |
|-----------|----------|-------|
| `isVerified()` — 1 topic | ~409,322 | Single KYC attestation check |
| `isVerified()` — 3 topics | ~1,044,175 | KYC + accreditation + country |
| `isVerified()` — 5 topics | ~1,679,102 | Full compliance suite |

## Identity Operations

| Operation | Gas Cost | Notes |
|-----------|----------|-------|
| `registerWallet()` | ~90,366 | Link wallet to identity |
| `getIdentity()` — with mapping | ~91,590 | Resolve wallet → identity |
| `getIdentity()` — no mapping | ~11,319 | Returns wallet address directly |
| Batch register (5 wallets) | ~367,037 | ~73,407 per wallet |

## Attestation Operations

| Operation | Gas Cost | Notes |
|-----------|----------|-------|
| Create EAS attestation | ~297,075 | KYC provider onboards investor |
| `registerAttestation()` | ~381,379 | Register attestation in verifier |
| Revoke attestation | ~268,522 | KYC provider revokes |

## Trusted Issuer Management

| Operation | Gas Cost | Notes |
|-----------|----------|-------|
| `addTrustedAttester()` | ~309,076 | Add KYC provider |
| `removeTrustedAttester()` | ~117,108 | Remove KYC provider |
| `updateAttesterTopics()` | ~106,648 | Change authorized topics |

## EAS vs ONCHAINID Comparison

The EAS verification path gas costs scale linearly with the number of required topics. For a typical deployment (1-3 topics), gas costs remain practical for L1 and are negligible on L2s.

**Optimization opportunities for V2:**
- Batch attestation queries to reduce external calls
- Attestation caching with configurable TTL
- Merkle proof verification for offchain attestation batches
