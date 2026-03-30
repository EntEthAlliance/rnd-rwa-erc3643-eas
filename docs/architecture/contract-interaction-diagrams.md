# Contract Interaction Diagrams

## Overview

This document describes the contract interactions in the EAS-to-ERC-3643 Identity Bridge. The corresponding Mermaid diagram source files are in the `diagrams/` directory.

## Diagram 1: Architecture Overview

**File:** `diagrams/architecture-overview.mmd`

Shows all contracts and their relationships:
- Token → Identity Registry → EASClaimVerifier → EAS.sol
- Supporting modules: EASTrustedIssuersAdapter, EASIdentityProxy
- Parallel ONCHAINID path for dual-mode context

## Diagram 2: Transfer Verification Flow (EAS Path)

**File:** `diagrams/transfer-verification-flow.mmd`

Sequence diagram showing:
1. User initiates transfer
2. Token calls canTransfer
3. Identity Registry calls isVerified
4. EASClaimVerifier resolves identity
5. Queries EAS for attestations
6. Checks trusted issuers
7. Returns result
8. Transfer approved or rejected

## Diagram 3: Dual Mode Verification

**File:** `diagrams/dual-mode-verification.mmd`

Shows the Identity Registry checking both:
- ONCHAINID path (traditional)
- EAS path (bridge)
- Configurable priority/fallback behavior

## Diagram 4: Attestation Lifecycle

**File:** `diagrams/attestation-lifecycle.mmd`

Flow showing:
1. KYC provider verifies investor offchain
2. KYC provider creates EAS attestation
3. Attestation becomes live
4. Investor can hold/transfer tokens
5. KYC expires or attestation revoked
6. Investor can no longer transfer
7. Re-verification cycle
8. New attestation restores eligibility

## Diagram 5: Wallet-Identity Mapping

**File:** `diagrams/wallet-identity-mapping.mmd`

Shows:
- Multiple wallets mapping to one identity
- EASClaimVerifier resolution process
- Attestations made to identity recognized for all wallets

## Contract Interaction Matrix

| Caller | Target | Function | Purpose |
|--------|--------|----------|---------|
| Token | IdentityRegistry | isVerified() | Check compliance |
| IdentityRegistry | EASClaimVerifier | isVerified() | EAS path verification |
| EASClaimVerifier | EASIdentityProxy | getIdentity() | Resolve wallet to identity |
| EASClaimVerifier | ClaimTopicsRegistry | getClaimTopics() | Get required topics |
| EASClaimVerifier | EASTrustedIssuersAdapter | getTrustedAttestersForTopic() | Get trusted attesters |
| EASClaimVerifier | IEAS | getAttestation() | Fetch attestation data |
| KYCProvider | IEAS | attest() | Create attestation |
| Anyone | EASClaimVerifier | registerAttestation() | Register attestation for lookup |
| KYCProvider | IEAS | revoke() | Revoke attestation |
| Owner | EASTrustedIssuersAdapter | addTrustedAttester() | Add KYC provider |
| Agent | EASIdentityProxy | registerWallet() | Link wallet to identity |

## Event Emissions

### EASClaimVerifier Events

| Event | When Emitted |
|-------|--------------|
| TopicSchemaMappingSet | Topic-to-schema mapping configured |
| EASAddressSet | EAS contract address updated |
| TrustedIssuersAdapterSet | Adapter address updated |
| IdentityProxySet | Identity proxy address updated |
| ClaimTopicsRegistrySet | Topics registry address updated |
| AttestationRegistered | Attestation UID registered for lookup |

### EASTrustedIssuersAdapter Events

| Event | When Emitted |
|-------|--------------|
| TrustedAttesterAdded | New attester authorized |
| TrustedAttesterRemoved | Attester removed |
| AttesterTopicsUpdated | Attester's topics changed |

### EASIdentityProxy Events

| Event | When Emitted |
|-------|--------------|
| WalletRegistered | Wallet linked to identity |
| WalletRemoved | Wallet unlinked |
| AgentAdded | New agent authorized |
| AgentRemoved | Agent removed |

## State Transitions

### Attestation States

```
[Not Created] ──attest()──▶ [Active]
                               │
                               ├──revoke()──▶ [Revoked]
                               │
                               └──time passes──▶ [Expired]
```

### Investor Verification States

```
[Unverified] ──register attestation──▶ [Verified]
      ▲                                     │
      │                                     │
      └──attestation revoked/expired────────┘
```

### Wallet-Identity Link States

```
[Unlinked] ──registerWallet()──▶ [Linked]
     ▲                              │
     │                              │
     └────removeWallet()────────────┘
```
