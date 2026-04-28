# Shibui Semantics Catalog v0.1

> **Status:** EEA working draft
> **Document class:** Semantic reference specification
> **Purpose:** Canonical semantic interpretation of the two live Shibui EAS schemas.
> **Scope:** This document defines the intended meaning of the current schema values, the minimum evidence threshold for asserting them, and the interpretation rules expected of downstream verifiers.
> **Non-goal:** This document does **not** modify the on-chain schema strings registered by [`script/RegisterSchemas.s.sol`](../../script/RegisterSchemas.s.sol). If this catalog and the implementation diverge, the implementation remains authoritative for live protocol behavior and this document must be corrected.

---

## 1. Design intent

Shibui separates **transport** from **meaning**:

- the **schema strings** define the bytes carried in EAS attestations;
- the **policy contracts** define what a verifier accepts on-chain;
- this **Semantics Catalog** defines the intended real-world meaning of each field and enum value.

The design objective is interoperability. Two providers should be able to produce attestations that a token issuer or verifier can interpret consistently without bilateral custom mapping.

---

## 2. Editorial rules for v0.1

The following editorial rules apply throughout this draft.

1. **Code authority wins.** Enum values, field order, and live predicates are taken from the deployed Shibui implementation.
2. **Append-only semantics.** Existing enum values must never be reassigned a new meaning. New meanings require new appended values or a new schema version.
3. **Minimum-evidence semantics.** This catalog sets the floor for what must be true before an attester uses a value. Providers may do more, not less.
4. **Jurisdictional equivalence where needed.** Some values are legal categories; where exact legal terms differ across jurisdictions, this catalog defines the umbrella class Shibui is trying to express.
5. **Privacy by commitment.** Shibui carries eligibility outcomes and an evidence commitment, not the raw KYC file.

---

## 3. Canonical live schemas

## Schema 1 — Investor Eligibility

**Exact live schema string**

```text
address identity,uint8 kycStatus,uint8 amlStatus,uint8 sanctionsStatus,uint8 sourceOfFundsStatus,uint8 accreditationType,uint16 countryCode,uint64 expirationTimestamp,bytes32 evidenceHash,uint8 verificationMethod
```

**Live role in protocol**

This is the single canonical eligibility payload used by all eight production claim-topic policy modules.

**Fields**

1. `identity`
2. `kycStatus`
3. `amlStatus`
4. `sanctionsStatus`
5. `sourceOfFundsStatus`
6. `accreditationType`
7. `countryCode`
8. `expirationTimestamp`
9. `evidenceHash`
10. `verificationMethod`

## Schema 2 — Issuer Authorization

**Exact live schema string**

```text
address issuerAddress,uint256[] authorizedTopics,string issuerName
```

**Live role in protocol**

This is the governance / audit-trail schema used to authorize trusted attesters for specific Shibui claim topics.

**Fields**

1. `issuerAddress`
2. `authorizedTopics`
3. `issuerName`

---

## 4. Normative references used in this draft

This first version uses the following source hierarchy:

### External authoritative sources

- **FATF Recommendation 10** — customer due diligence baseline for KYC / source-of-funds expectations.
- **ISO 3166-1 numeric** — canonical source for country codes.
- **SEC Regulation D / Rule 501** — US accredited investor baseline.
- **US Investment Company Act qualified purchaser concept** — US qualified purchaser baseline.
- **MiFID II Annex II** — EU professional client baseline.
- **OFAC sanctions lists / search service** and equivalent competent sanctions authorities — sanctions-screening reference points.

### Shibui-internal canonical sources

Where no global standard cleanly defines the exact enum, Shibui itself is the canonical source:

- [`script/RegisterSchemas.s.sol`](../../script/RegisterSchemas.s.sol)
- [`docs/schemas/schema-definitions.md`](schema-definitions.md)
- [`contracts/policies/TopicPolicyBase.sol`](../../contracts/policies/TopicPolicyBase.sol)
- concrete policy modules under [`contracts/policies/`](../../contracts/policies/)
- [`contracts/resolvers/TrustedIssuerResolver.sol`](../../contracts/resolvers/TrustedIssuerResolver.sol)
- [`contracts/EASTrustedIssuersAdapter.sol`](../../contracts/EASTrustedIssuersAdapter.sol)

Where this draft says **Shibui canonical enum**, it means the enum is currently governed by the live codebase rather than imported verbatim from an external registry.

---

# 5. Schema 1 — Investor Eligibility semantics

## 5.1 Schema purpose

Schema 1 expresses the current compliance posture of a specific ERC-3643 identity address. It is not a raw identity record. It is a compact eligibility payload used by Shibui policy modules to answer questions such as:

- is this identity currently KYC-verified?
- is this identity clear from AML and sanctions checks?
- is this identity eligible under country restrictions?
- what investor-class bucket does this identity satisfy?

One attestation may satisfy multiple claim topics because the payload intentionally combines the common outcomes that regulated token offerings usually need.

---

## 5.2 Field catalog

## Field 1 — `identity`

**Definition**

The ERC-3643 identity address to which the attestation applies. This is the canonical subject of the eligibility record in Shibui. It is **not** a wallet address.

**Master source**

Shibui schema and verifier logic.

**Allowed values**

- any non-zero EVM address representing the investor identity subject

**Minimum evidence threshold**

Before issuing the attestation, the attester must have resolved the customer or entity to the identity address that the relevant token / issuer stack recognizes as the compliance subject.

**Operational rule**

- The EAS attestation `recipient` and the encoded `identity` field should refer to the same underlying identity subject.
- A wallet linked later through `EASIdentityProxy` inherits the eligibility of this identity address.

**Refresh and revocation**

Update whenever the identity binding changes or the previous subject mapping was wrong.

**Privacy notes**

This field exposes the identity address on-chain. It must not be treated as a substitute for the off-chain identity dossier.

---

## Field 2 — `kycStatus`

**Definition**

The attester's current KYC outcome for the identity.

**Master source**

Shibui canonical enum, with evidence threshold anchored in FATF Recommendation 10-style customer due diligence.

**Allowed values**

| Code | Label | Meaning |
|---:|---|---|
| 0 | `NOT_VERIFIED` | Required KYC review has not been completed to the attester's standard. |
| 1 | `VERIFIED` | Identity has passed the attester's KYC process and remains current. |
| 2 | `EXPIRED` | KYC was previously completed but is now out of date and must be refreshed. |
| 3 | `REVOKED` | KYC approval is affirmatively withdrawn due to a negative compliance event or attester action. |
| 4 | `PENDING` | Review has started but final approval has not yet been granted. |

**Minimum evidence threshold**

To assert `VERIFIED`, the attester must at minimum:

- identify the customer subject;
- verify identity using reliable, independent source material appropriate to the subject type;
- identify beneficial ownership where applicable;
- understand the purpose/nature of the relationship at a level sufficient for onboarding;
- complete onboarding review without unresolved blocking issues.

To assert `EXPIRED`, the attester must have a policy-based reason that the prior review is no longer current.

To assert `REVOKED`, the attester must have positively withdrawn the prior approval; passive lapse should use `EXPIRED`, not `REVOKED`.

**Cross-jurisdiction equivalence**

`VERIFIED` is an umbrella eligibility outcome, not a claim that every jurisdiction used the same onboarding steps. It means the attester regards the identity as meeting the KYC baseline required for the relevant regulated relationship in that jurisdiction.

**On-chain consumer**

`KYCStatusPolicy` requires `kycStatus == VERIFIED`.

**Refresh and revocation**

- refresh on attester review cycle;
- move to `EXPIRED` when refresh is overdue;
- move to `REVOKED` when approval is actively withdrawn.

**Privacy notes**

This field reveals outcome only, not the underlying identity documents or risk analysis.

---

## Field 3 — `amlStatus`

**Definition**

The attester's current AML outcome for the identity at the level needed for the relevant Shibui use case.

**Master source**

Shibui canonical enum, operationally aligned with AML onboarding and ongoing monitoring practices.

**Allowed values**

| Code | Label | Meaning |
|---:|---|---|
| 0 | `CLEAR` | No unresolved AML issue blocks use of the identity for the attester's intended regulated activity. |
| 1 | `FLAGGED` | The identity is subject to an unresolved AML issue or heightened finding that blocks approval under the attester's control framework. |

**Minimum evidence threshold**

To assert `CLEAR`, the attester must have completed AML screening/risk review appropriate to its regime with no unresolved blocking finding.

To assert `FLAGGED`, the attester must have a documented adverse outcome that, under its policy, blocks approval. A mere alert that is later cleared should not remain `FLAGGED`.

**Cross-jurisdiction equivalence**

`CLEAR` means “no blocking AML issue under the attester's regime,” not “identical AML law globally.”

**On-chain consumer**

`AMLPolicy` requires `amlStatus == CLEAR`.

**Refresh and revocation**

Must be refreshed whenever AML review is rerun or a new adverse event occurs.

**Privacy notes**

This field exposes only a binary approval outcome. Detailed typology, SAR, and case notes must remain off-chain.

---

## Field 4 — `sanctionsStatus`

**Definition**

The sanctions-screening outcome for the identity against the sanctions universe the attester applies.

**Master source**

Shibui canonical enum, with screening expectations anchored in competent sanctions authorities such as OFAC and equivalent applicable authorities.

**Allowed values**

| Code | Label | Meaning |
|---:|---|---|
| 0 | `CLEAR` | No unresolved sanctions match blocks the identity under the attester's applicable sanctions coverage. |
| 1 | `HIT` | A sanctions match or unresolved positive screening result blocks approval. |

**Minimum evidence threshold**

To assert `CLEAR`, the attester must screen the identity against the sanctions lists it is required or claims to cover and resolve candidate matches to a non-blocking outcome.

To assert `HIT`, the attester must have a positive or unresolved match that, under its compliance policy, requires denial or suspension of approval.

**Cross-jurisdiction equivalence**

This field is especially jurisdiction-sensitive. In v0.1, Shibui treats `CLEAR` / `HIT` as the attester's sanctions-screening outcome under its declared compliance perimeter. Future versions may need an explicit list-coverage or jurisdiction field if issuers require harmonized sanctions scope.

**On-chain consumer**

`SanctionsPolicy` requires `sanctionsStatus == CLEAR`.

**Refresh and revocation**

Should be refreshed on initial onboarding, periodic rescreening, and any material sanctions-list update the attester operationally relies on.

**Privacy notes**

No watchlist detail, matching rationale, or case notes belong on-chain.

---

## Field 5 — `sourceOfFundsStatus`

**Definition**

Whether the attester has verified source-of-funds sufficiently for the use case.

**Master source**

Shibui canonical enum, with minimum evidence floor aligned to FATF-style CDD expectations where source-of-funds inquiry is required.

**Allowed values**

| Code | Label | Meaning |
|---:|---|---|
| 0 | `NOT_VERIFIED` | Source of funds has not been verified to the attester's required standard. |
| 1 | `VERIFIED` | Source of funds has been reviewed and accepted to the attester's required standard. |

**Minimum evidence threshold**

To assert `VERIFIED`, the attester must have obtained and reviewed documentation or other evidence sufficient to support the claimed lawful source of funds for the relevant onboarding context.

Examples may include bank statements, sale documents, payroll evidence, audited statements, broker records, or equivalent evidence appropriate to the subject and jurisdiction.

**Cross-jurisdiction equivalence**

`VERIFIED` means the attester completed an adequate source-of-funds review under its applicable regime. It does not imply every jurisdiction uses the same documentary threshold.

**On-chain consumer**

`SourceOfFundsPolicy` requires `sourceOfFundsStatus == VERIFIED`.

**Refresh and revocation**

Refresh when the funding pattern materially changes, on enhanced due diligence review, or when the attester's policy requires renewed proof.

**Privacy notes**

The underlying financial records must remain off-chain. Shibui only carries the outcome and evidence commitment.

---

## Field 6 — `accreditationType`

**Definition**

The investor-category bucket the attester determined the identity satisfies.

**Master source**

Shibui canonical enum, with equivalence anchored to major regulatory concepts including SEC accredited investor, qualified purchaser, and MiFID II professional-client style categories.

**Allowed values**

| Code | Label | Meaning |
|---:|---|---|
| 0 | `NONE` | No qualifying investor-category outcome has been established. |
| 1 | `RETAIL_QUALIFIED` | A retail participant who qualifies under a regime-specific test short of full institutional categorization. |
| 2 | `ACCREDITED` | A non-retail investor outcome broadly equivalent to US accredited-investor treatment. |
| 3 | `QUALIFIED_PURCHASER` | A higher-threshold investor outcome broadly equivalent to US qualified-purchaser treatment. |
| 4 | `INSTITUTIONAL` | An institutional / entity-class investor outcome appropriate for institutional-only gating. |

**Minimum evidence threshold**

The attester must document the legal or policy basis for the assigned bucket.

### Minimum floor by value

- `NONE`: used when no qualifying classification has been established.
- `RETAIL_QUALIFIED`: attester has determined the investor satisfies a defined retail-upgrade or knowledge/experience threshold recognized by the relevant regime or issuer policy.
- `ACCREDITED`: attester has determined the investor satisfies a legal or policy test materially equivalent to accredited-investor status.
- `QUALIFIED_PURCHASER`: attester has determined the investor satisfies a higher-threshold legal or policy test materially equivalent to qualified-purchaser status.
- `INSTITUTIONAL`: attester has determined the subject is an institution / entity category eligible for institutional treatment under the relevant regime or issuer policy.

**Cross-jurisdiction equivalence (v0.1)**

This is the most important semantic bridge in Schema 1.

| Shibui value | US reference | EU reference | Notes |
|---|---|---|---|
| `RETAIL_QUALIFIED` | No exact federal single label; issuer-specific qualified retail treatment may apply | Retail client that has been validly treated under a narrower qualified-access regime | This bucket is intentionally narrow and should be used cautiously. |
| `ACCREDITED` | SEC Rule 501 accredited investor | Often closest operationally to a professional-client style non-retail access outcome, but not legally identical | Treat as a practical access bucket, not a claim of doctrinal identity. |
| `QUALIFIED_PURCHASER` | US qualified purchaser | No direct MiFID II equivalent | Higher-threshold bucket than `ACCREDITED`. |
| `INSTITUTIONAL` | Institutional account / entity class depending on regime | Professional client per se / eligible institutional category depending on use case | Issuers may still narrow this with policy controls. |

**On-chain consumers**

- `AccreditationPolicy`: issuer-configured allow-set
- `ProfessionalInvestorPolicy`: `accreditationType >= RETAIL_QUALIFIED`
- `InstitutionalInvestorPolicy`: `accreditationType == INSTITUTIONAL`

**Refresh and revocation**

Refresh when the classification basis expires, supporting documents age out, or the subject's status changes.

**Privacy notes**

Only the resulting bucket is public. Net worth, income, portfolio size, or entity filing details stay off-chain.

---

## Field 7 — `countryCode`

**Definition**

The country code the attester assigns to the identity for Shibui country-based policy checks.

**Master source**

ISO 3166-1 numeric.

**Allowed values**

- numeric country codes from ISO 3166-1 numeric
- example: `840` = United States

**Semantic rule**

In v0.1, this field should be interpreted as the **primary country classification used by the attester for eligibility gating**. If the attester uses residence, incorporation, domicile, or another primary country concept, that concept must be documented in the provider's conformance profile.

**Minimum evidence threshold**

The attester must have documentary or registry evidence supporting the assigned country classification appropriate to the subject type.

Examples:

- natural person: residence or equivalent compliance country evidence
- entity: incorporation / registration / principal jurisdiction evidence, as applicable to the attester's regime

**Cross-jurisdiction equivalence**

The code values themselves are globally standardized; the remaining variability is what country attribute the provider chose to encode. That ambiguity should be disclosed in the provider conformance profile until Shibui introduces a more explicit jurisdiction field model.

**On-chain consumer**

`CountryAllowListPolicy` compares the numeric code against an issuer-managed allow-list or block-list.

**Refresh and revocation**

Refresh when the underlying controlling country fact changes.

**Privacy notes**

This field reveals only a country code, not address details.

---

## Field 8 — `expirationTimestamp`

**Definition**

The data-level freshness deadline for the eligibility payload.

**Master source**

Shibui schema and policy logic.

**Allowed values**

- `0` = no payload-level expiration
- any future Unix timestamp = last valid second for the payload

**Semantic rule**

This is the authoritative business-validity deadline inside the payload. EAS-level expiration may also exist, but Shibui policy modules independently enforce this field.

**Minimum evidence threshold**

The attester must set an expiration that matches the review cycle or validity window of the underlying checks.

Example guidance:

- annual KYC refresh -> set one-year review horizon
- event-driven institutional file with no fixed expiry -> `0` may be acceptable if the attester's process truly treats it as open-ended

**On-chain consumer**

Every Schema-1 policy enforces freshness through `TopicPolicyBase._isPayloadFresh`.

**Refresh and revocation**

Re-attest before expiry if continuity is required. Expiry should not be used as a substitute for an active negative event that requires revocation.

**Privacy notes**

No privacy concern beyond signaling the review horizon.

---

## Field 9 — `evidenceHash`

**Definition**

A `bytes32` cryptographic commitment to the off-chain evidence package supporting the attestation.

**Master source**

Shibui schema design.

**Allowed values**

- `keccak256` digest of the attester-defined evidence dossier or evidence manifest

**Semantic rule**

This field proves referential integrity, not human readability. It lets an auditor ask the attester to produce the exact supporting file set whose digest was committed on-chain.

**Minimum evidence threshold**

The attester must be able to reproduce the preimage or evidence manifest corresponding to the hash for audit, examiner, or dispute-resolution purposes.

**On-chain consumer**

None in v0.1. This field is not enforced by policy modules.

**Refresh and revocation**

Must change whenever the underlying evidence basis materially changes and a new attestation is issued.

**Privacy notes**

Raw KYC files, PII, and supporting documents must remain off-chain. The hash alone is intended to be public-safe.

---

## Field 10 — `verificationMethod`

**Definition**

The provenance class for how the attester established the relevant eligibility outcome.

**Master source**

Shibui canonical enum.

**Allowed values**

| Code | Label | Meaning |
|---:|---|---|
| 1 | `SELF_ATTESTED` | Based materially on subject self-declaration. |
| 2 | `THIRD_PARTY` | Based materially on third-party verification or provider review. |
| 3 | `PROFESSIONAL_LETTER` | Based materially on a professional attestation, opinion, or letter. |
| 4 | `BROKER_DEALER_FILE` | Based materially on records held in a broker-dealer or comparable intermediary file. |

**Minimum evidence threshold**

The selected method must reflect the dominant provenance basis used for the approval outcome.

**Semantic rule**

This field does **not** by itself make an attestation valid or invalid on-chain in v0.1. It is an audit and trust-transparency field. Future profiles or issuers may choose to require or prefer certain methods.

**Refresh and revocation**

Update whenever the provenance basis materially changes.

**Privacy notes**

This field reveals method category only, not the underlying documents or provider identity.

---

## 5.3 Topic-level semantic summary

The current production policy modules interpret Schema 1 as follows:

| Topic ID | Topic | Required semantic outcome |
|---:|---|---|
| 1 | KYC | `kycStatus = VERIFIED` and payload fresh |
| 2 | AML | `amlStatus = CLEAR` and payload fresh |
| 3 | COUNTRY | `countryCode` passes issuer policy and payload fresh |
| 7 | ACCREDITATION | `accreditationType` is in issuer allow-set and payload fresh |
| 9 | PROFESSIONAL | `accreditationType >= RETAIL_QUALIFIED` and payload fresh |
| 10 | INSTITUTIONAL | `accreditationType = INSTITUTIONAL` and payload fresh |
| 13 | SANCTIONS_CHECK | `sanctionsStatus = CLEAR` and payload fresh |
| 14 | SOURCE_OF_FUNDS | `sourceOfFundsStatus = VERIFIED` and payload fresh |

This means Shibui currently treats the Investor Eligibility schema as a **shared multi-topic envelope** rather than a one-topic/one-schema model.

---

# 6. Schema 2 — Issuer Authorization semantics

## 6.1 Schema purpose

Schema 2 expresses that a recognized authorizer is vouching for a given attester address to issue Shibui attestations for a defined set of claim topics.

It is not an investor credential. It is a governance credential that supports the trusted-attester registry.

---

## 6.2 Field catalog

## Field 1 — `issuerAddress`

**Definition**

The address being authorized to act as a Shibui attester.

**Master source**

Shibui schema and adapter logic.

**Allowed values**

- any non-zero EVM address intended to act as the attester identity in EAS

**Minimum evidence threshold**

The authorizer must have performed whatever governance or due-diligence process the issuer requires before recognizing this address as an approved attester.

**Semantic rule**

This address is the subject of the authorization. In adapter logic, the encoded `issuerAddress` must equal the `attester` being added or updated.

**On-chain consumer**

`EASTrustedIssuersAdapter._validateIssuerAuth` enforces equality between the encoded value and the attester under consideration.

**Refresh and revocation**

Re-issue or revoke if the provider rotates keys, changes attestation address, or loses authorization.

---

## Field 2 — `authorizedTopics`

**Definition**

The set of Shibui claim topics for which the authorized attester may be trusted.

**Master source**

Shibui / ONCHAINID-style topic mapping used in current ERC-3643 practice.

**Allowed values**

An array of topic IDs, including in current Shibui production scope:

- `1` KYC
- `2` AML
- `3` COUNTRY
- `7` ACCREDITATION
- `9` PROFESSIONAL
- `10` INSTITUTIONAL
- `13` SANCTIONS_CHECK
- `14` SOURCE_OF_FUNDS

**Minimum evidence threshold**

The authorizer must have decided that the attester is approved to produce attestations for each listed topic.

**Semantic rule**

This is an authorization **scope**, not merely a description. The adapter requires the topics requested in `addTrustedAttester` / `updateAttesterTopics` to be a subset of this array.

**On-chain consumer**

`EASTrustedIssuersAdapter._validateIssuerAuth` enforces subset coverage.

**Refresh and revocation**

Re-issue or revoke when the attester's approved scope expands, narrows, or is withdrawn.

---

## Field 3 — `issuerName`

**Definition**

Human-readable display name for the authorized attester.

**Master source**

Shibui schema design.

**Allowed values**

- free-text string

**Minimum evidence threshold**

The value should identify the provider or authorized attester in a way that is intelligible to auditors and operators.

**Semantic rule**

Informative only. No live contract logic depends on this field.

**On-chain consumer**

None.

**Refresh and revocation**

Update if the provider branding or legal name materially changes.

**Privacy notes**

This field is intended to be public.

---

## 6.3 Authorization workflow semantics

A Schema-2 record means:

1. the attestation was written by an address permitted by `TrustedIssuerResolver`;
2. that writer is therefore a recognized authorizer at the time of issuance;
3. the record names a specific attester address;
4. the record scopes which topics that attester may be trusted for;
5. the adapter may then use the attestation UID as cryptographic evidence when changing trust state.

In plain English: **Schema 2 is the bridge between governance approval and machine-enforced attester trust.**

---

# 7. Open issues for v0.2+

This first version is intentionally practical and close to the live code. It still leaves open design questions:

1. **Country ambiguity.** `countryCode` does not yet distinguish residence, domicile, tax residence, incorporation, or formation.
2. **Sanctions coverage ambiguity.** `sanctionsStatus` does not yet encode which sanctions universe was screened.
3. **Accreditation equivalence needs hardening.** The `accreditationType` bridge is useful, but future versions should add fuller jurisdiction tables and examples.
4. **Verification provenance is coarse.** `verificationMethod` is audit-friendly but not rich enough for all institutional workflows.
5. **Entity / natural-person split.** Schema 1 uses a unified model; some future use cases may require explicit subject-type semantics.

---

# 8. Recommended next step

If this direction is right, the best v0.2 move is **not** to touch the live schemas yet. It is to add a second document:

- `docs/schemas/shibui-conformance-profiles.md`

That document would let specific providers state, for example:

- what `countryCode` means in their workflow,
- which sanctions lists they cover,
- what evidence package feeds `evidenceHash`,
- what legal test they use for each `accreditationType` bucket.

That gets Shibui much closer to the charter's goal of provider interoperability without prematurely forcing a schema migration.

---

## Appendix A — Canonical implementation references

- [`script/RegisterSchemas.s.sol`](../../script/RegisterSchemas.s.sol)
- [`docs/schemas/schema-definitions.md`](schema-definitions.md)
- [`contracts/policies/TopicPolicyBase.sol`](../../contracts/policies/TopicPolicyBase.sol)
- [`contracts/policies/KYCStatusPolicy.sol`](../../contracts/policies/KYCStatusPolicy.sol)
- [`contracts/policies/AMLPolicy.sol`](../../contracts/policies/AMLPolicy.sol)
- [`contracts/policies/SanctionsPolicy.sol`](../../contracts/policies/SanctionsPolicy.sol)
- [`contracts/policies/SourceOfFundsPolicy.sol`](../../contracts/policies/SourceOfFundsPolicy.sol)
- [`contracts/policies/AccreditationPolicy.sol`](../../contracts/policies/AccreditationPolicy.sol)
- [`contracts/policies/ProfessionalInvestorPolicy.sol`](../../contracts/policies/ProfessionalInvestorPolicy.sol)
- [`contracts/policies/InstitutionalInvestorPolicy.sol`](../../contracts/policies/InstitutionalInvestorPolicy.sol)
- [`contracts/policies/CountryAllowListPolicy.sol`](../../contracts/policies/CountryAllowListPolicy.sol)
- [`contracts/resolvers/TrustedIssuerResolver.sol`](../../contracts/resolvers/TrustedIssuerResolver.sol)
- [`contracts/EASTrustedIssuersAdapter.sol`](../../contracts/EASTrustedIssuersAdapter.sol)
