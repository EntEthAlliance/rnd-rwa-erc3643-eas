# Gap Analysis: ONCHAINID vs EAS

## Overview

This document compares ONCHAINID capabilities versus EAS capabilities across key dimensions and identifies how the bridge addresses each gap.

## Comparison Summary

| Dimension | ONCHAINID | EAS | Gap Status |
|-----------|-----------|-----|------------|
| Key Management | ERC-734 keys | None | Out of scope |
| Multi-wallet Identity | Native | Requires proxy | Solved by bridge |
| Claim/Attestation Structure | ERC-735 claims | EAS attestations | Solved by bridge |
| Revocation | Issuer-controlled | Attester-controlled | Compatible |
| Cross-chain | CREATE2 deterministic | Chain-specific | Deferred to V2 |
| Off-chain attestations | Not native | Native support | Deferred to V2 |
| Trusted Issuer Registry | ITrustedIssuersRegistry | None native | Solved by bridge |
| Claim Topic Registry | IClaimTopicsRegistry | Schema registry | Mapping provided |

---

## Dimension 1: Key Management

### ONCHAINID Approach

ONCHAINID inherits ERC-734 key management:
- **Management Keys (1):** Can add/remove keys, change the identity
- **Action Keys (2):** Can execute actions on behalf of the identity
- **Claim Signer Keys (3):** Can sign claims
- **Encryption Keys (4):** For encrypted data

```solidity
// ERC-734 key structure
struct Key {
    uint256[] purposes; // Array of key purposes
    uint256 keyType; // ECDSA, RSA, etc.
    bytes32 key; // Actual key data
}
```

Key operations:
- `addKey()` - Add a key to the identity
- `removeKey()` - Remove a key
- `getKey()` - Retrieve key info
- `keyHasPurpose()` - Check if key has specific purpose

### EAS Approach

EAS has **no key management**. Attestations are signed by EOAs or contracts directly.

### Gap Analysis

**Question:** Does the bridge need key management?

**Answer:** No. Key management is orthogonal to compliance verification.

**Reasoning:**
1. Key management in ONCHAINID is about **wallet control and recovery**, not compliance verification
2. The `isVerified()` function does not check keys - it checks claims
3. ERC-3643 tokens do not require the identity to have specific key purposes
4. The bridge's job is to answer "is this investor compliant?" not "who controls this identity?"

**Status:** Out of scope - key management is a separate concern from compliance verification.

**V2 Consideration:** If wallet linking in EASIdentityProxy requires attestation-based authorization, we could use an EAS attestation with a resolver that checks the attester is the identity owner.

---

## Dimension 2: Multi-Wallet Identity

### ONCHAINID Approach

The Identity Registry Storage maintains a mapping:

```solidity
// In IIdentityRegistryStorage
mapping(address => IIdentity) internal _identities;
mapping(address => uint16) internal _investorCountries;

function addIdentityToStorage(address _userAddress, IIdentity _identity, uint16 _country) external;
function storedIdentity(address _userAddress) external view returns (IIdentity);
```

One investor can have multiple wallets registered to the same Identity contract:
- Wallet A → Identity 0x123
- Wallet B → Identity 0x123
- Wallet C → Identity 0x123

Claims are held by the Identity contract, so all wallets share the same compliance status.

### EAS Approach

EAS attestations are made to a single `recipient` address. There is no native multi-wallet support.

### Bridge Solution: EASIdentityProxy

```solidity
// Wallet → Identity mapping
mapping(address => address) internal _walletToIdentity;
// Identity → Wallet[] reverse mapping for enumeration
mapping(address => address[]) internal _identityWallets;

function registerWallet(address wallet, address identity) external;
function getIdentity(address wallet) external view returns (address);
function getWallets(address identity) external view returns (address[] memory);
```

**Verification flow:**
1. `EASClaimVerifier.isVerified(wallet)` called
2. Resolve: `identity = EASIdentityProxy.getIdentity(wallet)`
3. If no mapping: `identity = wallet` (direct attestation)
4. Query EAS for attestations where `recipient = identity`
5. Return verification result

**Status:** Solved by `EASIdentityProxy` contract.

**Access Control:** Registration by:
- Token agent (`onlyAgent` role from ERC-3643)
- Or by the identity address itself (self-registration)

**V2 Enhancement:** Use EAS attestations (Schema 3: Wallet-Identity Link) for permissionless, attestation-based linking:

```solidity
// Schema: address walletAddress, address identityAddress, uint64 linkedTimestamp
// Attester must be identityAddress or hold management key equivalent
```

---

## Dimension 3: Cross-Chain Portability

> **Cross-chain scope.** Earlier README copy described "one KYC, all chains" as a benefit. That is **not** a property of the current implementation. EAS attestations are per-chain; an investor verified on chain A must be separately attested on chain B. Multi-chain attestation portability is on the V2 roadmap. Integrators should plan for per-chain attestation and, if needed, their own mirroring infrastructure.


### ONCHAINID Approach

ONCHAINID uses CREATE2 via IdFactory for deterministic addresses:

```solidity
// In IdFactory
function createIdentity(address _wallet, string memory _salt)
    external returns (address)
{
    bytes32 salt = keccak256(abi.encodePacked(_wallet, _salt));
    address identity = Create2.deploy(0, salt, type(Identity).creationCode);
    return identity;
}
```

Benefits:
- Same identity address across all chains
- Claims signed on one chain work on another
- Issuer can pre-sign claims for deployment on any chain

### EAS Approach

EAS attestations are **chain-specific**:
- Attestations exist only on the chain where they were created
- Attestation UIDs are unique per chain
- No native cross-chain mechanism

### Gap Analysis

**Challenge:** An investor verified on Ethereum would need separate attestations on Polygon, Arbitrum, etc.

**Options:**

| Option | Pros | Cons |
|--------|------|------|
| Separate attestations per chain | Simple, clear state | Duplicated verification effort |
| Cross-chain messaging (LayerZero, Axelar) | Single source of truth | Complexity, latency, cost |
| Off-chain attestations with on-chain proof | Gas efficient | Trust assumptions |
| Attestation mirroring via resolver | Automated sync | Additional infrastructure |

**V1 Decision:** Defer to V2. Require separate attestations per chain.

**Rationale:**
1. Cross-chain security is complex - don't rush it
2. Most initial deployments will be single-chain
3. KYC providers already have multi-chain workflows
4. Can add cross-chain later without changing V1 contracts

**V2 Roadmap:**
- Implement cross-chain attestation mirroring
- Use LayerZero or similar for attestation bridging
- Maintain canonical chain with sync to others

**Status:** Deferred to V2.

---

## Dimension 4: Off-Chain Attestations

### ONCHAINID Approach

ONCHAINID claims are **on-chain only**:
- Claims stored in the Identity contract
- Full claim data visible on-chain
- Privacy concerns for sensitive data

### EAS Approach

EAS supports both on-chain and off-chain attestations:

**On-chain attestations:**
- Stored in EAS contract
- Publicly visible
- Verifiable by anyone

**Off-chain attestations:**
- Signed by attester but not stored on-chain
- Published to IPFS, Ceramic, or private storage
- Verified via signature recovery
- Can be brought on-chain when needed

```typescript
// EAS SDK off-chain attestation
const offchainAttestation = await eas.signOffchainAttestation({
    schema: schemaUID,
    recipient: investorAddress,
    data: encodedData,
    expirationTime: expirationTime,
    revocable: true
});
// Returns: { uid, schema, recipient, data, signature, ... }
```

### Gap Analysis

**Privacy benefit:** Off-chain attestations keep sensitive KYC data private until needed.

**Challenge:** How to verify off-chain attestations during token transfer (on-chain)?

**Options:**

| Option | Pros | Cons |
|--------|------|------|
| Bring on-chain at first transfer | Simple | Loses privacy after first transfer |
| ZK proof of attestation | Full privacy | Complex, gas expensive |
| Trusted relayer | Gas efficient | Trust assumption |
| Timestamped commitment | Proof of existence | Still reveals data when verified |

**V1 Decision:** Defer to V2. Focus on on-chain attestations.

**Rationale:**
1. On-chain attestations match ONCHAINID's current model
2. Privacy-preserving verification is a separate research track
3. Simpler to audit and verify
4. Off-chain support can be added as an enhancement

**V2 Roadmap:**
- Implement off-chain attestation verification via `attestByDelegation`
- Add relayer infrastructure for off-chain to on-chain translation
- Explore ZK circuits for private verification

**Status:** Deferred to V2.

---

## Dimension 5: Claim/Attestation Structure

### ONCHAINID Claims (ERC-735)

```solidity
struct Claim {
    uint256 topic;      // Claim type (1=KYC, 7=accreditation, etc.)
    uint256 scheme;     // Signature scheme (1=ECDSA, 2=RSA, etc.)
    address issuer;     // Claim issuer address
    bytes signature;    // Cryptographic signature
    bytes data;         // Arbitrary claim data
    string uri;         // Optional URI for additional data
}
```

Validation:
- Signature verified by calling `IClaimIssuer.isClaimValid()`
- Issuer can implement custom validation logic
- Revocation checked in `isClaimValid()`

### EAS Attestations

```solidity
struct Attestation {
    bytes32 uid;           // Unique identifier
    bytes32 schema;        // Schema UID
    uint64 time;           // Creation timestamp
    uint64 expirationTime; // Expiration (0 = never)
    uint64 revocationTime; // Revocation time (0 = not revoked)
    bytes32 refUID;        // Reference to another attestation
    address recipient;     // Who the attestation is about
    address attester;      // Who made the attestation
    bool revocable;        // Can be revoked
    bytes data;            // Schema-encoded data
}
```

Validation:
- Signature verified at attestation creation
- Revocation: `revocationTime > 0`
- Expiration: `expirationTime != 0 && expirationTime < block.timestamp`

### Bridge Mapping

| ONCHAINID | EAS | Notes |
|-----------|-----|-------|
| topic | schema | uint256 → bytes32 mapping needed |
| scheme | N/A | EAS uses ECDSA natively |
| issuer | attester | Direct mapping |
| signature | N/A | Verified at attestation time |
| data | data | ABI-encoded in both |
| uri | N/A | Can be included in data |
| getClaim(claimId) | getAttestation(uid) | Different addressing |

**Status:** Solved by `EASClaimVerifier` with topic-to-schema mapping.

---

## Dimension 6: Revocation

### ONCHAINID Approach

Revocation is controlled by the claim issuer via `IClaimIssuer.isClaimValid()`:

```solidity
interface IClaimIssuer {
    function isClaimValid(
        IIdentity _identity,
        uint256 _claimTopic,
        bytes memory _sig,
        bytes memory _data
    ) external view returns (bool);

    function revokeClaim(bytes32 _claimId) external;
    function isClaimRevoked(bytes memory _sig) external view returns (bool);
}
```

The issuer has full control over claim validity and can:
- Revoke claims
- Implement time-based expiration
- Add custom validation rules

### EAS Approach

Revocation is **attester-controlled** and immediate:

```solidity
// In IEAS
function revoke(RevocationRequest calldata request) external;

// Checking revocation
Attestation memory att = eas.getAttestation(uid);
bool isRevoked = att.revocationTime > 0;
```

Key differences:
- Only the original attester can revoke
- Revocation is immediate and on-chain
- No custom revocation logic - binary revoked/not-revoked

### Compatibility Analysis

| Aspect | ONCHAINID | EAS | Compatible? |
|--------|-----------|-----|-------------|
| Who can revoke | Issuer | Attester | Yes (same entity) |
| Revocation timing | Via isClaimValid | Immediate on-chain | Yes |
| Custom revocation logic | Yes | No | Limited |
| Revocation check | External call | Storage read | EAS simpler |

**Limitation:** EAS doesn't support custom revocation logic. If an issuer needs complex revocation rules (e.g., revoke after N transfers), this must be handled off-chain before calling EAS.revoke().

**Status:** Compatible. Minor limitation on custom revocation logic is acceptable.

---

## Dimension 7: Trusted Issuer Registry

### ONCHAINID Approach

`ITrustedIssuersRegistry` manages which claim issuers are trusted for which topics:

```solidity
interface ITrustedIssuersRegistry {
    function addTrustedIssuer(IClaimIssuer _trustedIssuer, uint256[] calldata _claimTopics) external;
    function removeTrustedIssuer(IClaimIssuer _trustedIssuer) external;
    function updateIssuerClaimTopics(IClaimIssuer _trustedIssuer, uint256[] calldata _claimTopics) external;
    function getTrustedIssuers() external view returns (IClaimIssuer[] memory);
    function getTrustedIssuersForClaimTopic(uint256 claimTopic) external view returns (IClaimIssuer[] memory);
    function isTrustedIssuer(address _issuer) external view returns (bool);
    function getTrustedIssuerClaimTopics(IClaimIssuer _trustedIssuer) external view returns (uint256[] memory);
}
```

### EAS Approach

EAS has no native trusted issuer concept. Anyone can create attestations.

### Bridge Solution: EASTrustedIssuersAdapter

```solidity
interface IEASTrustedIssuersAdapter {
    function addTrustedAttester(address attester, uint256[] calldata claimTopics) external;
    function removeTrustedAttester(address attester) external;
    function updateAttesterTopics(address attester, uint256[] calldata claimTopics) external;
    function isAttesterTrusted(address attester, uint256 claimTopic) external view returns (bool);
    function getTrustedAttestersForTopic(uint256 claimTopic) external view returns (address[] memory);
    function getAttesterTopics(address attester) external view returns (uint256[] memory);
}
```

**Design decisions:**
1. Mirror the `ITrustedIssuersRegistry` interface pattern
2. Use `uint256 claimTopic` not `bytes32 schemaUID` for compatibility
3. Access control via `onlyOwner` or `onlyAgent` (matching ERC-3643 roles)

**Alternative: Resolver-based enforcement**

Instead of checking trusted attesters at verification time, enforce at attestation creation:

```solidity
contract TrustedAttesterResolver is SchemaResolver {
    mapping(address => mapping(uint256 => bool)) public trustedAttesterForTopic;

    function onAttest(Attestation calldata attestation, uint256) internal override returns (bool) {
        // Decode attestation data to get claim topic
        // Check if attester is trusted for that topic
        return trustedAttesterForTopic[attestation.attester][claimTopic];
    }
}
```

**Tradeoff:**

| Approach | Pros | Cons |
|----------|------|------|
| External check (EASTrustedIssuersAdapter) | Flexible, can change trusted attesters | Attestations from untrusted sources exist |
| Resolver enforcement | Only valid attestations created | Less flexible, harder to update |

**V1 Decision:** Use `EASTrustedIssuersAdapter` for external checks. More flexible and matches ONCHAINID pattern.

**Status:** Solved by `EASTrustedIssuersAdapter` contract.

---

## Summary: Gap Resolution

| Gap | Resolution | Implementation |
|-----|------------|----------------|
| Key management | Out of scope | Not needed for compliance verification |
| Multi-wallet identity | EASIdentityProxy | wallet → identity mapping |
| Claim structure | Topic-to-schema mapping | EASClaimVerifier |
| Trusted issuers | EASTrustedIssuersAdapter | Mirrors TrustedIssuersRegistry |
| Cross-chain | Deferred to V2 | Separate attestations per chain |
| Off-chain attestations | Deferred to V2 | On-chain only for V1 |
| Revocation | Native EAS | Compatible, minor limitation |

## V2 Roadmap Summary

1. **Cross-chain attestation bridging** - LayerZero/Axelar integration
2. **Off-chain attestation verification** - Relayer infrastructure
3. **Attestation-based wallet linking** - Schema 3 as identity link
4. **ZK-based private verification** - For sensitive compliance data
5. **Resolver-based trusted issuer enforcement** - Optional strict mode
