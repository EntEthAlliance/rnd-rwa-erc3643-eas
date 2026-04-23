# Shibui schema review brief

**Purpose:** Validate the two EAS schemas Shibui is about to register on Sepolia before the UIDs become load-bearing. Schema UIDs are deterministic on `(schemaString, resolver, revocable)` — once attestations are issued against a UID, changing any of those three forces a migration.

**Scope of this review:** the two schemas below, their field set, types, resolver binding, and revocability. *Not* in scope: contract architecture, policy logic, access control, gas. Those have been audited separately.

**Time budget:** ~15 minutes.

---

## Context in one paragraph

Shibui replaces ERC-3643's per-investor OnchainID contract with EAS attestations: one attestation per (identity, claim-topic) pair, decoded at transfer time by `EASClaimVerifier.isVerified(wallet)`. The bridge requires *two* schemas — one for investor data, one for provider authorization — and a third optional one on the V2 roadmap. We are registering Schemas 1 and 2 on Sepolia; Schema 3 is not in scope for this review.

---

## Schema 1 — Investor Eligibility

**Schema string (exact):**
```
address identity,uint8 kycStatus,uint8 amlStatus,uint8 sanctionsStatus,uint8 sourceOfFundsStatus,uint8 accreditationType,uint16 countryCode,uint64 expirationTimestamp,bytes32 evidenceHash,uint8 verificationMethod
```

**Resolver:** `address(0)` — **no resolver.** Policies enforce payload at verify time (lazy validation).
**Revocable:** yes.
**Encoded size:** 320 bytes (10 × 32-byte words).

| # | Field | Type | Values | Rationale |
|---|---|---|---|---|
| 1 | `identity` | `address` | — | The attestation recipient (ERC-3643 identity address, not wallet). |
| 2 | `kycStatus` | `uint8` | 0=NOT_VERIFIED, 1=VERIFIED, 2=EXPIRED, 3=REVOKED, 4=PENDING | Core KYC gate. |
| 3 | `amlStatus` | `uint8` | 0=CLEAR, 1=FLAGGED | Audit C-7 requirement. |
| 4 | `sanctionsStatus` | `uint8` | 0=CLEAR, 1=HIT | OFAC/EU sanctions gate. |
| 5 | `sourceOfFundsStatus` | `uint8` | 0=NOT_VERIFIED, 1=VERIFIED | MiFID II source-of-funds. |
| 6 | `accreditationType` | `uint8` | 0=NONE, 1=RETAIL_QUALIFIED, 2=ACCREDITED, 3=QUALIFIED_PURCHASER, 4=INSTITUTIONAL | Drives Reg D / Reg S / MiFID gating. |
| 7 | `countryCode` | `uint16` | ISO 3166-1 numeric (e.g. 840=USA) | Used by `CountryAllowListPolicy`. |
| 8 | `expirationTimestamp` | `uint64` | unix ts; 0 = never | Payload-level expiry, separate from EAS-level. |
| 9 | `evidenceHash` | `bytes32` | keccak256 of KYC dossier | Commitment only — raw PII stays off-chain with the KYC provider. |
| 10 | `verificationMethod` | `uint8` | 1=SELF_ATTESTED, 2=THIRD_PARTY, 3=PRO_LETTER, 4=BROKER_DEALER | Auditor-visible provenance. |

**Claim-topic mapping** (topic → field read by the corresponding `ITopicPolicy`):
- KYC (1) → `kycStatus == 1`
- AML (2) → `amlStatus == 0`
- COUNTRY (3) → `countryCode` ∈ allow-list
- ACCREDITATION (7) → `accreditationType` ∈ allowed set
- PROFESSIONAL (9) → `accreditationType >= 1`
- INSTITUTIONAL (10) → `accreditationType == 4`
- SANCTIONS_CHECK (13) → `sanctionsStatus == 0`
- SOURCE_OF_FUNDS (14) → `sourceOfFundsStatus == 1`

**Why one big schema instead of one-schema-per-topic:** every real-world KYC provider collects all these fields in a single file. Splitting into eight schemas would mean eight attestations, eight signatures, and eight revocations per investor — that's both a UX and a cost problem. One fat attestation keeps the provider's mental model intact and lets the policy layer decide which fields any given token cares about.

---

## Schema 2 — Issuer Authorization

**Schema string (exact):**
```
address issuerAddress,uint256[] authorizedTopics,string issuerName
```

**Resolver:** `TrustedIssuerResolver` (admin-curated whitelist of authorizers).
**Revocable:** yes.

| Field | Type | Description |
|---|---|---|
| `issuerAddress` | `address` | The KYC provider being authorized (attestation recipient). |
| `authorizedTopics` | `uint256[]` | Claim topics this provider is vouched for. |
| `issuerName` | `string` | Human-readable label (audit trail only, not on-chain logic). |

**Purpose:** cryptographic audit trail for `EASTrustedIssuersAdapter.addTrustedAttester(attester, topics, authUID)`. Every trust change on the adapter must cite a live Schema-2 attestation where `recipient == attester` and `authorizedTopics ⊇ requested topics`. Without this, any wallet with the right role could silently whitelist itself.

**Resolver rationale:** Schema 1 uses lazy verification (check at read time) because the data is already gated by per-topic policies. Schema 2 needs eager gating because the write itself is the privileged action — if anyone could self-issue a "I'm authorized" attestation, the adapter's trust check becomes circular. The `TrustedIssuerResolver.onAttest` callback is the gate.

---

## Trade-offs we've already considered

1. **Why revocable, not immutable?** — Compliance events (sanctions listing, KYC expiry, wallet compromise) require immediate invalidation. Immutable attestations would force a full re-mint at the token level.
2. **Why `evidenceHash` instead of raw data?** — GDPR / MiCA / Reg BI: PII on-chain is a non-starter. The hash commits to a specific document set; the KYC provider holds the preimage for a regulator request.
3. **Why `uint8` for enums that only need `bool`?** — Future-proofing. AML today is clear/flagged; tomorrow it's a four-band risk score. Cost of the extra 7 bits: nothing (ABI-packed into a 32-byte word regardless).
4. **Why not a dedicated `ITopicPolicy` per schema field?** — We have one; it's called `TopicPolicyBase` and it decodes the full struct once per `isVerified()` call. Splitting the schema would mean N decodes. Benchmarked: single decode is measurably cheaper.
5. **Why no resolver on Schema 1?** — An `onAttest` resolver would force the KYC provider to pay gas for every attestation at the Ethereum L1 rate, and the gate it would provide (attester is in the trusted set) is already enforced at `EASClaimVerifier.registerAttestation()`. Lazy > eager here.

---

## What we'd like validated

Short list — any "yes, fine" on these is enough:

1. **Field completeness.** Is there any compliance signal an EEA-member issuer would expect to find in this schema that's missing? (E.g., PEP status, tax residency, jurisdiction of formation for entities.)
2. **Type economy.** Any field where the type is over- or under-sized? `countryCode` as `uint16` (ISO numeric → max 894) is deliberate, but `verificationMethod` as `uint8` may be cramped if real-world provenance signals proliferate.
3. **Enum stability.** The `kycStatus` and `accreditationType` value spaces are append-only by convention. Is that enforceable enough, or should we version-pin via a separate `schemaVersion` field?
4. **Schema 2 minimalism.** `issuerName` is a free-text `string`. Is that governance-sufficient, or should it be a `bytes32` commitment to a public issuer registry? (We chose string for debugging / block-explorer legibility; happy to reconsider.)
5. **Migration path.** If a regulator demands a new field in 18 months, we register Schema 3 and have the bridge accept both UIDs temporarily. Is that migration surface acceptable, or should we bake a version field in now?
6. **Privacy boundary.** The only identifying bytes on-chain are the identity address + `evidenceHash`. Is that aligned with how your legal team is thinking about GDPR Art. 17 / CCPA deletion requests?

---

## What we do not need reviewed here

- Policy logic (`KYCStatusPolicy`, `CountryAllowListPolicy`, etc.) — each has its own unit tests; separate review cycle.
- `EASClaimVerifier` or `EASTrustedIssuersAdapter` contract code — audited.
- UUPS upgrade path — parked per `docs/execution/mvp-uups-execution-plan.md`.
- Gas profile — see `docs/gas-benchmarks.md`.

---

## How to respond

Plain text / Slack / PR comment / email — whatever's fastest. A "LGTM, register them" is fine. A specific "change X because Y" is better. Targeted silence on any of the six questions above reads as tacit approval.

**Artifacts for reference:**
- [`docs/schemas/schema-definitions.md`](schemas/schema-definitions.md) — full spec
- [`script/RegisterSchemas.s.sol`](../script/RegisterSchemas.s.sol) — actual registration call
- [`contracts/policies/TopicPolicyBase.sol`](../contracts/policies/TopicPolicyBase.sol) — shared decoder
- [`contracts/resolvers/TrustedIssuerResolver.sol`](../contracts/resolvers/TrustedIssuerResolver.sol) — Schema-2 gate
