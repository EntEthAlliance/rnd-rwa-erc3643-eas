# EAS-to-ERC-3643 Identity Bridge

A bridge that enables ERC-3643 security tokens to accept EAS (Ethereum Attestation Service) attestations as proof of investor eligibility.

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
