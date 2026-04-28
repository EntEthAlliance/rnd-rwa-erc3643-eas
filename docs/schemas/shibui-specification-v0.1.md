# Shibui Specification v0.1

> **Status:** EEA working draft  
> **Document class:** Specification draft  
> **Purpose:** Define the two live Shibui EAS schemas, their intended semantics, and the practical interpretation needed for issuer and provider interoperability.  
> **Scope:** This document covers schema structure, field meaning, enum meaning, minimum evidence thresholds, current on-chain policy interpretation, and illustrative provider / jurisdiction mapping guidance.  
> **Non-goal:** This document does **not** modify the live schema strings registered by [`script/RegisterSchemas.s.sol`](../../script/RegisterSchemas.s.sol). If this document and the implementation diverge, the implementation remains authoritative for live protocol behavior.

---

## 1. Overview

Shibui uses Ethereum Attestation Service (EAS) to express investor-eligibility and attester-authorization data for ERC-3643 integrations.

The architecture has three layers:

1. **Schema strings** — define the bytes stored in EAS attestations.  
2. **Contracts and policies** — define what is accepted on-chain.  
3. **This specification** — defines what those bytes are intended to mean in real-world compliance and onboarding terms.

The practical goal is interoperability. A token issuer should be able to read an attestation from one provider and interpret it in a way that is consistent with another provider using the same Shibui schema.

---

## 2. Editorial rules

The following rules apply throughout this draft:

1. **Code authority wins.** Field order, enum values, and live policy predicates are taken from the current implementation.  
2. **Append-only semantics.** Existing values must never be reassigned a different meaning.  
3. **Minimum-evidence floor.** This specification defines the minimum basis for asserting a value. Providers may exceed that floor.  
4. **Privacy by commitment.** Shibui carries outcomes and an evidence commitment, not raw KYC files or raw PII.  
5. **Equivalence where necessary.** Some legal categories do not map perfectly across jurisdictions. Where exact identity is not possible, this specification defines the intended equivalence class and flags where issuer policy is still required.

---

## 3. Normative and reference sources

### External reference sources

This draft relies on the following external sources as the main policy and terminology anchors:

- **FATF Recommendation 10** — customer due diligence baseline for KYC and source-of-funds expectations  
- **ISO 3166-1 numeric** — country-code reference  
- **SEC Regulation D / Rule 501** — US accredited-investor reference  
- **US qualified purchaser framework** — higher-threshold US investor-category reference  
- **MiFID II Annex II** — EU professional-client reference  
- **OFAC and equivalent sanctions authorities** — sanctions-screening reference

### Shibui implementation references

The implementation references for this specification are:

- [`script/RegisterSchemas.s.sol`](../../script/RegisterSchemas.s.sol)  
- [`docs/schemas/schema-definitions.md`](./schema-definitions.md)  
- [`contracts/policies/TopicPolicyBase.sol`](../../contracts/policies/TopicPolicyBase.sol)  
- concrete policy modules under [`contracts/policies/`](../../contracts/policies/)  
- [`contracts/resolvers/TrustedIssuerResolver.sol`](../../contracts/resolvers/TrustedIssuerResolver.sol)  
- [`contracts/EASTrustedIssuersAdapter.sol`](../../contracts/EASTrustedIssuersAdapter.sol)

When this document refers to a **Shibui canonical enum**, it means the enum is currently defined by the live Shibui implementation rather than imported verbatim from a third-party code list.

---

## 4. The two live Shibui schemas

### 4.1 Schema 1 — Investor Eligibility

**Exact live schema string**

```text
address identity,uint8 kycStatus,uint8 amlStatus,uint8 sanctionsStatus,uint8 sourceOfFundsStatus,uint8 accreditationType,uint16 countryCode,uint64 expirationTimestamp,bytes32 evidenceHash,uint8 verificationMethod
```

**Role in protocol**

Schema 1 is the single canonical eligibility payload decoded by the current Shibui topic-policy modules.

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

### 4.2 Schema 2 — Issuer Authorization

**Exact live schema string**

```text
address issuerAddress,uint256[] authorizedTopics,string issuerName
```

**Role in protocol**

Schema 2 is the governance and audit-trail schema used to authorize trusted attesters for specific Shibui claim topics.

**Fields**

1. `issuerAddress`  
2. `authorizedTopics`  
3. `issuerName`

---

## 5. Schema 1 — Investor Eligibility

### 5.1 Purpose

Schema 1 expresses the current compliance posture of a specific ERC-3643 identity address. It is not a raw identity record. It is a compact eligibility payload used by Shibui to answer questions such as:

- is this identity currently KYC-verified?
- is this identity clear from AML and sanctions checks?
- is this identity eligible under country restrictions?
- what investor-category bucket does this identity satisfy?

A single Schema-1 attestation may satisfy multiple claim topics because regulated onboarding commonly produces all of these outcomes together.

### 5.2 Field definitions

#### 5.2.1 `identity`

**Definition**  
The ERC-3643 identity address to which the attestation applies. This is the canonical subject of the eligibility record in Shibui. It is not a wallet address.

**Minimum evidence threshold**  
Before issuing the attestation, the attester must have resolved the subject to the identity address recognized by the token / issuer stack as the compliance subject.

**Operational notes**

- The EAS attestation recipient and the encoded `identity` field should refer to the same underlying subject.  
- Wallets linked through `EASIdentityProxy` inherit the eligibility associated with this identity.

---

#### 5.2.2 `kycStatus`

**Definition**  
The attester's current KYC outcome for the identity.

**Allowed values**

| Code | Label | Meaning |
|---:|---|---|
| 0 | `NOT_VERIFIED` | Required KYC review has not been completed to the attester's standard. |
| 1 | `VERIFIED` | Identity has passed the attester's KYC process and remains current. |
| 2 | `EXPIRED` | KYC was previously completed but is now out of date and must be refreshed. |
| 3 | `REVOKED` | KYC approval has been affirmatively withdrawn. |
| 4 | `PENDING` | Review has started but final approval has not yet been granted. |

**Minimum evidence threshold for `VERIFIED`**

At minimum, the attester should have:

- identified the customer subject;  
- verified identity using reliable, independent source material appropriate to the subject type;  
- identified beneficial ownership where applicable;  
- understood the purpose and nature of the relationship to the extent required for onboarding;  
- completed review without unresolved blocking issues.

**Interpretation note**  
`VERIFIED` is a jurisdiction-level eligibility outcome. It does not imply that every jurisdiction used the same onboarding steps.

---

#### 5.2.3 `amlStatus`

**Definition**  
The attester's current AML outcome for the identity.

**Allowed values**

| Code | Label | Meaning |
|---:|---|---|
| 0 | `CLEAR` | No unresolved AML issue blocks use of the identity for the attester's intended regulated activity. |
| 1 | `FLAGGED` | The identity is subject to an unresolved AML issue or adverse finding that blocks approval. |

**Minimum evidence threshold**  
To assert `CLEAR`, the attester must have completed AML screening or review appropriate to its regime with no unresolved blocking finding.

---

#### 5.2.4 `sanctionsStatus`

**Definition**  
The sanctions-screening outcome for the identity against the sanctions universe the attester applies.

**Allowed values**

| Code | Label | Meaning |
|---:|---|---|
| 0 | `CLEAR` | No unresolved sanctions match blocks the identity under the attester's applicable sanctions coverage. |
| 1 | `HIT` | A sanctions match or unresolved positive screening result blocks approval. |

**Minimum evidence threshold**  
To assert `CLEAR`, the attester must have screened the identity against the sanctions lists it is required or claims to cover and resolved candidate matches to a non-blocking outcome.

**Interpretation note**  
This field is outcome-based. In v0.1, it does not separately encode which sanctions lists were checked. That disclosure belongs in provider conformance notes or issuer onboarding materials.

---

#### 5.2.5 `sourceOfFundsStatus`

**Definition**  
Whether the attester has verified source of funds sufficiently for the use case.

**Allowed values**

| Code | Label | Meaning |
|---:|---|---|
| 0 | `NOT_VERIFIED` | Source of funds has not been verified to the attester's required standard. |
| 1 | `VERIFIED` | Source of funds has been reviewed and accepted to the attester's required standard. |

**Minimum evidence threshold**  
To assert `VERIFIED`, the attester must have obtained and reviewed documentation or other evidence sufficient to support the claimed lawful source of funds for the relevant onboarding context.

---

#### 5.2.6 `accreditationType`

**Definition**  
The investor-category bucket the attester determined the identity satisfies.

**Allowed values**

| Code | Label | Meaning |
|---:|---|---|
| 0 | `NONE` | No qualifying investor-category outcome has been established. |
| 1 | `RETAIL_QUALIFIED` | A retail participant who qualifies under a regime-specific test short of full institutional categorization. |
| 2 | `ACCREDITED` | A non-retail investor outcome broadly equivalent to US accredited-investor treatment. |
| 3 | `QUALIFIED_PURCHASER` | A higher-threshold investor outcome broadly equivalent to US qualified-purchaser treatment. |
| 4 | `INSTITUTIONAL` | An institutional or entity-class investor outcome appropriate for institutional-only gating. |

**Minimum evidence threshold**  
The attester must document the legal or policy basis for the assigned bucket.

**Cross-jurisdiction interpretation**

| Shibui value | Closest US reference | Closest EU reference | Note |
|---|---|---|---|
| `RETAIL_QUALIFIED` | no single federal label | narrower qualified-retail / opt-up style treatment where applicable | use carefully |
| `ACCREDITED` | Rule 501 accredited investor | sometimes used as an issuer-defined equivalence to a non-retail access category | not legally identical |
| `QUALIFIED_PURCHASER` | qualified purchaser | no direct MiFID II equivalent | higher threshold |
| `INSTITUTIONAL` | institutional account / eligible entity class | institutional / per se professional entity class | may still require issuer narrowing |

This is the field where issuer policy matters most. The schema intentionally compresses several jurisdiction-specific legal concepts into one portable eligibility field.

##### Tier and regime clarification

`accreditationType` is best understood as a **tier indicator**, not a **regime tag**.

That means:

- the enum signals the level or class of investor treatment being asserted;  
- it does **not** by itself identify the legal regime under which that treatment was determined;  
- regime context must be supplied by the issuer policy, provider conformance materials, or the off-chain dossier referenced by `evidenceHash`.

This distinction matters because the enum intentionally mixes labels that come from different regulatory traditions. For example:

- `ACCREDITED` is anchored in US private-offering practice;  
- `RETAIL_QUALIFIED` is better read as a lower-tier non-institutional qualification bucket that may arise in EU or issuer-defined contexts;  
- `QUALIFIED_PURCHASER` is a higher-threshold US category;  
- `INSTITUTIONAL` is a portable top-tier bucket often interpreted through entity or per se professional treatment.

Current Shibui policy modules are therefore the layer that applies regime context in practice:

- `AccreditationPolicy` interprets the enum through an issuer-configured allow-set;  
- `ProfessionalInvestorPolicy` interprets the enum as a threshold rule for professional treatment;  
- `InstitutionalInvestorPolicy` interprets the enum as an institutional-only threshold.

In other words, the enum provides the portable classification tier, while policy modules and issuer configuration provide the legal and commercial meaning for a specific deployment.

---

#### 5.2.7 `countryCode`

**Definition**  
The country code the attester assigns to the identity for Shibui country-based policy checks.

**Reference source**  
ISO 3166-1 numeric.

**Interpretation note**  
In v0.1, this should be read as the provider's primary country classification for eligibility gating. That may be residence, domicile, incorporation, or another country attribute depending on the provider workflow. That specific interpretation should be disclosed by the provider or issuer.

---

#### 5.2.8 `expirationTimestamp`

**Definition**  
The data-level freshness deadline for the eligibility payload.

**Allowed values**

- `0` = no payload-level expiration  
- future Unix timestamp = last valid time for the payload

**Interpretation note**  
This is the business-validity deadline inside the payload. EAS-level expiration may also exist, but Shibui enforces this field independently through its policy base.

---

#### 5.2.9 `evidenceHash`

**Definition**  
A `bytes32` commitment to the off-chain evidence package supporting the attestation.

**Interpretation note**  
This is a referential-integrity field, not a human-readable field. It lets an auditor ask the attester to produce the exact file set whose digest was committed on-chain.

---

#### 5.2.10 `verificationMethod`

**Definition**  
The provenance class for how the attester established the relevant eligibility outcome.

**Allowed values**

| Code | Label | Meaning |
|---:|---|---|
| 1 | `SELF_ATTESTED` | Based materially on subject self-declaration. |
| 2 | `THIRD_PARTY` | Based materially on third-party verification or provider review. |
| 3 | `PROFESSIONAL_LETTER` | Based materially on a professional attestation, opinion, or letter. |
| 4 | `BROKER_DEALER_FILE` | Based materially on records held in a broker-dealer or similar intermediary file. |

**Interpretation note**  
In v0.1 this field is informative. It improves auditability and trust transparency, but current topic-policy logic does not enforce it.

### 5.3 Current topic-policy interpretation

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

This means Shibui currently treats Schema 1 as a shared multi-topic eligibility envelope rather than a one-topic / one-schema design.

---

## 6. Schema 2 — Issuer Authorization

### 6.1 Purpose

Schema 2 expresses that a recognized authorizer is vouching for a given attester address to issue Shibui attestations for a defined set of claim topics.

It is not an investor credential. It is a governance credential supporting the trusted-attester registry.

### 6.2 Field definitions

#### 6.2.1 `issuerAddress`

**Definition**  
The address being authorized to act as a Shibui attester.

**Interpretation note**  
In adapter logic, the encoded `issuerAddress` must equal the attester address being added or updated.

---

#### 6.2.2 `authorizedTopics`

**Definition**  
The set of Shibui claim topics for which the authorized attester may be trusted.

**Current production scope**

- `1` KYC  
- `2` AML  
- `3` COUNTRY  
- `7` ACCREDITATION  
- `9` PROFESSIONAL  
- `10` INSTITUTIONAL  
- `13` SANCTIONS_CHECK  
- `14` SOURCE_OF_FUNDS

**Interpretation note**  
This is an authorization scope, not merely a description. The adapter requires any requested attester topics to be a subset of this array.

---

#### 6.2.3 `issuerName`

**Definition**  
Human-readable display name for the authorized attester.

**Interpretation note**  
This field is informative only. It is intended for legibility and audit traceability.

### 6.2.4 Attester Identity Anchors

This subsection is **non-normative**. It does not change the live schema string.

Schema 2's `issuerName` field is free text today. In production, however, attesters are typically regulated legal entities whose identity should be verifiable against an authoritative registry or identity system. Different jurisdictions and ecosystems rely on different identity anchors. The purpose of this subsection is to give implementers a consistent way to declare **which identity system anchors a given attester**, without forcing one universal choice.

#### Anchor model

Shibui treats attester identity anchors as **pluggable**.

- **LEI / vLEI** is the recommended default for global institutional use.  
- Other anchors may also be legitimate and legally meaningful in their own context, including:  
  - eIDAS-qualified trust or supervisory identifiers,  
  - national regulator license numbers,  
  - W3C DIDs,  
  - jurisdiction-specific public registries.

The specification therefore recognizes plurality. It does not require a single mandatory anchor type.

#### Tagging convention

Because `issuerName` is free text, any anchor included there SHOULD be machine-parseable and unambiguous.

Recommended direction:

- a short prefix tag, followed by `:`, followed by the anchor value  
- human-readable entity name may appear before or after the tagged anchor, provided the tagged component remains unambiguous

Illustrative examples:

- `Acme KYC Services | lei:5493001KJTIIGC8Y1R12`  
- `Acme KYC Services | vlei:5493001KJTIIGC8Y1R12`  
- `Acme KYC Services | eidas:EU-TSP-123456`  
- `Acme KYC Services | did:did:web:acme.example`  
- `Acme KYC Services | x-fca:123456`

Recognized tag families in v0.1:

- `lei:` — Legal Entity Identifier  
- `vlei:` — verifiable LEI or equivalent LEI-derived verifiable credential reference  
- `eidas:` — eIDAS-related trust or supervisory identifier  
- `did:` — W3C Decentralized Identifier  
- `x-{name}:` — implementation-defined extension tag for other anchor systems

The exact formatting around the tag is left to implementers, but the tag itself SHOULD be deterministic and easy to parse.

#### Resolution expectations

Anchor resolution is always **off-chain**. The on-chain attestation only carries the tagged identity reference.

Verifiers consuming Schema 2 SHOULD resolve anchors as follows:

- `lei:` → resolve against GLEIF or an equivalent authoritative LEI source; confirm the entity exists and is active  
- `vlei:` → resolve using the relevant vLEI verification flow or issuer trust chain anchored to the LEI ecosystem  
- `eidas:` → resolve against the relevant EU trust list, supervisory registry, or equivalent authoritative source  
- `did:` → resolve using a conformant DID resolver and validate the current DID document / method rules  
- `x-{name}:` → resolve using the documented procedure for that custom anchor family

Implementers SHOULD record the resolved legal or organizational name alongside the attester address in compliance and audit logs.

#### Lifecycle guidance

Anchor status is part of the trusted-attester review process.

Examples of lifecycle events include:

- LEI not renewed  
- regulator license revoked or suspended  
- eIDAS trust status changed  
- DID deactivated or rotated beyond recognized control

These events SHOULD be treated as off-chain trust and governance signals. They do **not** replace EAS revocation and they do **not** automatically change on-chain state by themselves. Instead, implementers should incorporate anchor-status review into the process that decides whether an attester remains approved under Schema 2 governance.

#### What the anchor does and does not do

The anchor binds an attester address to an identifiable legal or organizational entity.

It does **not**:

- authorize the attester — authorization remains governed by `authorizedTopics` and Schema 2 workflows  
- validate the factual content of investor attestations — that remains the role of Schema 1 and its policy layer  
- move resolution on-chain — verification stays off-chain in this revision

The anchor is therefore an identity-binding mechanism, not an authorization mechanism and not a truth-validation mechanism.

#### Extensibility

The recognized anchor set is open-ended. New identity systems will emerge.

To preserve interoperability, new anchor types should be introduced by:

1. defining a stable machine-readable tag;  
2. documenting the authoritative resolution method;  
3. documenting status / lifecycle expectations;  
4. documenting how the anchor maps to a legal or organizational identity.

Adding a new anchor family should not break existing implementations. Consumers that do not recognize a tag may ignore it, flag it for manual review, or treat it according to issuer policy.

#### Recommended default

For globally oriented institutional deployments, LEI / vLEI remains the recommended default because it aligns well with existing regulatory and financial-market practice. But it is a recommendation, not a mandate.

### 6.3 Operational meaning

A Schema-2 record means:

1. the attestation was written by an address permitted by `TrustedIssuerResolver`;  
2. the writer is therefore a recognized Shibui authorizer at the time of issuance;  
3. the record names a specific attester address;  
4. the record scopes which topics that attester may be trusted for;  
5. the adapter may then cite the attestation UID as cryptographic evidence when changing trust state.

In plain language: Schema 2 is the bridge between governance approval and machine-enforced attester trust.

---

## 7. Practical conformance guidance

The schemas are intentionally compact. That keeps the on-chain model stable, but it means some operational meaning still needs to be documented at the provider or issuer layer.

Examples:

- what does `countryCode` mean in a given workflow: residence, domicile, incorporation, or something else?  
- what sanctions lists are covered when `sanctionsStatus = CLEAR` is asserted?  
- what evidence package is committed into `evidenceHash`?  
- what legal test was used before setting `accreditationType = ACCREDITED` or `INSTITUTIONAL`?

For that reason, Shibui adoption should include a short conformance appendix or onboarding note per provider.

### 7.1 Recommended provider disclosure checklist

Any issuer approving a Shibui attester should ask for the following disclosures:

1. legal entity name  
2. attester address  
3. LEI or vLEI, where available  
4. covered jurisdictions  
5. covered topic IDs  
6. `countryCode` interpretation  
7. sanctions-list coverage statement  
8. accreditation / professional-classification mapping statement  
9. `evidenceHash` construction rule  
10. refresh and revocation cadence  
11. dominant `verificationMethod` usage

### 7.2 Non-normative extension fields for richer jurisdictional context

The on-chain schemas remain intentionally compact. If an issuer needs richer jurisdictional or classification detail, that information SHOULD be encoded in the off-chain dossier referenced by `evidenceHash`.

This section is non-normative. It does not change the on-chain schema. Its purpose is to prevent ecosystem fragmentation by giving implementers a common shape for extended metadata.

Typical cases where extension fields may be needed include:

- multiple relevant countries for one subject;  
- separate residence, domicile, tax residence, incorporation, or formation fields;  
- regime-specific legal classification details;  
- statute, rule, or annex citations supporting the asserted investor tier;  
- richer sanctions-screening coverage statements.

#### Recommended off-chain JSON structure

```json
{
  "subject": {
    "type": "natural_person_or_entity",
    "identityAddress": "0x..."
  },
  "jurisdiction": {
    "primaryCountryCode": 840,
    "residenceCountryCodes": [840],
    "taxResidenceCountryCodes": [840],
    "incorporationCountryCode": null,
    "domicileCountryCode": null
  },
  "classification": {
    "shibuiAccreditationType": "ACCREDITED",
    "regime": "US_REG_D_501",
    "regimeTierLabel": "accredited_investor",
    "statuteCitations": [
      "17 CFR 230.501"
    ]
  },
  "screening": {
    "sanctionsCoverage": ["OFAC", "EU"],
    "amlProgram": "provider_defined_program"
  },
  "attester": {
    "legalName": "Acme KYC Services",
    "lei": "5493001KJTIIGC8Y1R12",
    "attesterAddress": "0x..."
  },
  "evidence": {
    "verificationMethod": "THIRD_PARTY",
    "dossierVersion": "1.0",
    "createdAt": "2026-04-28T00:00:00Z"
  }
}
```

#### Interpretation guidance

- `primaryCountryCode` should match the on-chain `countryCode` when present.  
- `shibuiAccreditationType` should match the on-chain enum value.  
- `regime` and `regimeTierLabel` provide the context the on-chain enum does not carry.  
- `statuteCitations` identify the legal basis for the asserted classification where relevant.  
- `sanctionsCoverage` identifies the list universe behind a `sanctionsStatus` outcome.  
- `lei` anchors the attester to a legal entity where available.

Issuers and providers may extend this structure, but SHOULD preserve these top-level sections if they want maximum interoperability across Shibui integrations.

---

## 8. Illustrative application profiles

This section is informative. It is included to show how the specification can be applied in practice. It is not an endorsement of any provider.

### 8.1 Profile A — US private-offering workflow

**Representative provider model:** Parallel Markets-style onboarding and 506(c) accreditation workflow  
**Representative jurisdiction:** United States

**Typical fit within Shibui**

- `kycStatus` — KYC outcome after onboarding review  
- `amlStatus` — AML outcome where in scope  
- `sanctionsStatus` — sanctions screening result  
- `accreditationType` — often `ACCREDITED`, `QUALIFIED_PURCHASER`, or `INSTITUTIONAL` depending on the investor and offering  
- `verificationMethod` — often `THIRD_PARTY`, or `PROFESSIONAL_LETTER` where classification depends materially on a professional attestation

**Issuer cautions**

- `countryCode` should be clarified explicitly.  
- `sourceOfFundsStatus` should not be assumed unless the workflow includes that review.  
- `PROFESSIONAL` under MiFID-style logic should not be inferred automatically from US accreditation.

### 8.2 Profile B — Global KYC / AML screening workflow with EU distribution context

**Representative provider model:** Sumsub-style verification platform  
**Representative jurisdiction:** multi-jurisdiction, illustrated here with EU-facing token distribution

**Typical fit within Shibui**

- strong fit for `kycStatus`, `amlStatus`, `sanctionsStatus`, `countryCode`  
- `sourceOfFundsStatus` only where the workflow includes that review  
- `accreditationType` requires explicit issuer policy for how EU professional / institutional treatment maps into the Shibui enum

**Issuer cautions**

- KYC / AML / sanctions fit is stronger than investor-category mapping.  
- EU professional-client treatment and US accredited-investor treatment are not automatically interchangeable.  
- The issuer should document its chosen equivalence rule.

### 8.3 Jurisdiction note — United States

Investor.gov describes accredited investors as investors eligible to participate in offerings relying on exemptions such as Rule 506 of Regulation D, with the term defined in Rule 501 of Regulation D.

**Suggested mapping**

| US outcome | Shibui value |
|---|---|
| no qualifying determination | `NONE` |
| Rule 501 accredited investor | `ACCREDITED` |
| qualified purchaser | `QUALIFIED_PURCHASER` |
| institutional entity under issuer policy | `INSTITUTIONAL` |

### 8.4 Jurisdiction note — European Union

MiFID II Annex II describes professional clients as clients with the experience, knowledge, and expertise to make their own investment decisions and properly assess risk, including specified regulated entities, large undertakings meeting size thresholds, governments/central banks, and other institutional investors.

**Suggested mapping**

| EU classification | Shibui value |
|---|---|
| retail client | `NONE` |
| professional client | `RETAIL_QUALIFIED` for conservative mapping, or `ACCREDITED` only if the issuer explicitly adopts that equivalence |
| large undertaking / institutional / per se professional entity | `INSTITUTIONAL` where issuer policy supports that treatment |

---

## 9. What this specification does not solve yet

The current schema design is deliberately compact. That leaves some open questions for future revisions:

1. `countryCode` does not distinguish residence, domicile, tax residence, incorporation, or formation.  
2. `sanctionsStatus` does not identify the exact sanctions universe screened.  
3. `accreditationType` compresses several legal concepts into a single portable eligibility field.  
4. `verificationMethod` is useful but coarse.  
5. natural-person and entity semantics remain combined in one model.

These are future-iteration questions, not blockers for the current specification.

---

## 10. Companion implementation references

For the current live implementation, see:

- [`docs/schemas/schema-definitions.md`](./schema-definitions.md)  
- [`script/RegisterSchemas.s.sol`](../../script/RegisterSchemas.s.sol)  
- [`contracts/policies/TopicPolicyBase.sol`](../../contracts/policies/TopicPolicyBase.sol)  
- topic-policy contracts under [`contracts/policies/`](../../contracts/policies/)  
- [`contracts/resolvers/TrustedIssuerResolver.sol`](../../contracts/resolvers/TrustedIssuerResolver.sol)  
- [`contracts/EASTrustedIssuersAdapter.sol`](../../contracts/EASTrustedIssuersAdapter.sol)
