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

## Installation

```bash
# Clone the repository
git clone https://github.com/your-org/eas-erc3643-bridge
cd eas-erc3643-bridge

# Install dependencies
forge install
```

## Quick Start

### Build

```bash
forge build
```

### Test

```bash
forge test
```

### Deploy

```bash
# Set environment variables
export PRIVATE_KEY=<your-private-key>
export OWNER_ADDRESS=<owner-address>  # Optional, defaults to deployer

# Deploy to Base Sepolia
forge script script/DeployBridge.s.sol:DeployBridge --rpc-url base-sepolia --broadcast

# Deploy with custom EAS address
EAS_ADDRESS=0x... forge script script/DeployBridge.s.sol:DeployBridge --rpc-url <rpc-url> --broadcast
```

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

## Documentation

- [Integration Guide](docs/integration/integration-guide.md) - Step-by-step integration instructions
- [Schema Definitions](docs/schemas/schema-definitions.md) - EAS schema specifications
- [Schema Governance](docs/schemas/schema-governance.md) - Schema versioning and updates
- [System Architecture](docs/architecture/system-architecture.md) - Component overview
- [Gap Analysis](docs/research/gap-analysis.md) - ONCHAINID vs EAS comparison

### Architecture Diagrams

Located in `diagrams/`:
- `architecture-overview.mmd` - High-level system architecture
- `transfer-verification-flow.mmd` - Token transfer verification sequence
- `dual-mode-verification.mmd` - Path A vs Path B verification flows
- `attestation-lifecycle.mmd` - Attestation state machine
- `wallet-identity-mapping.mmd` - Multi-wallet identity relationships

## Testing

The project includes comprehensive tests:

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

Test categories:
- **Unit tests** (`test/unit/`): Individual contract function testing
- **Integration tests** (`test/integration/`): Multi-contract interaction flows
- **Scenario tests** (`test/scenarios/`): Real-world use case simulations (STO, investor lifecycle)

## Networks

### Deployed EAS Addresses

| Network | EAS Address |
|---------|-------------|
| Ethereum Mainnet | `0xA1207F3BBa224E2c9c3c6D5aF63D0eb1582Ce587` |
| Sepolia | `0xC2679fBD37d54388Ce493F1DB75320D236e1815e` |
| Base | `0x4200000000000000000000000000000000000021` |
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
