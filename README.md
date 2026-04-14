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

## How Verification Works

When a token transfer is attempted, Shibui intercepts the `isVerified(wallet)` call and resolves it against EAS attestations instead of ONCHAINID contracts. Here is the full sequence:

```
User
  │  transfer(to, amount)
  ▼
ERC-3643 Token
  │  isVerified(to)
  ▼
EASClaimVerifier                              [Shibui]
  │  getIdentity(wallet) ──────────────────▶ EASIdentityProxy
  │  identityAddress ◀────────────────────── EASIdentityProxy
  │
  │  getClaimTopics() ─────────────────────▶ ClaimTopicsRegistry
  │  [topic1, topic2, ...] ◀─────────────── ClaimTopicsRegistry
  │
  │  for each topic:
  │    getTrustedAttesters(topic) ─────────▶ EASTrustedIssuersAdapter
  │    [attester1, ...] ◀──────────────────── EASTrustedIssuersAdapter
  │
  │    getAttestation(uid) ────────────────▶ EAS.sol (on-chain)
  │    Attestation{schema, revoked, expiry} ◀ EAS.sol
  │
  │    validate: not revoked, not expired, schema match, attester trusted
  │
  ├── all topics pass → true
  └── any topic fails → false
  ▼
ERC-3643 Token
  ├── true  → transfer executes
  └── false → transfer reverts
```

The full Mermaid source for this diagram is in [`diagrams/transfer-verification-flow.mmd`](diagrams/transfer-verification-flow.mmd). Render it at [mermaid.live](https://mermaid.live) or directly in GitHub.

Nothing changes in the ERC-3643 token contract. The compliance interface is identical. Only the backend is different.

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

## EAS Schemas

Shibui uses three EAS schemas, registered on-chain via [`script/RegisterSchemas.s.sol`](script/RegisterSchemas.s.sol). These are the data structures that KYC providers and token issuers write to and read from.

### 1. Investor eligibility

```solidity
address identity,
uint8   kycStatus,
uint8   accreditationType,
uint16  countryCode,
uint64  expirationTimestamp
```

The core compliance attestation. A KYC provider attests this to an investor's identity address. It encodes whether the investor has passed KYC (`kycStatus`), what type of accreditation they hold (`accreditationType`), their jurisdiction (`countryCode`), and when the attestation expires.

This is the schema most tokens will require for claim topic 1 (KYC). It is revocable — the attesting provider can invalidate it at any time, which immediately blocks the investor's ability to transfer tokens.

### 2. Issuer authorization

```solidity
address   issuerAddress,
uint256[] authorizedTopics,
string    issuerName
```

Authorizes an attestation provider (a KYC service, a custodian, a regulator) to issue attestations for specific claim topics. A token issuer registers an attester using this schema, scoping exactly which topics that attester is trusted for.

This schema is what makes the system composable: a bank trusted for KYC (topic 1) is not automatically trusted for accreditation (topic 2). Trust is granular and explicit.

### 3. Wallet-identity link

```solidity
address walletAddress,
address identityAddress,
uint64  linkedTimestamp
```

Maps a wallet address to an identity address. A single investor can have multiple wallets — hardware wallets, cold wallets, exchange wallets — all linked to one identity. An attestation made to the identity applies to all linked wallets.

This is what enables multi-wallet support without re-running KYC per wallet.

---

### Schema registration

Schemas are registered idempotently. Running the script multiple times is safe — UIDs are deterministic based on the schema string, resolver, and revocable flag.

```bash
forge script script/RegisterSchemas.s.sol:RegisterSchemas \
  --rpc-url $RPC_URL \
  --broadcast
```

Known EAS Schema Registry addresses (auto-detected by chain ID):

| Network | Registry address |
|---|---|
| Ethereum mainnet | `0xA7b39296258348C78294F95B872b282326A97BDF` |
| Sepolia | `0x0a7E2Ff54e76B8E6659aedc9103FB21c038050D0` |
| Base / Optimism | `0x4200000000000000000000000000000000000020` |
| Arbitrum | `0xA310da9c5B885E7fb3fbA9D66E9Ba6Df512b78eB` |

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

### Register schemas

```bash
forge script script/RegisterSchemas.s.sol:RegisterSchemas \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast
```

Save the emitted UIDs — you'll need them to configure `EASClaimVerifier`.

### Run a full pilot (5 seeded investors)

```bash
forge script script/SetupPilot.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast
```

---

## Key Flows

### Investor onboarding

```
1. Token issuer deploys Shibui contracts
2. Registers schemas (RegisterSchemas.s.sol)
3. Configures required claim topics (e.g., topic 1 = KYC, topic 2 = accreditation)
4. Adds trusted attesters via IssuerAuthorization schema
5. KYC provider creates EAS attestation using InvestorEligibility schema
6. Issuer registers attestation UID → verifier.registerAttestation(wallet, topic, uid)
7. verifier.isVerified(wallet) → true ✓  → investor can receive/transfer tokens
```

### Revocation (real-time compliance)

```
1. KYC provider revokes the EAS attestation on-chain
2. verifier.isVerified(wallet) → false ✗  → transfers blocked immediately
3. Re-attest when investor re-qualifies
4. verifier.isVerified(wallet) → true ✓  → access restored
```

### Multi-wallet identity

```
1. Investor registers multiple wallets using the WalletIdentityLink schema
2. Attestation is issued to the identity address, not per-wallet
3. All linked wallets inherit verification status automatically
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

## Diagrams

All diagrams are Mermaid source files in [`diagrams/`](diagrams/). Render at [mermaid.live](https://mermaid.live) or directly in GitHub.

| File | What It Shows |
|------|---------------|
| [`transfer-verification-flow.mmd`](diagrams/transfer-verification-flow.mmd) | Full sequence: user → token → Shibui → EAS → result |
| [`architecture-overview.mmd`](diagrams/architecture-overview.mmd) | Contract relationships |
| [`bridge-before-after.mmd`](diagrams/bridge-before-after.mmd) | Before (ONCHAINID) vs after (Shibui) |
| [`attestation-lifecycle.mmd`](diagrams/attestation-lifecycle.mmd) | Attestation states: issued → valid → revoked → renewed |
| [`dual-mode-verification.mmd`](diagrams/dual-mode-verification.mmd) | Direct wallet mode vs identity proxy mode |
| [`multi-chain-reuse.mmd`](diagrams/multi-chain-reuse.mmd) | One KYC attestation used across multiple chains |
| [`revocation-flow.mmd`](diagrams/revocation-flow.mmd) | Real-time revocation sequence |
| [`stakeholder-interactions.mmd`](diagrams/stakeholder-interactions.mmd) | Who does what: issuer, provider, investor, compliance |

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

*Built by the EEA Working Group on Real-World Assets and Tokenization.*
