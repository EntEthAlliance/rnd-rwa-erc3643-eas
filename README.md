# EAS-to-ERC-3643 Identity Bridge

A bridge that enables ERC-3643 security tokens to accept EAS (Ethereum Attestation Service) attestations as proof of investor eligibility.

## Why This Exists

### The Problem

Security tokens built on [ERC-3643](https://github.com/TokenySolutions/T-REX) (the leading standard for regulated tokenized assets) rely on [ONCHAINID](https://github.com/onchain-id/solidity) for investor identity verification. ONCHAINID works — but it's a closed system. Every KYC provider, every identity verifier, every compliance check must fit into its specific ERC-734/735 key-and-claim model.

Meanwhile, the broader Ethereum ecosystem has converged on [EAS](https://attest.sh) (Ethereum Attestation Service) as a general-purpose attestation layer. KYC providers, credential issuers, and identity platforms are increasingly issuing attestations through EAS — but none of that infrastructure can talk to ERC-3643 tokens today.

**The result:** tokenized securities live in an identity silo, cut off from the growing ecosystem of onchain attestations.

### Benefits

| Without the bridge | With the bridge |
|---|---|
| Token issuers must use ONCHAINID-compatible KYC providers only | Any EAS-compatible KYC provider works — broader provider market, lower costs |
| Investor onboarding requires deploying an ONCHAINID identity per user | Investors reuse existing EAS attestations they already have from other protocols |
| Compliance verification is single-chain | EAS attestations work across Ethereum, Base, Arbitrum, Optimism — one KYC, many chains |
| Adding a new compliance check means a new ONCHAINID claim type | New checks are just new EAS schemas — flexible, permissionless, no protocol upgrade needed |
| Existing tokens can't adopt new identity infrastructure without redeployment | Zero-modification wrapper (Path B) adds EAS support without touching deployed contracts |

**In short:** EAS turns investor identity from a closed, vendor-locked system into an open, composable layer — while keeping ERC-3643's regulatory compliance framework fully intact.

### Use Case: Tokenized Treasury Fund on Base

A fund manager issues a tokenized US Treasury product on **Base** using ERC-3643. Investors must be KYC-verified and accredited.

**Today (without the bridge):**
1. Fund deploys ERC-3643 token on Base
2. Each investor must create an ONCHAINID identity contract on Base
3. A specific ONCHAINID-compatible KYC provider must issue claims to that identity
4. Investor can only trade this token — their KYC doesn't carry over to other protocols
5. If the fund also launches on Arbitrum, investors repeat the entire process

**With the bridge:**
1. Fund deploys ERC-3643 token on Base with the EAS bridge
2. Investor already has an EAS attestation from a KYC provider (e.g., from onboarding to another DeFi protocol)
3. Fund adds that KYC provider as a **trusted attester** — investor is immediately eligible, no new identity deployment
4. Same attestation works on Arbitrum, Optimism, mainnet — investor is verified everywhere
5. Fund can accept attestations from **multiple** KYC providers simultaneously, giving investors choice

**Result:** Faster investor onboarding, lower compliance costs, multi-chain portability, and no vendor lock-in — without sacrificing the regulatory guarantees that make ERC-3643 the standard for security tokens.

### What This Project Delivers

Smart contracts and tooling that let ERC-3643 tokens accept EAS attestations as valid proof of investor eligibility — alongside or instead of traditional ONCHAINID claims. Drop-in for new deployments, zero-modification wrapper for existing ones.

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

Located in `diagrams/`:
- [`architecture-overview.mmd`](diagrams/architecture-overview.mmd) - High-level system architecture
- [`transfer-verification-flow.mmd`](diagrams/transfer-verification-flow.mmd) - Token transfer verification sequence
- [`dual-mode-verification.mmd`](diagrams/dual-mode-verification.mmd) - Path A vs Path B verification flows
- [`attestation-lifecycle.mmd`](diagrams/attestation-lifecycle.mmd) - Attestation state machine
- [`wallet-identity-mapping.mmd`](diagrams/wallet-identity-mapping.mmd) - Multi-wallet identity relationships

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

## Acknowledgments

- [ERC-3643 (T-REX)](https://github.com/TokenySolutions/T-REX) - Security token standard
- [Ethereum Attestation Service](https://attest.sh) - Attestation infrastructure
- [ONCHAINID](https://github.com/onchain-id/solidity) - ERC-734/735 identity implementation
