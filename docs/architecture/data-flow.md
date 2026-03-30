# Data Flow Documentation

## Overview

This document describes the data flow for each major operation in the EAS-to-ERC-3643 Identity Bridge.

## Operation 1: Register Identity (Link Wallet to Identity)

### Purpose
Link a wallet address to an identity address so attestations made to the identity are recognized for all linked wallets.

### Participants
- **Agent/Identity Owner**: Initiates registration
- **EASIdentityProxy**: Stores mapping

### Flow

```
Agent/Identity Owner
        │
        │ registerWallet(wallet, identity)
        ▼
┌─────────────────────────────┐
│     EASIdentityProxy        │
│                             │
│  1. Validate authorization  │
│     - msg.sender == owner   │
│     - OR msg.sender is agent│
│     - OR msg.sender == identity
│                             │
│  2. Check not already       │
│     registered to different │
│     identity                │
│                             │
│  3. Store mapping:          │
│     _walletToIdentity[wallet] = identity
│     _identityWallets[identity].push(wallet)
│                             │
│  4. Emit WalletRegistered   │
└─────────────────────────────┘
```

### Storage Writes
- `_walletToIdentity[wallet]` = identity address
- `_identityWallets[identity]` += wallet
- `_walletIndex[wallet]` = array index

### Events Emitted
- `WalletRegistered(wallet, identity)`

---

## Operation 2: Issue Attestation

### Purpose
KYC provider creates a compliance attestation for an investor.

### Participants
- **KYC Provider (Attester)**: Creates attestation
- **EAS.sol**: Stores attestation
- **EASClaimVerifier**: Registers attestation for lookup

### Flow

```
KYC Provider
        │
        │ 1. Encode attestation data
        │    abi.encode(identity, kycStatus, accreditationType, countryCode, expirationTimestamp)
        │
        │ 2. attest(AttestationRequest{schema, data})
        ▼
┌─────────────────────────────┐
│         EAS.sol             │
│                             │
│  1. Validate schema exists  │
│  2. Generate unique UID     │
│  3. Store attestation:      │
│     - uid, schema, time     │
│     - recipient, attester   │
│     - revocable, data       │
│  4. Call resolver (if any)  │
│  5. Emit Attested event     │
│  6. Return UID              │
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
│  5. Store in registry:      │
│     _registeredAttestations │
│     [identity][topic][attester] = uid
│  6. Emit AttestationRegistered
└─────────────────────────────┘
```

### Storage Writes
**EAS.sol:**
- `_attestations[uid]` = Attestation struct

**EASClaimVerifier:**
- `_registeredAttestations[identity][topic][attester]` = uid

### Events Emitted
- EAS: `Attested(recipient, attester, uid, schemaUID)`
- EASClaimVerifier: `AttestationRegistered(identity, topic, attester, uid)`

---

## Operation 3: Verify Transfer

### Purpose
Check if an investor is compliant before a token transfer.

### Participants
- **Token**: Initiates compliance check
- **IdentityRegistry**: Routes to verifier
- **EASClaimVerifier**: Performs EAS verification
- **EASIdentityProxy**: Resolves wallet to identity
- **ClaimTopicsRegistry**: Provides required topics
- **EASTrustedIssuersAdapter**: Provides trusted attesters
- **EAS.sol**: Provides attestation data

### Flow

```
Token.transfer(from, to, amount)
        │
        │ canTransfer()
        ▼
┌─────────────────────────────┐
│     IdentityRegistry        │
│                             │
│  isVerified(userAddress)    │
│        │                    │
│        │ (Path A)           │
└────────┼────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│     EASClaimVerifier        │
│                             │
│  isVerified(userAddress)    │
│                             │
│  Step 1: Resolve Identity   │
│  ┌─────────────────────┐    │
│  │ EASIdentityProxy    │    │
│  │ getIdentity(wallet) │    │
│  │ Returns: identity   │    │
│  └─────────────────────┘    │
│                             │
│  Step 2: Get Required Topics│
│  ┌─────────────────────┐    │
│  │ ClaimTopicsRegistry │    │
│  │ getClaimTopics()    │    │
│  │ Returns: [1, 7]     │    │
│  └─────────────────────┘    │
│                             │
│  Step 3: For each topic     │
│  ┌─────────────────────┐    │
│  │ Get schema UID      │    │
│  │ _topicToSchema[topic]│   │
│  └─────────────────────┘    │
│  ┌─────────────────────┐    │
│  │ TrustedIssuersAdapter│   │
│  │ getTrustedAttesters │    │
│  │ ForTopic(topic)     │    │
│  │ Returns: [attester1]│    │
│  └─────────────────────┘    │
│                             │
│  Step 4: Check attestations │
│  For each trusted attester: │
│  ┌─────────────────────┐    │
│  │ Get registered UID  │    │
│  │ _registeredAttestat │    │
│  │ ions[id][topic][att]│    │
│  └─────────────────────┘    │
│  ┌─────────────────────┐    │
│  │ EAS.getAttestation  │    │
│  │ (attestationUID)    │    │
│  │ Returns: Attestation│    │
│  └─────────────────────┘    │
│                             │
│  Step 5: Validate           │
│  - uid != 0 (exists)        │
│  - schema matches           │
│  - revocationTime == 0      │
│  - expirationTime check     │
│  - data expiration check    │
│                             │
│  Returns: true/false        │
└─────────────────────────────┘
```

### Storage Reads
1. `EASIdentityProxy._walletToIdentity[wallet]`
2. `ClaimTopicsRegistry._claimTopics`
3. `EASClaimVerifier._topicToSchema[topic]`
4. `EASTrustedIssuersAdapter._claimTopicToAttesters[topic]`
5. `EASClaimVerifier._registeredAttestations[identity][topic][attester]`
6. `EAS._attestations[uid]`

### Events Emitted
None (view function)

---

## Operation 4: Revoke Attestation

### Purpose
KYC provider invalidates a previously issued attestation.

### Participants
- **KYC Provider (Attester)**: Initiates revocation
- **EAS.sol**: Updates attestation state

### Flow

```
KYC Provider (original attester)
        │
        │ revoke(RevocationRequest{schema, uid})
        ▼
┌─────────────────────────────┐
│         EAS.sol             │
│                             │
│  1. Fetch attestation       │
│  2. Validate caller is      │
│     original attester       │
│  3. Validate revocable flag │
│  4. Set revocationTime =    │
│     block.timestamp         │
│  5. Call resolver.revoke()  │
│  6. Emit Revoked event      │
└─────────────────────────────┘
```

### Storage Writes
- `_attestations[uid].revocationTime` = block.timestamp

### Events Emitted
- `Revoked(recipient, attester, uid, schemaUID)`

### Effect on Verification
- Next `isVerified()` call will see `revocationTime != 0`
- Attestation considered invalid
- Verification will fail for that topic (unless another valid attestation exists)

---

## Operation 5: Link Wallet (Multi-Wallet Support)

### Purpose
Add another wallet to an existing identity.

### Flow

```
Identity Owner (or Agent)
        │
        │ registerWallet(newWallet, identity)
        ▼
┌─────────────────────────────┐
│     EASIdentityProxy        │
│                             │
│  1. Validate authorization  │
│  2. Store mapping           │
│  3. Emit event              │
└─────────────────────────────┘
        │
        ▼
    Next verification:
        │
        │ EASClaimVerifier.isVerified(newWallet)
        ▼
┌─────────────────────────────┐
│     EASIdentityProxy        │
│                             │
│  getIdentity(newWallet)     │
│  Returns: identity          │
│                             │
│  Attestations for identity  │
│  now apply to newWallet     │
└─────────────────────────────┘
```

---

## Operation 6: Add Trusted Attester

### Purpose
Authorize a new KYC provider to issue attestations.

### Participants
- **Token Issuer (Owner)**: Authorizes attester
- **EASTrustedIssuersAdapter**: Stores trust relationship

### Flow

```
Token Issuer (Owner)
        │
        │ addTrustedAttester(attester, [1, 7])
        │ (KYC and Accreditation topics)
        ▼
┌─────────────────────────────┐
│  EASTrustedIssuersAdapter   │
│                             │
│  1. Validate not already    │
│     trusted                 │
│  2. Store in arrays:        │
│     _trustedAttesters.push  │
│     _attesterClaimTopics    │
│     _claimTopicToAttesters  │
│  3. Set trust flags:        │
│     _isTrusted[attester]    │
│     _attesterTrustedForTopic│
│  4. Emit TrustedAttesterAdded
└─────────────────────────────┘
```

### Storage Writes
- `_trustedAttesters.push(attester)`
- `_attesterClaimTopics[attester]` = [1, 7]
- `_claimTopicToAttesters[1].push(attester)`
- `_claimTopicToAttesters[7].push(attester)`
- `_isTrusted[attester]` = true
- `_attesterTrustedForTopic[attester][1]` = true
- `_attesterTrustedForTopic[attester][7]` = true

### Events Emitted
- `TrustedAttesterAdded(attester, [1, 7])`

---

## Gas Costs Summary

| Operation | Estimated Gas | Notes |
|-----------|---------------|-------|
| registerWallet | ~50,000 | New storage slots |
| attest | ~80,000-150,000 | Depends on data size |
| registerAttestation | ~60,000 | Validates and stores |
| isVerified (1 topic, 1 attester) | ~30,000 | Multiple reads |
| isVerified (3 topics, 2 attesters each) | ~100,000 | Worst case |
| revoke | ~30,000 | Single storage update |
| addTrustedAttester | ~80,000 | Multiple arrays |
| removeTrustedAttester | ~50,000 | Array manipulation |
