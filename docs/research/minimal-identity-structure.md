# Minimal Identity Structure Analysis

## Overview

This document traces the `isVerified()` call in the ERC-3643 Identity Registry contract to understand the minimal requirements that an identity layer must provide for security token transfers. We then map each step to its EAS equivalent.

## ERC-3643 Identity Verification Call Path

### Entry Point: `isVerified(address _userAddress)`

Located in `IdentityRegistry.sol`, this function is the core verification check called during token transfers.

### Step-by-Step Analysis

#### Step 1: Identity Address Lookup

```solidity
if (address(identity(_userAddress)) == address(0)) {return false;}
```

**What happens:**
- The registry fetches the ONCHAINID address associated with the wallet from `IIdentityRegistryStorage`
- If no identity is registered, verification fails immediately
- Storage read: `_tokenIdentityStorage.storedIdentity(_userAddress)`

**EAS Equivalent:**
- EAS attestations are made to a recipient address directly
- For multi-wallet support, we need `EASIdentityProxy` to map wallet → identity address
- If no mapping exists, use wallet address directly as the identity
- If identity mapping returns zero address, verification fails

#### Step 2: Fetch Required Claim Topics

```solidity
uint256[] memory requiredClaimTopics = _tokenTopicsRegistry.getClaimTopics();
if (requiredClaimTopics.length == 0) {
    return true;
}
```

**What happens:**
- Retrieves the list of required claim topic IDs from the Claim Topics Registry
- If no topics are required, the user is automatically verified
- External call: `IClaimTopicsRegistry.getClaimTopics()`

**EAS Equivalent:**
- Claim topics are uint256 identifiers (e.g., 1 = KYC, 2 = AML, 7 = accredited investor)
- EAS uses bytes32 schema UIDs instead
- Bridge must maintain a mapping: `claimTopic (uint256) → schemaUID (bytes32)`
- Same logic: if no topics required, return true

#### Step 3: Fetch Trusted Issuers for Each Topic

```solidity
IClaimIssuer[] memory trustedIssuers =
    _tokenIssuersRegistry.getTrustedIssuersForClaimTopic(requiredClaimTopics[claimTopic]);

if (trustedIssuers.length == 0) {return false;}
```

**What happens:**
- For each required topic, get the list of trusted issuer addresses
- If no trusted issuers exist for a required topic, verification fails
- External call: `ITrustedIssuersRegistry.getTrustedIssuersForClaimTopic(uint256)`

**EAS Equivalent:**
- Trusted issuers → EAS attester addresses
- `EASTrustedIssuersAdapter` maintains: `attester address → authorized topics[]`
- Query: `isAttesterTrusted(address attester, uint256 claimTopic) → bool`
- Same logic: if no trusted attesters for a topic, fail

#### Step 4: Generate Claim IDs

```solidity
bytes32[] memory claimIds = new bytes32[](trustedIssuers.length);
for (uint256 i = 0; i < trustedIssuers.length; i++) {
    claimIds[i] = keccak256(abi.encode(trustedIssuers[i], requiredClaimTopics[claimTopic]));
}
```

**What happens:**
- Claim IDs in ONCHAINID are deterministic: `keccak256(abi.encode(issuer, topic))`
- This allows direct lookup of claims on the Identity contract

**EAS Equivalent:**
- EAS attestations have unique UIDs but are not deterministically addressable by (attester, schema)
- Must query EAS for attestations where:
  - `recipient` = identity address
  - `schema` = mapped schema UID
  - `attester` = one of the trusted attesters
- Use EAS indexing or store attestation UIDs separately

#### Step 5: Retrieve and Validate Claims

```solidity
(foundClaimTopic, scheme, issuer, sig, data, ) = identity(_userAddress).getClaim(claimIds[j]);

if (foundClaimTopic == requiredClaimTopics[claimTopic]) {
    try IClaimIssuer(issuer).isClaimValid(identity(_userAddress),
        requiredClaimTopics[claimTopic], sig, data) returns(bool _validity) {
        // ...
    }
}
```

**What happens:**
- Retrieves claim data from the ONCHAINID contract (ERC-735 compatible)
- Claim data includes: topic, scheme, issuer, signature, data
- Calls `isClaimValid()` on the issuer contract to verify cryptographic signature
- The issuer can perform additional checks (revocation, etc.)

**EAS Equivalent:**
- Query EAS directly: `IEAS.getAttestation(bytes32 uid)`
- Attestation struct contains: uid, schema, time, expirationTime, revocationTime, recipient, attester, data
- No external signature verification needed - EAS handles this at attestation creation
- Revocation is native: `revocationTime > 0` means revoked
- Additional checks on `expirationTime` field

#### Step 6: Revocation and Validity Checks

**ONCHAINID approach:**
- Issuer contract's `isClaimValid()` checks revocation
- Revocation is managed by the issuer, not the Identity contract

**EAS approach:**
- Revocation is native: `attestation.revocationTime > 0` (if revocable)
- Expiration is native: `attestation.expirationTime != 0 && attestation.expirationTime < block.timestamp`
- Additional expiration can be encoded in attestation data (expirationTimestamp field)

## Mapping Summary

| ONCHAINID Component | EAS Equivalent | Notes |
|---------------------|----------------|-------|
| Identity contract address | EASIdentityProxy mapping or wallet address directly | Multi-wallet support via proxy |
| Claim topic (uint256) | EAS schema UID (bytes32) | Configurable mapping in EASClaimVerifier |
| Trusted issuer (IClaimIssuer) | EAS attester address | EASTrustedIssuersAdapter manages authorization |
| Claim signature validation | EAS native verification | Handled at attestation creation time |
| Claim revocation check | `attestation.revocationTime > 0` | Native EAS feature |
| Claim data | `attestation.data` (ABI encoded) | Schema-defined structure |
| getClaim() | EAS.getAttestation() | Different query pattern - need UID or indexing |

## Key Architectural Decisions

### 1. Attestation Discovery

**Challenge:** ONCHAINID uses deterministic claim IDs, but EAS attestations are not directly addressable by (recipient, schema, attester).

**Solutions:**
1. Store attestation UIDs in a separate index contract
2. Use events + off-chain indexing (requires trusted relayer)
3. Use schema resolver to track attestations
4. Rely on EAS Indexer contract for on-chain queries

**Recommendation:** Use EAS Indexer or maintain our own index in EASClaimVerifier for gas efficiency.

### 2. Multi-Topic Verification

**ONCHAINID:** Iterates through topics, for each topic iterates through trusted issuers, checks claims.

**EAS Bridge:** Same pattern, but:
- Map topic → schemaUID
- Get trusted attesters for topic from EASTrustedIssuersAdapter
- Query attestations for (recipient=identity, schema=schemaUID, attester∈trustedAttesters)
- Validate not revoked, not expired

### 3. Expiration Handling

**Two-tier expiration:**
1. EAS-level: `expirationTime` field on attestation (set at creation, immutable)
2. Data-level: `expirationTimestamp` field in attestation data schema

**Verification logic:**
```solidity
// EAS-level expiration
if (attestation.expirationTime != 0 && attestation.expirationTime < block.timestamp) {
    // Attestation expired
    return false;
}

// Data-level expiration
InvestorEligibility memory data = abi.decode(attestation.data, (InvestorEligibility));
if (data.expirationTimestamp != 0 && data.expirationTimestamp < block.timestamp) {
    // Data expired
    return false;
}
```

### 4. Trust Model Comparison

| Aspect | ONCHAINID | EAS |
|--------|-----------|-----|
| Who can create claims | Anyone, but validation required | Anyone can attest |
| Validation timing | At verification time (isClaimValid) | At attestation time (resolver) or verification time |
| Revocation authority | Issuer (via isClaimValid) | Attester only |
| Trust registry | TrustedIssuersRegistry | EASTrustedIssuersAdapter |

## EAS Bridge Verification Flow

```
isVerified(walletAddress)
    │
    ├─► getIdentity(walletAddress) via EASIdentityProxy
    │   └─► Returns identity address (or wallet if no mapping)
    │
    ├─► getClaimTopics() from ClaimTopicsRegistry (existing ERC-3643)
    │   └─► Returns uint256[] requiredTopics
    │
    └─► For each topic:
            │
            ├─► getSchemaUID(topic) from EASClaimVerifier
            │   └─► Returns bytes32 schemaUID
            │
            ├─► getTrustedAttestersForTopic(topic) from EASTrustedIssuersAdapter
            │   └─► Returns address[] trustedAttesters
            │
            └─► For each trustedAttester:
                    │
                    ├─► Query EAS for attestations matching:
                    │   - recipient = identity
                    │   - schema = schemaUID
                    │   - attester = trustedAttester
                    │
                    └─► For matching attestation:
                            ├─► Check revocationTime == 0
                            ├─► Check expirationTime (EAS-level)
                            ├─► Decode data, check expirationTimestamp
                            └─► If valid: topic satisfied, continue
```

## Storage Reads and External Calls

**Per verification call:**
1. `EASIdentityProxy.getIdentity()` - 1 SLOAD (mapping lookup)
2. `ClaimTopicsRegistry.getClaimTopics()` - External call, returns array
3. Per topic:
   - `EASClaimVerifier.getSchemaUID()` - 1 SLOAD
   - `EASTrustedIssuersAdapter.getTrustedAttestersForTopic()` - External call, returns array
   - `EAS.getAttestation()` - External call per attestation check

**Gas optimization considerations:**
- Cache topic-to-schema mappings
- Minimize attestation queries by maintaining an index
- Consider batching attestation checks

## Conclusion

The EAS bridge must provide:
1. **Identity resolution** - `EASIdentityProxy` maps wallets to identity addresses
2. **Topic-to-schema mapping** - `EASClaimVerifier` maintains uint256 → bytes32 mapping
3. **Trusted issuer management** - `EASTrustedIssuersAdapter` tracks authorized attesters per topic
4. **Attestation verification** - Query EAS, check revocation, check expiration, decode data

The verification logic mirrors ONCHAINID but uses EAS primitives:
- Claims → Attestations
- Claim signatures → EAS native verification
- Claim revocation → EAS revocationTime
- Trusted issuers → Trusted attesters
