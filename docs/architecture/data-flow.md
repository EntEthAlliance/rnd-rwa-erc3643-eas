# Shibui Data Flow

## Overview

This document describes the current Shibui runtime flow. Roles, schema strings, and verification semantics follow the deployed contract design.

## Operation 1: Register wallet-to-identity mapping

### Purpose
Link a wallet address to an identity address so attestations issued to the identity are recognized for linked wallets.

### Participants
- **AGENT_ROLE holder**: registers the mapping
- **EASIdentityProxy**: stores wallet → identity mappings

### Flow

```
AGENT_ROLE holder
        │
        │ registerWallet(wallet, identity)
        ▼
┌─────────────────────────────┐
│     EASIdentityProxy        │
│                             │
│  1. Require AGENT_ROLE      │
│  2. Reject zero addresses   │
│  3. Reject conflicting      │
│     wallet registration     │
│  4. Store mapping:          │
│     _walletToIdentity[wallet] = identity
│     _identityWallets[identity].push(wallet)
│  5. Emit WalletRegistered   │
└─────────────────────────────┘
```

### Storage writes
- `_walletToIdentity[wallet]` = identity address
- `_identityWallets[identity]` += wallet
- `_walletIndex[wallet]` = array index

### Events emitted
- `WalletRegistered(wallet, identity)`

---

## Operation 2: Issue Investor Eligibility attestation

### Purpose
A trusted attester creates a Shibui-compatible Investor Eligibility attestation for an investor identity.

### Participants
- **Trusted attester**: issues the EAS attestation
- **EAS.sol**: stores the attestation
- **EASClaimVerifier**: registers the attestation for topic-based lookup

### Canonical schema payload

```text
address identity,uint8 kycStatus,uint8 amlStatus,uint8 sanctionsStatus,uint8 sourceOfFundsStatus,uint8 accreditationType,uint16 countryCode,uint64 expirationTimestamp,bytes32 evidenceHash,uint8 verificationMethod
```

### Flow

```
Trusted attester
        │
        │ 1. Encode Investor Eligibility payload
        │ 2. EAS.attest(AttestationRequest{schema, data})
        ▼
┌─────────────────────────────┐
│         EAS.sol             │
│                             │
│  1. Validate schema exists  │
│  2. Generate UID            │
│  3. Store attestation       │
│  4. Emit Attested           │
└──────────────┬──────────────┘
               │
               │ attestationUID
               ▼
┌─────────────────────────────┐
│     EASClaimVerifier        │
│                             │
│  registerAttestation(       │
│    identity,                │
│    claimTopic,              │
│    attestationUID           │
│  )                          │
│                             │
│  1. Fetch attestation       │
│  2. Validate schema match   │
│  3. Validate recipient      │
│  4. Validate trusted attester
│  5. Require caller =        │
│     attester OR             │
│     identity-proxy agent    │
│  6. Store UID by            │
│     identity/topic/attester │
│  7. Emit AttestationRegistered
└─────────────────────────────┘
```

### Storage writes
**EAS.sol**
- `_attestations[uid]` = Attestation struct

**EASClaimVerifier**
- `_registeredAttestations[identity][topic][attester]` = uid

### Events emitted
- EAS: `Attested(recipient, attester, uid, schemaUID)`
- EASClaimVerifier: `AttestationRegistered(identity, topic, attester, uid)`

---

## Operation 3: Authorize a trusted attester

### Purpose
Add or update a trusted attester for one or more claim topics using a live Schema-2 authorization attestation.

### Participants
- **Authorizer**: issues Schema-2 Issuer Authorization attestation
- **EASTrustedIssuersAdapter operator**: executes adapter update
- **TrustedIssuerResolver**: gates Schema-2 writes
- **EASTrustedIssuersAdapter**: stores trusted-attester/topic relationships

### Flow

```
Authorizer
        │
        │ 1. Issue Schema-2 EAS attestation
        │    issuerAddress, authorizedTopics, issuerName
        ▼
┌─────────────────────────────┐
│    TrustedIssuerResolver    │
│  allows only curated        │
│  authorizers to write       │
└──────────────┬──────────────┘
               │ authUID
               ▼
Operator (OPERATOR_ROLE)
        │
        │ addTrustedAttester(attester, topics, authUID)
        ▼
┌─────────────────────────────┐
│ EASTrustedIssuersAdapter    │
│                             │
│  1. Fetch Schema-2 UID      │
│  2. Validate attestation    │
│     exists / live / schema  │
│  3. Decode authorized topics│
│  4. Verify subset match     │
│  5. Store topic bindings    │
│  6. Emit TrustedAttesterAdded
└─────────────────────────────┘
```

---

## Operation 4: Verify transfer eligibility

### Purpose
Check if an investor is compliant before a token transfer.

### Participants
- **Token**: initiates compliance check
- **IdentityRegistry**: delegates to the configured verifier
- **EASClaimVerifier**: performs Shibui verification
- **EASIdentityProxy**: resolves wallet to identity
- **ClaimTopicsRegistry**: provides required topics
- **EASTrustedIssuersAdapter**: provides trusted attesters
- **EAS.sol**: provides attestation data
- **ITopicPolicy modules**: enforce topic-specific predicates

### Flow

```
Token.transfer(from, to, amount)
        │
        │ canTransfer()
        ▼
┌─────────────────────────────┐
│     IdentityRegistry        │
│  isVerified(userAddress)    │
│  delegates to Shibui when   │
│  verifier is configured     │
└──────────────┬──────────────┘
               ▼
┌─────────────────────────────┐
│     EASClaimVerifier        │
│                             │
│  1. Resolve identity via    │
│     EASIdentityProxy        │
│  2. Load required topics    │
│     from ClaimTopicsRegistry│
│  3. For each topic:         │
│     - load mapped schema UID│
│     - load trusted attesters│
│     - load registered UID   │
│     - fetch EAS attestation │
│     - reject revoked/expired│
│     - require policy.validate(att)
│  4. Return true only if all │
│     required topics pass    │
└─────────────────────────────┘
```

### Storage reads
1. `EASIdentityProxy._walletToIdentity[wallet]`
2. `ClaimTopicsRegistry._claimTopics`
3. `EASClaimVerifier._topicToSchema[topic]`
4. `EASClaimVerifier._topicToPolicy[topic]`
5. `EASTrustedIssuersAdapter._claimTopicToAttesters[topic]`
6. `EASClaimVerifier._registeredAttestations[identity][topic][attester]`
7. `EAS._attestations[uid]`

### Events emitted
None (view function)

---

## Operation 5: Revoke attestation

### Purpose
A trusted attester invalidates a previously issued attestation.

### Participants
- **Trusted attester**: initiates revocation
- **EAS.sol**: updates attestation state

### Flow

```
Trusted attester
        │
        │ revoke(RevocationRequest{schema, uid})
        ▼
┌─────────────────────────────┐
│         EAS.sol             │
│  1. Fetch attestation       │
│  2. Validate caller is      │
│     original attester       │
│  3. Validate revocable flag │
│  4. Set revocationTime      │
│  5. Emit Revoked            │
└─────────────────────────────┘
```

### Effect on verification
- the next `isVerified()` call sees `revocationTime != 0`
- that attestation no longer satisfies its topic
