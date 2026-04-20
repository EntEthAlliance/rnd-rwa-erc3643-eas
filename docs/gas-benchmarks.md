# Gas Benchmarks

Measured on Foundry (Solidity 0.8.24, optimizer 200 runs, via_ir enabled) against
`test/integration/GasBenchmark.t.sol`. Refreshed post-refactor (PR #54 + follow-ups).

> Reproduce with `forge test --match-contract GasBenchmarkTest -vvvv | grep GasUsed`.

## Intentional vs unintentional drift

Current numbers reflect the cost of payload-aware verification (audit C-1):
`isVerified` decodes the attestation payload and invokes an `ITopicPolicy`
module per required claim topic. This is **deliberately** more expensive than
the pre-refactor "claim exists and attester is trusted" check, because the
old path could not distinguish `kycStatus = VERIFIED` from `kycStatus =
PENDING` — a regulatory non-starter. The numbers below are the floor for a
regulatorily honest check, not a target to drive down.

To guard against *unintentional* regressions, `GasBenchmark.t.sol` locks
in ceilings via `assertLt` with ~10k headroom above each current reading:

| Operation | Current | Ceiling (asserted in test) |
|---|---:|---:|
| `isVerified` — 1 topic | 31,539 | 45,000 |
| `isVerified` — 3 topics | 80,083 | 95,000 |
| `isVerified` — 5 topics | 122,090 | 140,000 |

If those asserts fire, either a legitimate optimisation landed (bump the
ceiling down) or a regression slipped in (investigate before merge).

## Verification (`isVerified`)

The core verification function is the hot path: one call per token transfer that
involves a wallet the issuer's compliance module wants to gate. Post-refactor,
the verifier invokes an `ITopicPolicy` per required topic and iterates the
trusted-attester list (capped at `MAX_ATTESTERS_PER_TOPIC = 5`).

| Operation | Gas | Notes |
|---|---:|---|
| `isVerified()` — 1 topic (KYC) | **31,539** | `KYCStatusPolicy.validate()` + one EAS read |
| `isVerified()` — 3 topics (KYC + country + accreditation) | **80,083** | Three policy invocations, single attestation covers all three |
| `isVerified()` — 5 topics (KYC + AML + country + accreditation + sanctions) | **122,090** | Five policies against one Schema-v2 payload |

Linear scaling: ~22,500 gas per additional topic after the fixed setup. The
payload-aware verifier adds overhead (the decode + predicate) vs. the
pre-refactor "does the attestation exist" check, which is the cost of actually
enforcing regulatory semantics on-chain.

## Administration

| Operation | Gas | Notes |
|---|---:|---|
| `registerAttestation` | **53,393** | Attester pushes a UID to the verifier after attesting on EAS |
| `addTrustedAttester` (with `authUID`) | **201,533** | Includes Schema-2 attestation lookup + subset check (audit C-5) |
| `registerWallet` (identity proxy) | **79,029** | Wallet → identity binding by an AGENT_ROLE holder |

## Cost estimates at 30 gwei

| Operation | Gas | L1 (30 gwei) | USD @ $3000 ETH |
|---|---:|---:|---:|
| `isVerified` (1 topic) | 31,539 | 0.00095 ETH | ~$2.84 |
| `isVerified` (3 topics) | 80,083 | 0.00240 ETH | ~$7.21 |
| `isVerified` (5 topics) | 122,090 | 0.00366 ETH | ~$10.99 |
| `registerAttestation` | 53,393 | 0.00160 ETH | ~$4.81 |
| `addTrustedAttester` | 201,533 | 0.00605 ETH | ~$18.14 |
| `registerWallet` | 79,029 | 0.00237 ETH | ~$7.11 |

L2 execution (Base, Arbitrum, Optimism) is typically 1-2 orders of magnitude
cheaper per op; use these numbers as an upper bound.

## Pre- vs post-refactor

The pre-refactor verifier used a single-slot cache (`_activeAttestations`)
and did not call any policy module, so it was cheaper per call but regulatorily
incorrect (it could not distinguish `kycStatus = VERIFIED` from
`kycStatus = PENDING`). The new hot-path cost buys you:

1. Per-topic policy evaluation (audit C-1)
2. Multi-attester resilience: a revoked or untrusted attester no longer
   disables the investor (audit C-2)
3. Admin audit trail: every trusted-attester change references a live EAS
   Schema-2 attestation (audit C-5)

| | Pre-refactor | Post-refactor | Delta |
|---|---:|---:|---:|
| `isVerified(1 topic)` | ~27,878 | 31,539 | +13% |
| `isVerified(3 topics)` | ~57,309 | 80,083 | +40% |
| `isVerified(5 topics)` | ~86,808 | 122,090 | +41% |

The jump at 3+ topics reflects the per-topic policy invocation cost — expected
and acceptable given that the pre-refactor numbers were achieved by skipping
the checks that make the system regulatorily useful.

## Optimisation opportunities (V2)

- **Policy result caching** — memoise decoded payloads across topics that share
  Schema 1 v2 (every topic except AML/sanctions in the typical setup uses the
  same attestation; decoding once per call instead of per topic would recover
  ~20-30% of the gas at 3+ topics).
- **Bitmap-packed trusted-attester set** — replace the `address[]` per-topic
  list with a fixed-size slot; drops the SLOAD count at the cost of an upper
  bound on attester count.
- **Off-chain attestation verification** — move from "registered on-chain" to
  "presented via signed proof", so verification reads a single proof instead of
  N EAS attestations. Deferred to V2.

## Running the benchmarks

```bash
# Gas emitted by the GasBenchmark tests (cheap and targeted)
forge test --match-contract GasBenchmarkTest -vvvv 2>&1 | grep 'emit GasUsed'

# Full gas report (slower; covers every public/external entry point)
forge test --gas-report
```
