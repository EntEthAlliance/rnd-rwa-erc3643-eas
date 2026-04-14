# Shibui — Pluggable Identity for ERC-3643 Security Tokens

> An open-source project by the [Enterprise Ethereum Alliance](https://entethalliance.org)

---

## What This Is

ERC-3643 is the standard for compliant security tokens (KYC, accreditation, jurisdiction checks). By default, it is hardwired to ONCHAINID as its identity backend — meaning every token issuer, every KYC provider, and every investor is locked into one implementation.

**Shibui breaks that lock.**

It replaces ONCHAINID with [Ethereum Attestation Service (EAS)](https://attest.org) as a pluggable identity backend — without touching the ERC-3643 token contract itself. The result: compliance work done once by a regulated institution (a bank, a KYC provider, a custodian) is reusable across every token that trusts that institution, on any chain where EAS is deployed.

**Analogy:** ERC-3643 defines *what* must be verified before a transfer. Shibui defines *how* that verification is sourced — and makes the "how" swappable.

---

## The Problem It Solves

| Without Shibui | With Shibui |
|---|---|
| KYC done per-token, per-provider | KYC attested once, reused across tokens |
| Identity locked to ONCHAINID | Any EAS-compatible attester is pluggable |
| No cross-chain portability | EAS runs on 15+ chains |
| Vendor dependency on a single provider | Open infrastructure, no single point of control |
| Compliance work siloed per issuer | Shared registry; attestations are institution-portable |

---

## How It Works

A token transfer triggers `isVerified(wallet)`. Shibui intercepts that call and resolves it through EAS instead of ONCHAINID:

```
Transfer requested
      │
      ▼
EASClaimVerifier.isVerified(wallet)
      │
      ├─ Resolve wallet → identity (via EASIdentityProxy)
      ├─ Check required claim topics (via ClaimTopicsRegistry)
      ├─ For each topic: fetch EAS attestation
      └─ Validate: exists? correct schema? trusted attester? not revoked? not expired?
            │
            ├─ All pass → transfer proceeds
            └─ Any fail → transfer blocked
```

Nothing changes in the ERC-3643 token contract. The compliance interface is the same. Only the backend is different.

---

## Architecture

```
TOKEN ISSUERS
  │ deploy + configure
  ▼
ERC-3643 TOKEN
  transfer() → isVerified()
                  │
                  ▼
         ┌─────────────────────────────┐
         │    SHIBUI IDENTITY LAYER    │
         │                             │
         │  EASClaimVerifier           │  ← core verification logic
         │  EASIdentityProxy           │  ← wallet → identity mapping
         │  EASTrustedIssuersAdapter   │  ← attester trust per topic
         │  ClaimTopicsRegistry        │  ← required topics per token
         └──────────────┬──────────────┘
                        │ queries
                        ▼
              EAS PROTOCOL (attest.org)
              deployed on 15+ chains
                        ▲
                        │ attest / revoke
              IDENTITY AUTHORITIES
              (banks, KYC providers, compliance services)
```

---

## Quickstart

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed
- Git

### Install

```bash
git clone https://github.com/EntEthAlliance/rnd-rwa-erc3643-eas
cd rnd-rwa-erc3643-eas
forge install
```

### Build

```bash
forge build
```

### Test

```bash
# Run all tests
forge test

# With verbose output
forge test -vvv

# Run a specific test
forge test --match-test test_isVerified_withValidAttestation

# Coverage report
forge coverage
```

### Deploy to Testnet (Sepolia)

```bash
export PRIVATE_KEY=<your-private-key>
export SEPOLIA_RPC_URL=<your-rpc-url>

forge script script/DeployTestnet.s.sol:DeployTestnet \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast
```

### Deploy to Mainnet

```bash
export PRIVATE_KEY=<your-private-key>
export MULTISIG_ADDRESS=<gnosis-safe-address>
export CLAIM_TOPICS_REGISTRY=<existing-registry-address>

forge script script/DeployMainnet.s.sol:DeployMainnet \
  --rpc-url $MAINNET_RPC_URL \
  --broadcast \
  --verify
```

### Run a Full Pilot (5 seeded investors)

```bash
forge script script/SetupPilot.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast
```

---

## Key Flows

### Investor onboarding

```
1. Token issuer deploys Shibui contracts
2. Configures required claim topics (e.g., topic 1 = KYC, topic 2 = accreditation)
3. Adds trusted attesters (e.g., a licensed KYC provider's address)
4. KYC provider attests investor wallet via EAS
5. Issuer registers attestation UID → verifier.registerAttestation(wallet, topic, uid)
6. verifier.isVerified(wallet) → true ✓  → investor can receive/transfer tokens
```

### Revocation (real-time compliance)

```
1. KYC provider revokes the EAS attestation
2. verifier.isVerified(wallet) → false ✗  → transfers blocked immediately
3. Re-attest when investor re-qualifies
4. verifier.isVerified(wallet) → true ✓  → access restored
```

### Multi-wallet identity

```
1. Investor registers multiple wallets to one identity
2. Attestation is issued to the identity, not per-wallet
3. All registered wallets inherit verification status
```

---

## Test Coverage

| File | What It Covers |
|------|----------------|
| `test/integration/FullTransferLifecycle.t.sol` | End-to-end: deploy → attest → transfer → revoke → block |
| `test/scenarios/InvestorLifecycle.t.sol` | Onboarding, expiration, renewal, multi-wallet |
| `test/scenarios/UseCase_PrivateFund.t.sol` | Multi-topic, accreditation, provider management |
| `test/scenarios/UseCase_STO.t.sol` | Multi-country, holder limits, compliance enforcement |
| `test/unit/EASClaimVerifier.t.sol` | Verification correctness at unit level |
| `test/unit/NegativeParity.t.sol` | Failure paths: revoked, expired, wrong schema, untrusted |
| `test/gas/GasBenchmark.t.sol` | Gas cost measurement for all operations |

---

## Documentation

| Document | Description |
|----------|-------------|
| [`docs/integration-guide.md`](docs/integration-guide.md) | Step-by-step integration for token issuers |
| [`docs/architecture.md`](docs/architecture.md) | Contract design and component relationships |
| [`schemas/schema-definitions.md`](schemas/schema-definitions.md) | EAS schema specs, field definitions, encoding |
| [`schemas/schema-governance.md`](schemas/schema-governance.md) | How schemas are proposed, reviewed, and versioned |
| [`research/gap-analysis.md`](research/gap-analysis.md) | ONCHAINID vs EAS: detailed capability comparison |
| [`research/claim-topic-analysis.md`](research/claim-topic-analysis.md) | ERC-3643 claim topics in production, mapping to EAS |
| [`research/minimal-identity-structure.md`](research/minimal-identity-structure.md) | How `isVerified()` works and what Shibui replaces |
| [`diagrams/`](diagrams/) | Mermaid source files — render at [mermaid.live](https://mermaid.live) |

---

## Standards Alignment

Shibui is composed entirely of existing open standards:

- **[ERC-3643 / T-REX](https://github.com/TokenySolutions/T-REX)** — token compliance standard, kept intact
- **[EAS](https://attest.org)** — attestation protocol, deployed on 15+ chains, used by Coinbase, Base, Optimism, Gitcoin Passport
- **[ERC-7943](https://eips.ethereum.org/EIPS/eip-7943)** — interface pattern for identity abstraction (future compatibility)
- **W3C DID / Verifiable Credentials** — identity portability (roadmap)

No proprietary protocols. No vendor lock-in. No EEA token.

---

## Who This Is For

**Token issuers** who want compliance flexibility — accept investor credentials from multiple KYC providers without changing your token contract.

**KYC providers and identity services** who want their attestations to be portable across any ERC-3643 token that trusts them.

**Regulators and observers** who want an auditable, standards-based compliance layer that is readable on-chain.

**Developers** building on ERC-3643 who need an identity backend that is not tied to a single vendor.

---

## Governance

Shibui is maintained by the [Enterprise Ethereum Alliance](https://entethalliance.org) — a membership organization with no token, no equity stake in adoption, and no revenue from usage.

Schema governance runs through an EEA working group open to member organizations, token issuers, KYC providers, and regulators (observer status). Core schemas follow a 90-day standardization track. Extension schemas follow a lighter community track.

---

## Related Resources

- [EAS Documentation](https://docs.attest.org)
- [ERC-3643 Specification](https://github.com/TokenySolutions/T-REX)
- [Enterprise Ethereum Alliance](https://entethalliance.org)
- [EEA Working Group — RWA & Tokenization](https://entethalliance.org/working-groups)

---

## License

[MIT](LICENSE)

---

*Built by the EEA.*
