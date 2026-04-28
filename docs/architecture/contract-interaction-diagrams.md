# Shibui Contract Interaction Diagrams

## Overview

This document describes the contract interactions in Shibui. The corresponding Mermaid diagram source files are in the `diagrams/` directory.

All diagrams can be rendered with any Mermaid viewer ([mermaid.live](https://mermaid.live), GitHub, VS Code extension).

---

## Context & Strategy Diagrams

These diagrams explain the "why" — the problem space, the before/after comparison, and how different stakeholders interact with the system.

### Current ERC-3643 Identity

**File:** `diagrams/current-erc3643-identity.mmd`

**What it shows:** How ERC-3643 identity verification works today using ONCHAINID. Illustrates the flow from investor through KYC provider to ONCHAINID contract, Identity Registry, and finally token transfer. Highlights the pain points: vendor lock-in, per-user contract deployment, no cross-chain portability.

**When to reference:** When explaining why Shibui exists, or when comparing ONCHAINID to EAS.

### Before/After Comparison

**File:** `diagrams/bridge-before-after.mmd`

**What it shows:** Side-by-side comparison of the identity architecture before (closed ONCHAINID system) and after (open EAS attestation layer). Shows how the bridge opens up the identity layer without changing ERC-3643 fundamentals.

**When to reference:** When explaining the value proposition, or in executive summaries.

### Multi-Chain Reuse

**File:** `diagrams/multi-chain-reuse.mmd`

**What it shows:** How a single KYC verification can result in attestations across multiple chains (Ethereum, Base, Arbitrum, Optimism), enabling an investor to access security tokens on any chain without re-verification.

**When to reference:** When discussing cross-chain strategy or the multi-chain value proposition.

### Stakeholder Interactions

**File:** `diagrams/stakeholder-interactions.mmd`

**What it shows:** The four key stakeholders (token issuer, KYC provider, investor, compliance officer) and their interactions with the bridge. Shows what each stakeholder does, sees, and cares about.

**When to reference:** When explaining the system from different user perspectives, or in user documentation.

### Revocation Flow

**File:** `diagrams/revocation-flow.mmd`

**What it shows:** The real-time revocation process: AML flag triggered → attestation revoked → transfer blocked. Demonstrates how compliance enforcement is immediate and automatic.

**When to reference:** When explaining compliance mechanisms or the revocation process.

---

## Technical Architecture Diagrams

These diagrams show the "how" — contract relationships, data flows, and verification logic.

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
6. Checks trusted attesters
7. Returns result
8. Transfer approved or rejected

## Diagram 3: Dual Mode Verification

**File:** `diagrams/dual-mode-verification.mmd`

Shows the Identity Registry delegating to Shibui when configured while preserving the default ONCHAINID path when no Shibui verifier is set.

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
| Attester or AGENT_ROLE holder | EASClaimVerifier | registerAttestation() | Register attestation for lookup |
| KYCProvider | IEAS | revoke() | Revoke attestation |
| OPERATOR_ROLE holder | EASTrustedIssuersAdapter | addTrustedAttester() | Add trusted attester |
| AGENT_ROLE holder | EASIdentityProxy | registerWallet() | Link wallet to identity |

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
