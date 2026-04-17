# EAS-to-ERC-3643 Bridge Integration Guide

> **Scope reminder.** Shibui is an **attestation retrieval adapter**, not a full identity layer. Token-side primitives (forced transfer, freeze, recovery) live in the ERC-3643 token contract. See [`docs/architecture/enforcement-boundary.md`](architecture/enforcement-boundary.md).
>
> **Cross-chain.** EAS attestations are **per-chain** today. An investor verified on chain A must be re-attested on chain B; "one KYC, all chains" is on the V2 roadmap and not a property of the current implementation.
>
> **Path B caveats.** `EASClaimVerifierIdentityWrapper` is a **read-compat shim** for legacy ERC-3643 deployments that cannot be modified. It does not run topic policies in `isClaimValid`, returns empty signatures from `getClaim`, and has an unfavourable gas profile. New deployments should use Path A. See the wrapper's NatSpec for the full list of non-features.


## What You'll Achieve

By the end of this guide, your ERC-3643 security token will be able to verify investor eligibility using EAS attestations. Concretely:

- **Token issuers** can accept KYC/accreditation credentials from any EAS-compatible provider — not just ONCHAINID
- **Investors** reuse existing EAS attestations across multiple tokens and chains — one KYC, universal access
- **KYC providers** issue attestations once, accepted everywhere — through an open standard instead of a proprietary system
- **Compliance officers** can revoke access in real-time by revoking an attestation — enforcement is immediate and automated

### Example Scenario

A fund manager launches a tokenized US Treasury product on Base using ERC-3643. Regulation requires investors to be KYC-verified and accredited.

**Without the bridge:** Each investor deploys an ONCHAINID identity contract. A specific ONCHAINID-compatible KYC provider issues claims. If the fund launches on Arbitrum too, investors repeat everything.

**With the bridge:** Investors who already have EAS attestations from a KYC provider are immediately eligible — no new identity contracts, no re-verification. Works across Base, Arbitrum, Ethereum, and Optimism.

## Prerequisites

Before integration, ensure you have:

1. **Deployed EAS infrastructure** — EAS is already live on [Ethereum, Base, Arbitrum, Optimism, and testnets](https://docs.attest.org/docs/quick--start/contracts)
2. **Registered schemas** — Register the required EAS schemas (see [Schema Definitions](schemas/schema-definitions.md))
3. **Deployed bridge contracts** — Deploy the core bridge contracts (see below)
4. **KYC provider setup** — At least one trusted attestation provider issuing EAS attestations

## Integration Paths

### Path A: Pluggable Verifier (Recommended)

> **"We're building a new token and want EAS attestations as our primary identity layer."**

Integrate `EASClaimVerifier` as a verification module called by a modified Identity Registry. This gives you full control and the cleanest integration.

**When to use:**
- New ERC-3643 deployments
- When you can modify the Identity Registry
- When you want native EAS integration

**Steps:**

1. Deploy the bridge contracts
2. Configure `EASClaimVerifier` with required components
3. Modify your Identity Registry to call `EASClaimVerifier.isVerified()`
4. Register trusted attesters

### Path B: Identity Wrapper (Zero-Modification)

> **"We already have an ERC-3643 token in production. We can't redeploy, but we want to start accepting EAS attestations."**

Use `EASClaimVerifierIdentityWrapper` as a drop-in IIdentity replacement. Your existing contracts don't change at all — the wrapper translates EAS attestations into the ONCHAINID interface.

**When to use:**
- Existing ERC-3643 deployments already in production
- When you cannot modify the Identity Registry
- When you need backwards compatibility with ONCHAINID

**Steps:**

1. Deploy wrapper for each identity
2. Register wrapper address in IdentityRegistryStorage
3. Token uses existing verification flow — no code changes needed

## Step-by-Step Integration (Path A)

### 1. Deploy Bridge Contracts

```solidity
// Deploy in this order
EASTrustedIssuersAdapter adapter = new EASTrustedIssuersAdapter(tokenIssuer);
EASIdentityProxy identityProxy = new EASIdentityProxy(tokenIssuer);
EASClaimVerifier verifier = new EASClaimVerifier(tokenIssuer);

// Configure verifier
verifier.setEASAddress(EAS_CONTRACT_ADDRESS);
verifier.setTrustedIssuersAdapter(address(adapter));
verifier.setIdentityProxy(address(identityProxy));
verifier.setClaimTopicsRegistry(address(claimTopicsRegistry));
```

### 2. Configure Schema Mappings

Map ERC-3643 claim topics to EAS schema UIDs:

```solidity
// Topic 1 (KYC) -> Investor Eligibility Schema
verifier.setTopicSchemaMapping(1, INVESTOR_ELIGIBILITY_SCHEMA_UID);

// Topic 7 (Accreditation) -> Same or different schema
verifier.setTopicSchemaMapping(7, INVESTOR_ELIGIBILITY_SCHEMA_UID);
```

### 3. Add Trusted Attesters

> This is where the token issuer decides **which KYC providers to trust**. Only attestations from these providers will be accepted. You can add multiple providers — giving investors choice while maintaining compliance.

Register KYC providers as trusted attesters:

```solidity
uint256[] memory topics = new uint256[](2);
topics[0] = 1; // KYC
topics[1] = 7; // Accreditation

adapter.addTrustedAttester(KYC_PROVIDER_ADDRESS, topics);
```

### 4. Configure Required Topics

> Define what compliance checks your token requires. An investor must have valid attestations for **every** required topic to be eligible.

Set which topics are required for your token:

```solidity
claimTopicsRegistry.addClaimTopic(1); // KYC required
claimTopicsRegistry.addClaimTopic(7); // Accreditation required (optional)
```

### 5. Register Investor Identities

For multi-wallet support, register wallets to identity addresses:

```solidity
// Single wallet
identityProxy.registerWallet(investorWallet, identityAddress);

// Batch registration
address[] memory wallets = new address[](3);
wallets[0] = wallet1;
wallets[1] = wallet2;
wallets[2] = wallet3;
identityProxy.batchRegisterWallets(wallets, identityAddress);
```

### 6. KYC Provider Creates Attestation

> This is the KYC provider's job — not the token issuer's. After verifying an investor's identity (off-chain KYC/AML process), the provider issues an on-chain attestation via EAS. This attestation is reusable: it works for any token that trusts this provider.

The KYC provider creates an attestation on EAS:

```solidity
// Schema: address identity, uint8 kycStatus, uint8 accreditationType,
//         uint16 countryCode, uint64 expirationTimestamp
bytes memory data = abi.encode(
    identityAddress,
    1, // KYC_VERIFIED
    2, // ACCREDITED
    840, // USA
    uint64(block.timestamp + 365 days)
);

AttestationRequest memory request = AttestationRequest({
    schema: INVESTOR_ELIGIBILITY_SCHEMA_UID,
    data: AttestationRequestData({
        recipient: identityAddress,
        expirationTime: 0, // Use data-level expiration
        revocable: true,
        refUID: bytes32(0),
        data: data,
        value: 0
    })
});

bytes32 attestationUID = eas.attest(request);
```

### 7. Register Attestation in Verifier

Register the attestation for efficient lookup:

```solidity
verifier.registerAttestation(identityAddress, 1, attestationUID); // Topic 1 (KYC)
```

### 8. Verify Token Transfer Eligibility

> This is the payoff. When someone tries to buy, sell, or transfer your security token, the compliance check calls `isVerified()`. It returns `true` only if the investor has valid, non-revoked, non-expired attestations for every required topic from a trusted provider. All on-chain, all automatic.

The verification happens automatically during token transfers:

```solidity
// Inside your token or compliance contract
function canTransfer(address to) internal view returns (bool) {
    return verifier.isVerified(to);
}
```

## Configuration Options

### Direct Wallet Mode

If you don't need multi-wallet support, skip the identity proxy:

```solidity
verifier.setIdentityProxy(address(0));
// Attestations are made directly to wallet addresses
```

### Multiple KYC Providers

You can have multiple attesters for the same topic:

```solidity
adapter.addTrustedAttester(PROVIDER_1, topics);
adapter.addTrustedAttester(PROVIDER_2, topics);
// Investor can use attestation from either provider
```

### Schema per Topic

Different topics can use different schemas:

```solidity
verifier.setTopicSchemaMapping(1, KYC_SCHEMA_UID);
verifier.setTopicSchemaMapping(7, ACCREDITATION_SCHEMA_UID);
verifier.setTopicSchemaMapping(3, COUNTRY_SCHEMA_UID);
```

## Verification Flow

When `isVerified(address)` is called:

1. **Resolve Identity**: If `identityProxy` is set, resolve wallet to identity
2. **Get Required Topics**: Query `claimTopicsRegistry` for required topics
3. **For Each Topic**:
   - Get the mapped schema UID
   - Get trusted attesters for the topic
   - Check for valid registered attestation from any trusted attester
   - Validate: not revoked, not expired (EAS + data level)
4. **Return Result**: True only if all topics are satisfied

## Revocation — Real-Time Compliance Enforcement

> An investor fails an AML check. A sanctions list is updated. A KYC provider is compromised. In all these cases, you need to **immediately** block the investor from trading — not wait for a manual review cycle.

### By Attester: Revoke a Specific Investor

> **Scenario:** "Bob failed his annual AML re-check. His KYC attestation must be revoked immediately."

```solidity
eas.revoke(RevocationRequest({
    schema: schemaUID,
    data: RevocationRequestData({
        uid: attestationUID,
        value: 0
    })
}));
// Effect: Bob's attestation is instantly invalid.
// Next time anyone calls isVerified(bob), it returns false.
// Bob cannot buy, sell, or receive the token until re-verified.
```

### By Token Issuer: Remove Trust in a Provider

> **Scenario:** "We discovered KYC Provider X was issuing attestations without proper verification. We need to invalidate ALL their attestations."

```solidity
adapter.removeTrustedAttester(attesterAddress);
// Effect: EVERY attestation from this provider becomes invalid.
// All investors verified only by this provider are immediately blocked.
// Investors verified by other trusted providers are unaffected.
```

## Expiration Handling

Attestations expire in two ways:

1. **EAS-level expiration**: Set `expirationTime` in attestation request
2. **Data-level expiration**: Include `expirationTimestamp` in attestation data

The verifier checks both. Data-level expiration is recommended for flexibility.

## Error Handling

The verifier will revert if not properly configured:

| Error | Cause |
|-------|-------|
| `EASNotConfigured` | EAS address not set |
| `TrustedIssuersAdapterNotConfigured` | Adapter not set |
| `ClaimTopicsRegistryNotConfigured` | Registry not set |
| `SchemaNotMappedForTopic` | Missing topic→schema mapping |

`isVerified()` returns `false` (doesn't revert) when:
- No attestation registered for identity/topic
- Attestation is revoked
- Attestation is expired
- No trusted attesters for topic

## Events

Monitor these events for integration:

```solidity
// EASClaimVerifier
event EASAddressSet(address indexed easAddress);
event TrustedIssuersAdapterSet(address indexed adapterAddress);
event IdentityProxySet(address indexed proxyAddress);
event ClaimTopicsRegistrySet(address indexed registryAddress);
event TopicSchemaMappingSet(uint256 indexed claimTopic, bytes32 schemaUID);
event AttestationRegistered(address indexed identity, uint256 indexed claimTopic, address indexed attester, bytes32 attestationUID);

// EASTrustedIssuersAdapter
event TrustedAttesterAdded(address indexed attester, uint256[] claimTopics);
event TrustedAttesterRemoved(address indexed attester);
event AttesterTopicsUpdated(address indexed attester, uint256[] claimTopics);

// EASIdentityProxy
event WalletRegistered(address indexed wallet, address indexed identity);
event WalletRemoved(address indexed wallet, address indexed identity);
```

## Testing Your Integration

Use the provided test helpers:

```solidity
import {MockEAS} from "./mocks/MockEAS.sol";
import {MockAttester} from "./mocks/MockAttester.sol";
import {MockClaimTopicsRegistry} from "./mocks/MockClaimTopicsRegistry.sol";

// In your test setup
MockEAS mockEAS = new MockEAS();
MockAttester kycProvider = new MockAttester(address(mockEAS), "Test KYC");

// Create attestation
bytes32 uid = kycProvider.attestInvestorEligibility(
    schemaUID,
    recipient,
    identityAddress,
    1, // VERIFIED
    0, // NONE
    840, // USA
    0 // No expiration
);
```

## Security Considerations

1. **Trusted Attester Management**: Only add verified KYC providers
2. **Schema Validation**: Ensure schema UIDs match your registered schemas
3. **Expiration**: Set reasonable expiration times for attestations
4. **Access Control**: Only token issuer/agent should modify configurations
5. **Audit Trail**: Monitor events for compliance reporting

## Upgradeability

The bridge contracts are not upgradeable by default. For upgradeable deployments:

1. Use OpenZeppelin's upgradeable patterns
2. Modify contracts to inherit from `OwnableUpgradeable`
3. Deploy behind proxy contracts

## Support

For issues or questions:
- Review the test suite for usage examples
- Check the architecture documentation
- Open an issue on the repository
