# EAS Schema Definitions

Canonical reference for the EAS schemas Shibui registers on-chain. The source of
truth is [`script/RegisterSchemas.s.sol`](../../script/RegisterSchemas.s.sol);
this document explains each field's meaning and how the policy modules consume
it. If anything here diverges from the script, the script wins.

Companion documents:
- [`shibui-semantics-catalog-v0.1.md`](./shibui-semantics-catalog-v0.1.md) — semantic interpretation of the live schemas.
- [`shibui-conformance-profiles-v0.2.md`](./shibui-conformance-profiles-v0.2.md) — illustrative provider / jurisdiction conformance mappings.

Shibui registers two schemas today:

| # | Name | Registered by | Consumed by |
|---|---|---|---|
| 1 | Investor Eligibility | `RegisterSchemas.s.sol` | All eight `ITopicPolicy` modules |
| 2 | Issuer Authorization | `RegisterSchemas.s.sol` | `EASTrustedIssuersAdapter` + `TrustedIssuerResolver` |

A third schema (Wallet-Identity Link) is on the V2 roadmap and **not deployed**;
see [deferred items](#schema-3--wallet-identity-link-deferred) at the bottom.

---

## Schema 1 — Investor Eligibility

The single canonical payload that every production claim topic decodes.

### Schema string

```
address identity, uint8 kycStatus, uint8 amlStatus, uint8 sanctionsStatus, uint8 sourceOfFundsStatus, uint8 accreditationType, uint16 countryCode, uint64 expirationTimestamp, bytes32 evidenceHash, uint8 verificationMethod
```

Encoded size: 320 bytes (10 × 32).

### Registration parameters

| Setting | Value | Why |
|---|---|---|
| Resolver | `address(0)` | Policies enforce payload at verify time (lazy validation). No per-attest resolver callback keeps gas and attestation cost low. |
| Revocable | `true` | Attesters must be able to revoke on compliance changes. |
| EAS expiration | optional | `expirationTimestamp` in the payload is the authoritative deadline; EAS-level expiration is honoured as a secondary check. |

### Fields

| # | Field | Type | Values | Consumer |
|---|---|---|---|---|
| 1 | `identity` | `address` | — | ERC-3643 identity address (not a wallet). Recipient of the attestation. |
| 2 | `kycStatus` | `uint8` | 0 NOT_VERIFIED, 1 VERIFIED, 2 EXPIRED, 3 REVOKED, 4 PENDING | `KYCStatusPolicy` — requires `== 1 VERIFIED`. |
| 3 | `amlStatus` | `uint8` | 0 CLEAR, 1 FLAGGED | `AMLPolicy` — requires `== 0 CLEAR`. |
| 4 | `sanctionsStatus` | `uint8` | 0 CLEAR, 1 HIT | `SanctionsPolicy` — requires `== 0 CLEAR`. |
| 5 | `sourceOfFundsStatus` | `uint8` | 0 NOT_VERIFIED, 1 VERIFIED | `SourceOfFundsPolicy` — requires `== 1 VERIFIED`. |
| 6 | `accreditationType` | `uint8` | 0 NONE, 1 RETAIL_QUALIFIED, 2 ACCREDITED, 3 QUALIFIED_PURCHASER, 4 INSTITUTIONAL | `AccreditationPolicy` (admin-configured allow-set), `ProfessionalInvestorPolicy` (≥1), `InstitutionalInvestorPolicy` (==4). |
| 7 | `countryCode` | `uint16` | ISO 3166-1 numeric | `CountryAllowListPolicy` (allow- or block-list). |
| 8 | `expirationTimestamp` | `uint64` | Unix ts; 0 = never | Checked by every policy via `TopicPolicyBase`. |
| 9 | `evidenceHash` | `bytes32` | `keccak256` of the KYC dossier | Not enforced on-chain. Commits to off-chain evidence for post-trade audit. |
| 10 | `verificationMethod` | `uint8` | 1 SELF_ATTESTED, 2 THIRD_PARTY, 3 PROFESSIONAL_LETTER, 4 BROKER_DEALER_FILE | Not enforced on-chain. Provenance for auditors. |

Canonical enum values live in [`contracts/policies/TopicPolicyBase.sol`](../../contracts/policies/TopicPolicyBase.sol) — on-chain and off-chain tooling should import from there.

### Claim topics that decode this schema

| Topic ID | Name | Policy | Predicate (matches `validate()` in code) |
|---:|---|---|---|
| 1 | KYC | `KYCStatusPolicy` | `kycStatus == 1` (VERIFIED) |
| 2 | AML | `AMLPolicy` | `amlStatus == 0` (CLEAR) |
| 3 | COUNTRY | `CountryAllowListPolicy` | `countryCode` in admin set; mode flag selects allow-list vs block-list |
| 7 | ACCREDITATION | `AccreditationPolicy` | `accreditationType` in admin-configured allow-set |
| 9 | PROFESSIONAL | `ProfessionalInvestorPolicy` | `accreditationType >= 1` (RETAIL_QUALIFIED or higher; MiFID II) |
| 10 | INSTITUTIONAL | `InstitutionalInvestorPolicy` | `accreditationType == 4` (INSTITUTIONAL) |
| 13 | SANCTIONS_CHECK | `SanctionsPolicy` | `sanctionsStatus == 0` (CLEAR) |
| 14 | SOURCE_OF_FUNDS | `SourceOfFundsPolicy` | `sourceOfFundsStatus == 1` (VERIFIED) |

All eight bind to the same Investor Eligibility schema UID via `EASClaimVerifier.setTopicSchemaMapping(topicId, investorEligibilityUID)`.

### Encoding example

```solidity
bytes memory data = abi.encode(
    identityAddress,              // 1. identity
    uint8(1),                     // 2. kycStatus         (VERIFIED)
    uint8(0),                     // 3. amlStatus         (CLEAR)
    uint8(0),                     // 4. sanctionsStatus   (CLEAR)
    uint8(1),                     // 5. sourceOfFundsStatus (VERIFIED)
    uint8(2),                     // 6. accreditationType (ACCREDITED)
    uint16(840),                  // 7. countryCode       (USA)
    uint64(block.timestamp + 365 days), // 8. expirationTimestamp
    evidenceHash,                 // 9.  keccak256 of off-chain KYC dossier
    uint8(2)                      // 10. verificationMethod (THIRD_PARTY)
);
```

TypeScript encoding lives in [`demo/shibui-app/lib/schemas.ts`](../../demo/shibui-app/lib/schemas.ts) (`encodeInvestorEligibility`).

### Validation

Each policy decodes the payload and runs its single predicate. Payload-aware
verification is not optional — the common path is:

1. `TopicPolicyBase._isDecodable(data)` rejects short payloads.
2. `TopicPolicyBase._decode(data)` returns a typed `InvestorEligibility` struct.
3. The policy returns `true` iff its predicate holds and `expirationTimestamp` is in the future.
4. `EASClaimVerifier.isVerified` additionally checks: attestation exists, schema matches, not revoked, not EAS-expired, attester still trusted.

See [`contracts/policies/TopicPolicyBase.sol`](../../contracts/policies/TopicPolicyBase.sol) and any concrete policy (e.g. `KYCStatusPolicy.sol`) for the exact code.

---

## Schema 2 — Issuer Authorization

Cryptographic audit trail backing `addTrustedAttester`. Every add or update of
a trusted attester MUST cite a live Schema 2 attestation whose `recipient ==
attester` and whose `authorizedTopics` is a superset of the requested topics.

### Schema string

```
address issuerAddress, uint256[] authorizedTopics, string issuerName
```

### Registration parameters

| Setting | Value | Why |
|---|---|---|
| Resolver | `TrustedIssuerResolver` address | Rejects `onAttest` from any attester outside the admin-curated authorizer set (audit finding C-5). The trust boundary is cryptographic, not conventional. |
| Revocable | `true` | Authorization can be revoked when a provider is rotated out. |
| EAS expiration | optional | — |

The resolver address is passed via the `ISSUER_AUTH_RESOLVER` env var at registration time; the adapter must then be configured with the resulting schema UID via `setIssuerAuthSchemaUID`.

### Fields

| Field | Type | Description |
|---|---|---|
| `issuerAddress` | `address` | The address being authorized as a trusted attester. Enforced to match the adapter's `attester` argument. |
| `authorizedTopics` | `uint256[]` | Claim topic IDs the issuer is authorized to attest. Must be a superset of the topics requested in `addTrustedAttester`. |
| `issuerName` | `string` | Display name for the issuer. Not enforced. |

### Workflow

1. Admin authorizer (an address in the resolver's authorizer set) calls `EAS.attest` against Schema 2 with `recipient = attester`, `data = (attester, authorizedTopics, issuerName)`.
2. The `TrustedIssuerResolver.onAttest` callback verifies the attester is an approved authorizer and that `recipient` matches the encoded `issuerAddress`.
3. The compliance multisig (or operator) calls `EASTrustedIssuersAdapter.addTrustedAttester(attester, requestedTopics, authUID)` with the resulting UID. The adapter re-validates that the cited attestation is live, on-schema, and covers the requested topics.

### Encoding example

```solidity
uint256[] memory topics = new uint256[](2);
topics[0] = 1; // KYC
topics[1] = 7; // ACCREDITATION

bytes memory data = abi.encode(
    kycProviderAddress,
    topics,
    "Acme KYC Services"
);
```

---

## Schema 3 — Wallet-Identity Link (deferred)

Not deployed. Wallet-to-identity binding is handled by
`EASIdentityProxy.registerWallet` (agent-gated) in the current design. An
attestation-based replacement — permissionless, with identity-owner
authorization — is on the V2 roadmap. See [`docs/research/passport-format-v0.1.md`](../research/passport-format-v0.1.md) for the broader direction.

---

## Schema registration

Schemas are registered by [`script/RegisterSchemas.s.sol`](../../script/RegisterSchemas.s.sol).

Schema UIDs are deterministic on `keccak256(schemaString, resolverAddress, revocable)` — registering the same `(string, resolver, revocable)` triple on any chain yields the same UID. Record the resulting UIDs in [`deployments/<chain>.json`](../../deployments/sepolia.json) under `schemas.investorEligibility` and `schemas.issuerAuthorization`.

Because UIDs are derived from the schema string, **any change to the schema string creates a new UID** — existing attestations under the old UID are not automatically accepted. Shibui treats the current schemas as greenfield; there is no prior production deployment, so no dual-accept migration is provided.
