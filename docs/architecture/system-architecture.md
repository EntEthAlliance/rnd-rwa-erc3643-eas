# System Architecture

## Overview

The EAS-to-ERC-3643 Identity Bridge enables ERC-3643 security tokens to accept Ethereum Attestation Service (EAS) attestations as an alternative identity backend to ONCHAINID. The system is designed as a plug-in adapter that integrates with the existing ERC-3643 infrastructure without requiring modifications to the token contract or compliance modules.

## Component Inventory

### Core Bridge Contracts

| Contract | Role | Dependencies |
|----------|------|--------------|
| `EASClaimVerifier` | Core verification logic - checks if a wallet has valid EAS attestations for all required claim topics | IEAS, IEASTrustedIssuersAdapter, IEASIdentityProxy, IClaimTopicsRegistry |
| `EASTrustedIssuersAdapter` | Manages which EAS attester addresses are trusted for which claim topics | None (standalone) |
| `EASIdentityProxy` | Maps wallet addresses to identity addresses for multi-wallet support | None (standalone) |
| `EASClaimVerifierIdentityWrapper` | Path B wrapper - implements IIdentity interface to work with unmodified Identity Registry | EASClaimVerifier, IEAS, IEASTrustedIssuersAdapter |

### External Dependencies

| Contract/System | Source | Role |
|-----------------|--------|------|
| `EAS.sol` | ethereum-attestation-service/eas-contracts | Core EAS protocol - attestation storage and verification |
| `SchemaRegistry.sol` | ethereum-attestation-service/eas-contracts | EAS schema registration |
| `ClaimTopicsRegistry` | ERC-3643 T-REX | Defines required claim topics for token |
| `IdentityRegistry` | ERC-3643 T-REX | Entry point for compliance verification |
| `Token` | ERC-3643 T-REX | Security token contract |

### Mock Contracts (Testing)

| Contract | Role |
|----------|------|
| `MockEAS` | Simulates EAS contract for testing |
| `MockAttester` | Simulates KYC provider creating attestations |
| `MockClaimTopicsRegistry` | Simulates claim topics registry |

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           ERC-3643 Token Layer                               │
│  ┌─────────────┐      ┌──────────────────┐      ┌───────────────────────┐   │
│  │   Token     │─────▶│  Compliance      │─────▶│  Identity Registry    │   │
│  │  (ERC-20+)  │      │  Module          │      │  isVerified()         │   │
│  └─────────────┘      └──────────────────┘      └───────────┬───────────┘   │
└─────────────────────────────────────────────────────────────┼───────────────┘
                                                              │
                      ┌───────────────────────────────────────┼───────────────┐
                      │                                       │               │
                      │  Path A: Pluggable Verifier          ▼               │
                      │  ┌───────────────────────────────────────────────┐   │
                      │  │              EASClaimVerifier                  │   │
                      │  │  ┌─────────────┐  ┌────────────────────────┐  │   │
                      │  │  │  isVerified │  │ Topic-Schema Mapping   │  │   │
                      │  │  └──────┬──────┘  └────────────────────────┘  │   │
                      │  └─────────┼──────────────────────────────────────┘   │
                      │            │                                          │
                      │  ┌─────────┼──────────────────────────────────────┐   │
                      │  │         │                                      │   │
                      │  │    ┌────▼─────┐    ┌─────────────────────┐    │   │
                      │  │    │  EAS     │    │  Trusted Issuers    │    │   │
                      │  │    │ Identity │    │  Adapter            │    │   │
                      │  │    │  Proxy   │    │                     │    │   │
                      │  │    └──────────┘    └─────────────────────┘    │   │
                      │  │                                                │   │
                      │  │                 EAS Bridge Layer               │   │
                      │  └────────────────────────────────────────────────┘   │
                      │                                                       │
                      └───────────────────────────────────────────────────────┘
                                                │
                      ┌─────────────────────────┼─────────────────────────────┐
                      │                         │                             │
                      │                         ▼                             │
                      │        ┌────────────────────────────────┐            │
                      │        │           EAS.sol              │            │
                      │        │  ┌──────────────────────────┐  │            │
                      │        │  │  Attestation Storage     │  │            │
                      │        │  │  - uid, schema, time     │  │            │
                      │        │  │  - recipient, attester   │  │            │
                      │        │  │  - revocationTime        │  │            │
                      │        │  │  - data                  │  │            │
                      │        │  └──────────────────────────┘  │            │
                      │        └────────────────────────────────┘            │
                      │                                                       │
                      │                 EAS Protocol Layer                    │
                      └───────────────────────────────────────────────────────┘
```

## Integration Paths

### Path A: Pluggable Verifier (Recommended)

The Identity Registry is modified to support pluggable verifiers:

```solidity
// In modified IdentityRegistry
function isVerified(address userAddress) external view returns (bool) {
    // Try ONCHAINID first
    if (_verifyOnchainId(userAddress)) return true;

    // Fall back to EAS
    if (address(easClaimVerifier) != address(0)) {
        return easClaimVerifier.isVerified(userAddress);
    }

    return false;
}
```

**Advantages:**
- Clean separation of concerns
- Easy to add/remove verification methods
- Configurable priority

**Disadvantages:**
- Requires minor Identity Registry modification
- New deployments need modified registry

### Path B: IIdentity Wrapper (Zero-Modification)

Deploy `EASClaimVerifierIdentityWrapper` for each identity. The wrapper implements `IIdentity` interface:

```solidity
// Standard IdentityRegistry calls
identity.getClaim(claimId)  // Wrapper translates to EAS attestation lookup
IClaimIssuer(issuer).isClaimValid(...)  // Wrapper validates attestation
```

**Advantages:**
- Works with existing ERC-3643 contracts
- No contract modifications required
- Drop-in replacement

**Disadvantages:**
- More complex implementation
- Per-identity deployment overhead
- Emulates rather than native integration

## Trust Boundaries

### Owner Authority

| Contract | Owner Can | Owner Cannot |
|----------|-----------|--------------|
| EASClaimVerifier | Set topic-schema mappings, configure adapters | Create/revoke attestations |
| EASTrustedIssuersAdapter | Add/remove trusted attesters | Create attestations |
| EASIdentityProxy | Add agents | Register wallets (without authorization) |

### Agent Authority

| Contract | Agent Can | Agent Cannot |
|----------|-----------|--------------|
| EASIdentityProxy | Register/remove wallets | Add other agents |
| EASTrustedIssuersAdapter | N/A (owner-only) | - |

### Attester Authority

| Action | Who Can Do It |
|--------|--------------|
| Create attestation | Anyone with ETH for gas |
| Revoke attestation | Only original attester |
| Register attestation in verifier | Anyone (validates automatically) |

### Verification Trust Model

For a verification to pass:
1. Attestation must exist in EAS
2. Attester must be in TrustedIssuersAdapter for the topic
3. Attestation must not be revoked
4. Attestation must not be expired

## Upgrade Paths

### Contract Upgrades

The bridge contracts can be deployed as upgradeable proxies (UUPS or Transparent):

```solidity
// Recommended upgrade pattern
contract EASClaimVerifierV2 is EASClaimVerifier, UUPSUpgradeable {
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
```

### Token Issuer Upgrade Process

1. Deploy new implementation contract
2. Test on testnet
3. Execute upgrade via proxy admin
4. No token redeployment needed

### Schema Migration

When schemas evolve:
1. Register new schema
2. Update topic-schema mapping in EASClaimVerifier
3. KYC providers issue attestations with new schema
4. (Optional) Accept both old and new schemas during transition

## Data Flow

### Attestation Creation Flow

```
KYC Provider → EAS.attest() → Attestation stored
                    │
                    ▼
         registerAttestation() → Registered in EASClaimVerifier
```

### Verification Flow

```
Token.transfer() → IdentityRegistry.isVerified()
                          │
                          ▼ (Path A)
              EASClaimVerifier.isVerified()
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
        ▼                 ▼                 ▼
  Resolve Identity   Get Topics    Get Trusted Attesters
        │                 │                 │
        └─────────────────┼─────────────────┘
                          │
                          ▼
              For each topic:
              - Look up registered attestation
              - Query EAS for attestation data
              - Check not revoked, not expired
                          │
                          ▼
              Return true/false
```

## Security Considerations

### Access Control

- All configuration functions are `onlyOwner`
- Attestation registration is permissionless but validates attestation exists
- Wallet registration requires agent or identity authorization

### Revocation Timing

- EAS revocation is immediate
- Cached attestation UIDs are re-validated on each `isVerified()` call
- No stale validity windows

### Front-Running Protection

- Attestation UIDs are deterministic
- Registration validates attestation exists at registration time
- Verification re-validates at check time

### Gas Considerations

- Verification iterates through topics and attesters
- Worst case: O(topics × attesters) EAS reads
- Recommendation: Keep attesters per topic under 10
