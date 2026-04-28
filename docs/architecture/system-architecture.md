# Shibui System Architecture

> **Start Here:** For a comprehensive explanation of how ERC-3643 identity works, what EAS brings, and how Shibui connects them, see [Identity Architecture Explained](identity-architecture-explained.md). This document is the technical component reference.

## Overview

Shibui enables ERC-3643 security tokens to accept Ethereum Attestation Service (EAS) attestations as an investor-eligibility backend. It is a verifier layer that integrates with ERC-3643 identity and claim-topic infrastructure while keeping runtime semantics explicit: role-based administration, policy-aware verification, and identity resolution through `EASIdentityProxy`.

## Component inventory

### Core Shibui contracts

| Contract | Role | Dependencies |
|----------|------|--------------|
| `EASClaimVerifier` | Core verification logic for investor eligibility | IEAS, IEASTrustedIssuersAdapter, IEASIdentityProxy, IClaimTopicsRegistry, ITopicPolicy |
| `EASTrustedIssuersAdapter` | Trusted-attester registry keyed by claim topic | IEAS for Schema-2 authorization checks |
| `EASIdentityProxy` | Wallet-to-identity binding for multi-wallet support | AccessControl |
| `TrustedIssuerResolver` | Gates Schema-2 Issuer Authorization attestations | EAS resolver interface |
| `EASClaimVerifierIdentityWrapper` | Path B read-compat shim for legacy integrations | EASClaimVerifier |

### External dependencies

| Contract/System | Source | Role |
|-----------------|--------|------|
| `EAS.sol` | ethereum-attestation-service/eas-contracts | Attestation storage and revocation |
| `SchemaRegistry.sol` | ethereum-attestation-service/eas-contracts | Schema registration |
| `ClaimTopicsRegistry` | ERC-3643 T-REX | Defines required claim topics |
| `IdentityRegistry` | ERC-3643 T-REX | Entry point for compliance verification |
| `Token` | ERC-3643 T-REX | Security token contract |

## Architecture diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           ERC-3643 Token Layer                             │
│  Token ──▶ Compliance Module ──▶ IdentityRegistry.isVerified()             │
└───────────────────────────────────────┬─────────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           Shibui Verifier Layer                            │
│  EASClaimVerifier                                                           │
│    ├─ EASIdentityProxy           (wallet → identity)                       │
│    ├─ ClaimTopicsRegistry        (required topics)                         │
│    ├─ EASTrustedIssuersAdapter   (trusted attesters per topic)             │
│    ├─ topic → schema mapping                                              │
│    └─ topic → policy mapping                                               │
└───────────────────────────────────────┬─────────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              EAS Protocol Layer                            │
│  EAS.sol stores attestations and revocation state                          │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Integration paths

### Path A: Pluggable verifier (recommended)

**When to use:** new ERC-3643 deployments or integrations where the Identity Registry can delegate verification to Shibui.

Canonical behavior:
- when a Shibui verifier is configured, `IdentityRegistry.isVerified()` delegates to `EASClaimVerifier.isVerified()`
- when no verifier is configured, the default ERC-3643 / ONCHAINID path remains in place

```solidity
function isVerified(address userAddress) external view returns (bool) {
    if (address(easClaimVerifier) != address(0)) {
        return easClaimVerifier.isVerified(userAddress);
    }

    return _verifyOnchainId(userAddress);
}
```

**Advantages**
- clean separation of concerns
- explicit verifier selection
- policy-aware Shibui verification

### Path B: Identity wrapper (read-compat shim)

**When to use:** existing ERC-3643 deployments that cannot change the Identity Registry and need a compatibility layer.

`EASClaimVerifierIdentityWrapper` is a read-compat shim, not the preferred production path for new deployments.

**Trade-offs**
- more complex than Path A
- per-identity deployment overhead
- compatibility-oriented rather than native integration

## Roles and trust boundaries

### Administrative roles

| Role | Canonical responsibility |
|------|--------------------------|
| `DEFAULT_ADMIN_ROLE` | Administrative control over role assignment and privileged configuration surfaces |
| `OPERATOR_ROLE` | Day-to-day verifier and trusted-attester registry operations |
| `AGENT_ROLE` | Wallet-to-identity binding in `EASIdentityProxy` |

### Contract authority map

| Contract | Canonical authority model |
|----------|---------------------------|
| `EASClaimVerifier` | `OPERATOR_ROLE` manages operational configuration |
| `EASTrustedIssuersAdapter` | `DEFAULT_ADMIN_ROLE` manages EAS/schema config; `OPERATOR_ROLE` manages trusted attesters |
| `EASIdentityProxy` | `DEFAULT_ADMIN_ROLE` manages agents; `AGENT_ROLE` manages wallet mappings |

### Attester authority

| Action | Who can do it |
|--------|--------------|
| Create attestation | Trusted attester (or other EAS writer, though only trusted attesters will satisfy verification) |
| Revoke attestation | Original attester |
| Register attestation in verifier | Attester or authorized identity-proxy agent |

## Verification trust model

For a required topic to pass:
1. a topic-schema mapping must exist
2. a topic-policy mapping must exist
3. a trusted attester must be configured for the topic
4. a registered attestation UID must exist for `(identity, topic, attester)`
5. the attestation must exist in EAS
6. the schema must match
7. the attestation must not be revoked
8. the EAS-level expiration must be current
9. the bound `ITopicPolicy.validate(attestation)` predicate must pass

Shibui returns `true` only if every required topic is satisfied.

## Schemas

### Schema 1 — Investor Eligibility

```text
address identity,uint8 kycStatus,uint8 amlStatus,uint8 sanctionsStatus,uint8 sourceOfFundsStatus,uint8 accreditationType,uint16 countryCode,uint64 expirationTimestamp,bytes32 evidenceHash,uint8 verificationMethod
```

### Schema 2 — Issuer Authorization

```text
address issuerAddress,uint256[] authorizedTopics,string issuerName
```

Schema 2 is enforced through `TrustedIssuerResolver` and cited when the adapter executes `addTrustedAttester(attester, topics, authUID)`.

## Data flow summary

### Attestation creation

```
Trusted attester → EAS.attest() → EASClaimVerifier.registerAttestation()
```

### Trusted-attester authorization

```
Authorizer → Schema-2 attestation → addTrustedAttester(attester, topics, authUID)
```

### Verification

```
Token.transfer() → IdentityRegistry.isVerified() → EASClaimVerifier.isVerified()
    → resolve identity
    → load required topics
    → load trusted attesters
    → fetch EAS attestations
    → apply topic policies
```

## Security considerations

### Access control
- configuration is role-gated, not owner-gated
- attestation registration validates schema, recipient, and trusted-attester status
- wallet registration is agent-mediated

### Revocation timing
- EAS revocation is immediate
- Shibui re-validates attestation state on each `isVerified()` read

### Gas profile
- verification iterates by topic and trusted attester
- bounded trusted-attester lists keep runtime predictable
