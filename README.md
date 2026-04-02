# EAS-ERC3643: Open Identity Infrastructure for Security Tokens

A modular, open-source identity layer for ERC-3643 security tokens that makes compliance verification pluggable — so token issuers aren't locked into a single identity vendor.

## Why This Exists

### The Challenge

[ERC-3643](https://github.com/ERC-3643/ERC-3643) is the leading standard for regulated security tokens on Ethereum. It defines a comprehensive framework for tokenized securities that enforces transfer restrictions based on investor eligibility.

For identity verification, ERC-3643 implementations typically rely on [ONCHAINID](https://github.com/onchain-id/solidity) (ERC-734/735). While ONCHAINID contracts are open source, the **practical tooling ecosystem is vendor-specific**. Token issuers face:

- **Vendor lock-in:** Limited choice in KYC providers who support the ONCHAINID claim model
- **High deployment costs:** Each investor requires their own identity contract (~1.5M gas vs ~218K for an EAS attestation)
- **Tooling dependency:** Integration requires vendor-specific SDKs and infrastructure
- **Inflexible compliance:** Adding new verification types requires protocol-level changes

**The core issue:** ERC-3643 defines **WHAT** compliance checks are needed (KYC, accreditation, jurisdiction), but current implementations prescribe **HOW** those checks must be implemented.

### The Solution: Modular Identity

This project makes the compliance verification layer **pluggable**. Token issuers can choose their identity backend — ONCHAINID, [EAS](https://attest.org), or future systems — without changing the security token standard itself.

By creating an adapter for [Ethereum Attestation Service](https://attest.org) (EAS), we demonstrate that:

- **Standards should define interfaces, not implementations**
- **The compliance layer should be open infrastructure, not proprietary middleware**
- **Token issuers should have choice in identity providers**

This is the same principle that [ERC-7943](https://eips.ethereum.org/EIPS/eip-7943) got right — defining `canSend`/`canReceive`/`canTransfer` interfaces without prescribing the identity infrastructure underneath.

### Why EAS?

EAS is already deployed on 15+ chains with active usage by Coinbase, Optimism, Gitcoin Passport, and Base. It provides:

- **Lower deployment costs:** Attestations vs per-user contracts
- **Broad ecosystem adoption:** Existing credential infrastructure
- **Multi-chain presence:** Same attestation works across networks
- **Open tooling:** No vendor lock-in

### Benefits

| Vendor-locked identity | Modular identity (this project) |
|---|---|
| Limited KYC provider options | Open provider market — choose any EAS-compatible verifier |
| ~1.5M gas per investor identity deployment | ~218K gas per attestation — lower onboarding costs |
| Vendor-specific integration tooling | Standard EAS SDK — same tools across providers |
| Single compliance model | Flexible attestation schemas — adapt to new requirements |
| Per-chain identity deployment | Multi-chain attestations (Ethereum, Base, Arbitrum, Optimism, etc.) |
| Locked into implementation | Works with ERC-3643 AND ERC-7943 standards |

**In short:** This project preserves ERC-3643's regulatory compliance framework while making the identity verification layer open, competitive, and composable.

### Use Case: Tokenized Treasury Fund on Base

A fund manager issues a tokenized US Treasury product on **Base** using ERC-3643. Investors must be KYC-verified and accredited.

**With vendor-locked identity:**
1. Fund deploys ERC-3643 token on Base
2. Each investor must deploy an identity contract (~1.5M gas)
3. Fund's chosen KYC provider issues claims to that identity contract
4. Investor's credentials are siloed to this token
5. Launching on another chain requires repeating the process

**With modular identity (this project):**
1. Fund deploys ERC-3643 token on Base with the EAS adapter
2. Investor already has an EAS attestation from any compatible KYC provider (possibly from another protocol)
3. Fund adds that KYC provider as a **trusted attester** — investor is immediately eligible
4. Same attestation can work on Arbitrum, Optimism, mainnet (if the provider attests there too)
5. Fund can accept attestations from **multiple** KYC providers, giving investors choice

**Result:** Faster investor onboarding, lower compliance costs, better provider competition, and open-source tooling — without sacrificing the regulatory guarantees that make ERC-3643 the standard for security tokens.

## Design Principles

This project embodies a specific philosophy about regulated token infrastructure:

### 1. Open Infrastructure Over Proprietary Middleware
The compliance layer for regulated tokens should be **open infrastructure** that anyone can build on, not proprietary middleware controlled by a single vendor.

### 2. Standards Define Interfaces, Not Implementations
ERC-3643 should specify **what** compliance checks are required (KYC status, accreditation level, jurisdiction). It should **not** mandate how those checks are performed or which identity system provides them.

### 3. Built by a Standards Body, Not a Product Company
This project is maintained by the **Enterprise Ethereum Alliance** — a membership organization focused on standards development, not a vendor with product incentives. The goal is **ecosystem growth**, not vendor lock-in.

### 4. Composability Enables Competition
By making identity verification pluggable, we create a **competitive market** for KYC providers. Token issuers choose based on price, quality, and coverage — not based on which vendor the standard prescribes.

### 5. Preserve What Works, Open What Doesn't
ERC-3643's compliance framework is solid. We keep it intact. What needs to change is the coupling to a specific identity implementation.

## Overview

This project provides smart contracts and tooling to integrate EAS attestations with the ERC-3643 (T-REX) security token standard. It allows token issuers to leverage EAS's flexible attestation infrastructure while maintaining compatibility with existing ERC-3643 compliance frameworks.

### Key Features

- **Dual verification support**: Accept both ONCHAINID claims and EAS attestations
- **Multi-wallet identity**: Link multiple wallets to a single identity
- **Flexible schema mapping**: Map ERC-3643 claim topics to EAS schemas
- **Trusted attester management**: Control which KYC providers can issue valid attestations
- **Zero-modification integration**: Drop-in wrapper for existing deployments (Path B)

## Architecture

```
Token Transfer Request
        │
        ▼
┌─────────────────┐
│ Identity        │
│ Registry        │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ EASClaimVerifier│ ◄── Core verification logic
└────────┬────────┘
         │
    ┌────┴────┐
    ▼         ▼
┌───────┐  ┌──────────────────────┐
│ EAS   │  │EASTrustedIssuersAdapter│
└───────┘  └──────────────────────┘
```

### Contracts

| Contract | Description |
|----------|-------------|
| `EASClaimVerifier` | Core verification logic - checks EAS attestations against required topics |
| `EASTrustedIssuersAdapter` | Manages which attesters are trusted for which claim topics |
| `EASIdentityProxy` | Maps wallet addresses to identity addresses for multi-wallet support |
| `EASClaimVerifierIdentityWrapper` | IIdentity-compatible wrapper for zero-modification integration |

## Basic Implementation Example

This shows the minimal steps to deploy the bridge, configure a KYC provider, and verify an investor — end to end.

### 1. Deploy the bridge contracts

```solidity
// Deploy the three core contracts
EASTrustedIssuersAdapter adapter = new EASTrustedIssuersAdapter(tokenIssuer);
EASIdentityProxy identityProxy = new EASIdentityProxy(tokenIssuer);
EASClaimVerifier verifier = new EASClaimVerifier(tokenIssuer);
```

### 2. Configure the verifier

```solidity
// Point the verifier at EAS and its dependencies
verifier.setEASAddress(0xC2679fBD37d54388Ce493F1DB75320D236e1815e); // EAS on Sepolia
verifier.setTrustedIssuersAdapter(address(adapter));
verifier.setIdentityProxy(address(identityProxy));
verifier.setClaimTopicsRegistry(address(existingRegistry)); // your ERC-3643 registry

// Map ERC-3643 claim topics to EAS schemas
// Topic 1 = KYC, Topic 7 = Accreditation
verifier.setTopicSchemaMapping(1, kycSchemaUID);
verifier.setTopicSchemaMapping(7, accreditationSchemaUID);
```

### 3. Add a trusted KYC provider

```solidity
// Trust a KYC provider (e.g., a licensed verifier already issuing EAS attestations)
uint256[] memory topics = new uint256[](2);
topics[0] = 1; // KYC
topics[1] = 7; // Accreditation
adapter.addTrustedAttester(kycProviderAddress, topics);
```

### 4. Register an investor's attestation

```solidity
// An investor already has an EAS attestation from the trusted KYC provider.
// Anyone can register it (the contract validates it's real and from a trusted source).
verifier.registerAttestation(
    investorIdentity,  // investor's identity address
    1,                 // claim topic (KYC)
    attestationUID     // the EAS attestation UID
);
```

### 5. Verify investor eligibility

```solidity
// The Identity Registry calls this during token transfers.
// Returns true if the investor has valid attestations for ALL required topics.
bool eligible = verifier.isVerified(investorWallet);

// That's it. The investor can now receive and trade the security token.
```

### What happens under the hood

When `isVerified(investorWallet)` is called:

1. **Resolve identity** — maps the wallet to an identity address (supports multi-wallet)
2. **Get required topics** — reads from the ERC-3643 Claim Topics Registry (e.g., KYC + Accreditation)
3. **Check each topic** — for each required topic, looks up the registered EAS attestation
4. **Validate attestation** — confirms it exists, matches the expected schema, is from a trusted attester, hasn't been revoked, and hasn't expired
5. **Return result** — `true` only if every required topic has a valid attestation

The token transfer proceeds normally if `true`. No changes to the ERC-3643 token contract itself.

> **Full pilot script:** See [`script/SetupPilot.s.sol`](script/SetupPilot.s.sol) for a complete deployment with 5 test investors.

## Quickstart

### Prerequisites

- [Foundry](https://getfoundry.sh/) installed
- Git

### Installation

```bash
# Clone the repository
git clone https://github.com/your-org/eas-erc3643-bridge
cd eas-erc3643-bridge

# Install dependencies
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

# Run with verbosity
forge test -vvv

# Run specific test
forge test --match-test test_isVerified_withValidAttestation

# Run coverage
forge coverage
```

### Deploy

```bash
# Set environment variables
export PRIVATE_KEY=<your-private-key>
export OWNER_ADDRESS=<owner-address>  # Optional, defaults to deployer

# Deploy to Sepolia testnet
forge script script/DeployTestnet.s.sol:DeployTestnet --rpc-url $SEPOLIA_RPC_URL --broadcast

# Deploy to mainnet (requires multi-sig)
export MULTISIG_ADDRESS=<gnosis-safe-address>
export CLAIM_TOPICS_REGISTRY=<existing-registry-address>
forge script script/DeployMainnet.s.sol:DeployMainnet --rpc-url $MAINNET_RPC_URL --broadcast --verify
```

## Documentation

### Core Documentation

- [Integration Guide](docs/integration-guide.md) - Step-by-step integration instructions
- [Gas Benchmarks](docs/gas-benchmarks.md) - Gas cost analysis for bridge operations

### Architecture

- [System Architecture](docs/architecture/system-architecture.md) - Component overview and design
- [Contract Interaction Diagrams](docs/architecture/contract-interaction-diagrams.md) - UML sequence diagrams
- [Data Flow](docs/architecture/data-flow.md) - How data moves through the system

### Schemas

- [Schema Definitions](docs/schemas/schema-definitions.md) - EAS schema specifications
- [Schema Governance](docs/schemas/schema-governance.md) - Schema versioning and updates

### Research

- [Gap Analysis](docs/research/gap-analysis.md) - ONCHAINID vs EAS comparison
- [Claim Topic Analysis](docs/research/claim-topic-analysis.md) - ERC-3643 claim topic mapping
- [Minimal Identity Structure](docs/research/minimal-identity-structure.md) - Identity design decisions

### Diagrams

Located in `diagrams/`. Render with any Mermaid viewer ([mermaid.live](https://mermaid.live), GitHub, VS Code extension).

**Context & Strategy:**
- [`current-erc3643-identity.mmd`](diagrams/current-erc3643-identity.mmd) — How ERC-3643 identity works today (ONCHAINID flow + pain points)
- [`bridge-before-after.mmd`](diagrams/bridge-before-after.mmd) — Before vs after: closed system → open attestation layer
- [`multi-chain-reuse.mmd`](diagrams/multi-chain-reuse.mmd) — One KYC → attestations reused across 4 chains and multiple tokens
- [`stakeholder-interactions.mmd`](diagrams/stakeholder-interactions.mmd) — Who does what: issuer, KYC provider, investor, compliance officer

**Technical Architecture:**
- [`architecture-overview.mmd`](diagrams/architecture-overview.mmd) — Bridge contract architecture and component relationships
- [`transfer-verification-flow.mmd`](diagrams/transfer-verification-flow.mmd) — Token transfer verification sequence (full call flow)
- [`dual-mode-verification.mmd`](diagrams/dual-mode-verification.mmd) — Path A (pluggable verifier) vs Path B (identity wrapper)
- [`revocation-flow.mmd`](diagrams/revocation-flow.mmd) — Real-time revocation: AML flag → attestation revoked → transfer blocked
- [`attestation-lifecycle.mmd`](diagrams/attestation-lifecycle.mmd) — Attestation state machine (created → registered → verified → revoked/expired)
- [`wallet-identity-mapping.mmd`](diagrams/wallet-identity-mapping.mmd) — Multi-wallet identity relationships via EASIdentityProxy

## Who Is This For?

### Token Issuers

> "I'm launching a tokenized fund on Base. I need investors to be KYC-verified and accredited before they can hold tokens — but I don't want to lock into a single identity provider."

**What you do:** Deploy the bridge alongside your ERC-3643 token. Configure which claim topics are required (KYC, accreditation, country). Approve one or more KYC providers as trusted attesters. Your token's compliance checks now work with any EAS attestation from those providers.

### KYC / Identity Providers

> "We verify investor identities for multiple token issuers. We want to issue credentials once and have them accepted across all ERC-3643 tokens — not re-verify the same investor for each issuer."

**What you do:** Issue EAS attestations for investors you've verified. Any ERC-3643 token using the bridge can accept your attestations. One verification, many tokens — across Ethereum, Base, Arbitrum, and Optimism.

### Compliance Officers

> "I need to revoke an investor's access immediately when they fail ongoing AML checks — and I need it to take effect across every token they hold."

**What you do:** Revoke the EAS attestation. Every bridge-connected token that relied on that attestation will immediately block the investor from trading. Real-time, automated, on-chain compliance enforcement.

### Investors

> "I did KYC once for a DeFi protocol. Now I want to invest in a tokenized security — do I really need to go through KYC again?"

**What happens:** If your KYC provider issued an EAS attestation and the token issuer trusts that provider, you're already eligible. No new identity deployment, no re-verification. Your attestation carries across tokens and chains.

### Standards Bodies & Working Groups

> "We're defining compliance requirements for tokenized assets. We need a reference implementation that demonstrates how identity verification can be modular and vendor-neutral."

**What this provides:** A working example of **interface-based compliance** where the standard defines verification requirements without prescribing implementation. Use this as a template for future standards work or as a proof-of-concept for modular regulatory infrastructure.

## Integration Paths

### Path A: Pluggable Verifier (Recommended)

For new deployments or when you can modify the Identity Registry:

1. Deploy bridge contracts
2. Configure `EASClaimVerifier` with EAS address, adapter, and registry
3. Set topic-to-schema mappings
4. Add trusted attesters
5. Modify Identity Registry to call `verifier.isVerified()`

### Path B: Identity Wrapper (Zero-Modification)

For existing deployments where you cannot modify the Identity Registry:

1. Deploy `EASClaimVerifierIdentityWrapper` for each identity
2. Register wrapper address in `IdentityRegistryStorage`
3. Token uses existing verification flow unchanged

See [Integration Guide](docs/integration-guide.md) for detailed steps.

## Live Demo

Try the interactive demo on Sepolia testnet: **[Demo UI](https://claudyfaucant.github.io/eas-erc3643-bridge-demo/)**

The demo walks you through a complete scenario — deploying contracts, onboarding investors with EAS attestations, verifying eligibility, and revoking access — all on-chain, all in your browser.

## Schema

The bridge uses the following EAS schema for investor eligibility:

```
address identity, uint8 kycStatus, uint8 accreditationType, uint16 countryCode, uint64 expirationTimestamp
```

| Field | Type | Description |
|-------|------|-------------|
| `identity` | address | Identity address this attestation applies to |
| `kycStatus` | uint8 | 0=NOT_VERIFIED, 1=VERIFIED, 2=EXPIRED, 3=REVOKED, 4=PENDING |
| `accreditationType` | uint8 | 0=NONE, 1=RETAIL_QUALIFIED, 2=ACCREDITED, 3=QUALIFIED_PURCHASER, 4=INSTITUTIONAL |
| `countryCode` | uint16 | ISO 3166-1 numeric country code |
| `expirationTimestamp` | uint64 | Unix timestamp when attestation expires |

## Deployment Scripts

| Script | Purpose |
|--------|---------|
| `RegisterSchemas.s.sol` | Register EAS schemas (idempotent) |
| `SetupPilot.s.sol` | Complete pilot deployment with test data |
| `DeployTestnet.s.sol` | Sepolia deployment with test configuration |
| `DeployMainnet.s.sol` | Production deployment with multi-sig ownership |
| `DeployBridge.s.sol` | Basic bridge deployment |
| `ConfigureBridge.s.sol` | Post-deployment configuration |
| `AddTrustedAttester.s.sol` | Add trusted KYC providers |

## Networks

### Supported EAS Networks

| Network | EAS Address |
|---------|-------------|
| Ethereum Mainnet | `0xA1207F3BBa224E2c9c3c6D5aF63D0eb1582Ce587` |
| Sepolia | `0xC2679fBD37d54388Ce493F1DB75320D236e1815e` |
| Base | `0x4200000000000000000000000000000000000021` |
| Base Sepolia | `0x4200000000000000000000000000000000000021` |
| Arbitrum | `0xbD75f629A22Dc1ceD33dDA0b68c546A1c035c458` |
| Optimism | `0x4200000000000000000000000000000000000021` |

## Security

### Considerations

- Only add verified KYC providers as trusted attesters
- Set reasonable expiration times for attestations
- Monitor events for compliance reporting
- Use multi-sig for owner operations in production

### Audits

This codebase has not been audited. Use at your own risk in production environments.

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

MIT License - see [LICENSE](LICENSE) for details.

## References

- **EAS Contracts:** https://github.com/ethereum-attestation-service/eas-contracts
- **ERC-3643 Standard:** https://github.com/ERC-3643/ERC-3643
- **ERC-7943 Proposal:** https://eips.ethereum.org/EIPS/eip-7943
- **EAS Documentation:** https://docs.attest.org
- **Live Demo:** https://claudyfaucant.github.io/eas-erc3643-bridge-demo/

## Acknowledgments

- [ERC-3643 (T-REX)](https://github.com/ERC-3643/ERC-3643) - Security token standard
- [Ethereum Attestation Service](https://attest.org) - Attestation infrastructure
- [ONCHAINID](https://github.com/onchain-id/solidity) - ERC-734/735 identity implementation
