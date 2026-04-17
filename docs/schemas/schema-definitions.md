# EAS Schema Definitions

## Overview

This document defines the EAS schemas used by the EAS-to-ERC-3643 Identity Bridge. These schemas are the minimum viable set for supporting compliant security token transfers.

## Schema Registration

All schemas are registered on the EAS Schema Registry. The resulting schema UIDs are deterministic based on:
- Schema string
- Resolver address
- Revocability setting

Schema UIDs should be stored in a constants file and referenced by the bridge contracts.

---

## Schema 1 v2: Investor Eligibility

**Version:** 2.0 (post audit finding C-7). **Greenfield** — there is no
production v1 deployment, so no dual-accept migration is provided. Any
deployments should use v2 directly.

### Purpose

Primary compliance attestation for security token investors. Covers KYC status,
accreditation type, country, AML, sanctions, source-of-funds, and evidence
traceability — enough to gate Reg D / Reg S / MiFID II / OFAC workflows via
the Shibui topic-policy modules.

### Schema String

```
address identity, uint8 kycStatus, uint8 amlStatus, uint8 sanctionsStatus, uint8 sourceOfFundsStatus, uint8 accreditationType, uint16 countryCode, uint64 expirationTimestamp, bytes32 evidenceHash, uint8 verificationMethod
```

### New fields (audit C-7)

- `amlStatus` — 0 = clear, 1 = flagged. Consumed by `AMLPolicy`.
- `sanctionsStatus` — 0 = clear, 1 = hit. Consumed by `SanctionsPolicy`.
- `sourceOfFundsStatus` — 0 = not verified, 1 = verified. Consumed by `SourceOfFundsPolicy`.
- `evidenceHash` — `keccak256` of the underlying KYC file set, or an equivalent commitment. Auditor-visible; the bytes themselves stay with the KYC provider.
- `verificationMethod` — 1 = self-attested, 2 = third-party reviewer, 3 = professional letter, 4 = broker-dealer suitability file. Mirrors the field set in `docs/research/claim-topic-analysis.md`.

### Field Definitions

| Field | Type | Description |
|-------|------|-------------|
| `identity` | address | The identity address this attestation applies to |
| `kycStatus` | uint8 | Know Your Customer verification status |
| `accreditationType` | uint8 | Investor accreditation classification |
| `countryCode` | uint16 | ISO 3166-1 numeric country code |
| `expirationTimestamp` | uint64 | Unix timestamp after which the attestation is invalid |

### KYC Status Values

| Value | Name | Description |
|-------|------|-------------|
| 0 | NOT_VERIFIED | KYC not completed |
| 1 | VERIFIED | KYC completed and valid |
| 2 | EXPIRED | KYC verification has expired |
| 3 | REVOKED | KYC verification revoked |
| 4 | PENDING | KYC verification in progress |

### Accreditation Type Values

| Value | Name | Description | Jurisdiction |
|-------|------|-------------|--------------|
| 0 | NONE | Not accredited | - |
| 1 | RETAIL_QUALIFIED | Retail investor with qualifying knowledge/experience | EU (MiFID) |
| 2 | ACCREDITED | Accredited investor | US (Reg D) |
| 3 | QUALIFIED_PURCHASER | Qualified purchaser ($5M+ investments) | US |
| 4 | INSTITUTIONAL | Institutional investor | Global |

### Configuration

| Setting | Value |
|---------|-------|
| Revocable | Yes |
| Resolver | `EASTrustedIssuersAdapter` (validates attester authorization) |
| EAS Expiration | Optional (use `expirationTimestamp` in data for flexibility) |

### Claim Topic Mapping

This schema covers multiple ERC-3643 claim topics:

| Claim Topic ID | Topic Name | Schema Field |
|----------------|------------|--------------|
| 1 | KYC | `kycStatus` |
| 3 | COUNTRY | `countryCode` |
| 7 | ACCREDITATION | `accreditationType` |
| 9 | PROFESSIONAL | `accreditationType >= 1` |
| 10 | INSTITUTIONAL | `accreditationType == 4` |

### Encoding Example

```solidity
// Solidity encoding
bytes memory data = abi.encode(
    0x1234567890123456789012345678901234567890,  // identity
    uint8(1),   // kycStatus = VERIFIED
    uint8(2),   // accreditationType = ACCREDITED
    uint16(840), // countryCode = USA
    uint64(1735689600) // expirationTimestamp = 2025-01-01
);
```

```typescript
// TypeScript encoding (EAS SDK)
const schemaEncoder = new SchemaEncoder(
    "address identity, uint8 kycStatus, uint8 accreditationType, uint16 countryCode, uint64 expirationTimestamp"
);
const encodedData = schemaEncoder.encodeData([
    { name: "identity", value: "0x1234...", type: "address" },
    { name: "kycStatus", value: 1, type: "uint8" },
    { name: "accreditationType", value: 2, type: "uint8" },
    { name: "countryCode", value: 840, type: "uint16" },
    { name: "expirationTimestamp", value: 1735689600, type: "uint64" }
]);
```

### Validation Logic

```solidity
function validateInvestorEligibility(Attestation memory att) internal view returns (bool) {
    // Check not revoked
    if (att.revocationTime > 0) return false;

    // Check EAS-level expiration
    if (att.expirationTime != 0 && att.expirationTime < block.timestamp) return false;

    // Decode data
    (
        address identity,
        uint8 kycStatus,
        uint8 accreditationType,
        uint16 countryCode,
        uint64 expirationTimestamp
    ) = abi.decode(att.data, (address, uint8, uint8, uint16, uint64));

    // Check data-level expiration
    if (expirationTimestamp != 0 && expirationTimestamp < block.timestamp) return false;

    // Check KYC status
    if (kycStatus != 1) return false; // Must be VERIFIED

    return true;
}
```

---

## Schema 2: Issuer Authorization (resolver-gated)

### Purpose

Cryptographic audit trail backing the
`EASTrustedIssuersAdapter.addTrustedAttester(attester, topics, authUID)` call.
Every add/update of a trusted attester MUST cite a live Schema-2 attestation
whose `recipient == attester` and whose `authorizedTopics ⊇ requested topics`.

Post audit finding C-5, Schema 2 is registered with the `TrustedIssuerResolver`
address as its resolver (see `contracts/resolvers/TrustedIssuerResolver.sol`).
The resolver rejects any `onAttest` callback from an attester that is not in
the admin-curated authorizer set, so the trust boundary is cryptographic rather
than purely conventional.

### Schema String

```
address issuerAddress, uint256[] authorizedTopics, string issuerName
```

### Field Definitions

| Field | Type | Description |
|-------|------|-------------|
| `issuerAddress` | address | The address being authorized as a trusted attester |
| `authorizedTopics` | uint256[] | Array of claim topic IDs the issuer is authorized for |
| `issuerName` | string | Human-readable name of the issuer (for display purposes) |

### Configuration

| Setting | Value |
|---------|-------|
| Revocable | Yes |
| Resolver | None (administered by token issuer directly) |
| EAS Expiration | Optional |

### Usage

This schema is primarily for administrative purposes and governance transparency. The on-chain authorization is actually managed by `EASTrustedIssuersAdapter`.

**Workflow:**
1. Token issuer creates Issuer Authorization attestation
2. Token issuer calls `EASTrustedIssuersAdapter.addTrustedAttester()`
3. Attestation serves as audit trail and governance record

### Encoding Example

```solidity
// Solidity encoding
uint256[] memory topics = new uint256[](2);
topics[0] = 1; // KYC
topics[1] = 7; // ACCREDITATION

bytes memory data = abi.encode(
    0xKYCProviderAddress,
    topics,
    "Acme KYC Services"
);
```

### Alternative: On-Chain Only

For V1, Issuer Authorization can be managed purely through `EASTrustedIssuersAdapter` without EAS attestations. The attestation adds:
- Audit trail
- Human-readable metadata
- Potential for cross-organization discovery

---

## Schema 3: Wallet-Identity Link

### Purpose

Attests that a wallet address belongs to a specific identity address, enabling multi-wallet support.

### Schema String

```
address walletAddress, address identityAddress, uint64 linkedTimestamp
```

### Field Definitions

| Field | Type | Description |
|-------|------|-------------|
| `walletAddress` | address | The wallet being linked |
| `identityAddress` | address | The identity the wallet belongs to |
| `linkedTimestamp` | uint64 | When the link was established |

### Configuration

| Setting | Value |
|---------|-------|
| Revocable | Yes |
| Resolver | `WalletLinkResolver` (validates attester is identity owner) |
| EAS Expiration | None (links are persistent until revoked) |

### Resolver Logic

```solidity
contract WalletLinkResolver is SchemaResolver {
    function onAttest(
        Attestation calldata attestation,
        uint256 /* value */
    ) internal override returns (bool) {
        // Decode the attestation data
        (address walletAddress, address identityAddress, ) =
            abi.decode(attestation.data, (address, address, uint64));

        // The attester must be the identity address itself
        // OR hold a management key on the identity (V2)
        return attestation.attester == identityAddress;
    }

    function onRevoke(
        Attestation calldata attestation,
        uint256 /* value */
    ) internal override returns (bool) {
        // Same authorization check for revocation
        (address walletAddress, address identityAddress, ) =
            abi.decode(attestation.data, (address, address, uint64));

        return attestation.attester == identityAddress;
    }
}
```

### V1 vs V2 Usage

**V1 (Current):** Wallet linking managed by `EASIdentityProxy` contract with agent-based registration. Schema 3 is defined but not required for core functionality.

**V2 (Future):** Replace agent-managed `EASIdentityProxy` with attestation-based linking:
1. Identity owner creates Wallet-Identity Link attestation
2. `EASIdentityProxy` reads attestations instead of internal mapping
3. Permissionless, fully decentralized wallet linking

---

## Schema Registration Process

### Sepolia Deployment

```typescript
// Using EAS SDK
import { SchemaRegistry } from "@ethereum-attestation-service/eas-sdk";

const schemaRegistry = new SchemaRegistry(SEPOLIA_SCHEMA_REGISTRY);

// Schema 1: Investor Eligibility
const schema1 = "address identity, uint8 kycStatus, uint8 accreditationType, uint16 countryCode, uint64 expirationTimestamp";
const tx1 = await schemaRegistry.register({
    schema: schema1,
    resolverAddress: trustedIssuersAdapterAddress,
    revocable: true
});
const schemaUID1 = await tx1.wait();

// Schema 2: Issuer Authorization
const schema2 = "address issuerAddress, uint256[] authorizedTopics, string issuerName";
const tx2 = await schemaRegistry.register({
    schema: schema2,
    resolverAddress: ethers.ZeroAddress,
    revocable: true
});
const schemaUID2 = await tx2.wait();

// Schema 3: Wallet-Identity Link
const schema3 = "address walletAddress, address identityAddress, uint64 linkedTimestamp";
const tx3 = await schemaRegistry.register({
    schema: schema3,
    resolverAddress: walletLinkResolverAddress,
    revocable: true
});
const schemaUID3 = await tx3.wait();
```

### Schema UID Storage

Store schema UIDs in a constants file:

```solidity
// SchemaUIDs.sol
library SchemaUIDs {
    // Sepolia
    bytes32 constant INVESTOR_ELIGIBILITY_SEPOLIA = 0x...; // Actual UID after registration
    bytes32 constant ISSUER_AUTHORIZATION_SEPOLIA = 0x...;
    bytes32 constant WALLET_IDENTITY_LINK_SEPOLIA = 0x...;

    // Mainnet
    bytes32 constant INVESTOR_ELIGIBILITY_MAINNET = 0x...;
    bytes32 constant ISSUER_AUTHORIZATION_MAINNET = 0x...;
    bytes32 constant WALLET_IDENTITY_LINK_MAINNET = 0x...;
}
```

---

## Future Schemas (V2+)

### Extended Compliance Schema

```
address identity, uint8 amlStatus, uint8 sanctionsStatus, uint8 pep Status, bytes32 dueDiligenceHash
```

For enhanced due diligence requirements.

### Transfer Restriction Schema

```
address identity, address[] restrictedCounterparties, uint256 maxTransferAmount, uint64 lockupEndTimestamp
```

For investor-specific transfer restrictions.

### Investor Cap Schema

```
address token, address identity, uint256 maxHoldingAmount, uint256 currentHolding
```

For per-investor holding limits.

---

## Schema Versioning

If schemas need to evolve:

1. **New schema UID** - Register a new schema version
2. **Claim topic mapping** - Point topic to new schema UID
3. **Migration period** - Accept both old and new schemas temporarily
4. **Deprecation** - Remove old schema mapping

The bridge supports multiple schema UIDs per claim topic to enable smooth migrations.
