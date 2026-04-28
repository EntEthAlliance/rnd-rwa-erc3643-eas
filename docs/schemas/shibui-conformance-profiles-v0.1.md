# Shibui Conformance Profiles v0.1

> **Status:** EEA working draft
> **Document class:** Informative conformance-profile reference
> **Purpose:** Illustrative provider / jurisdiction mappings showing how real-world onboarding and compliance programs can bind their operating model to the two live Shibui schemas.
> **Non-endorsement:** Inclusion in this document does **not** constitute EEA approval, certification, ranking, or commercial endorsement.
> **Relationship to the Semantics Catalog:** This document applies [`shibui-semantics-catalog-v0.1.md`](./shibui-semantics-catalog-v0.1.md) to concrete operating models. The catalog defines what values mean. A conformance profile explains how a given provider or jurisdictional workflow populates those values in practice.

---

## 1. Why conformance profiles exist

The Shibui schemas are intentionally compact. That keeps the on-chain model stable, but it also means some operational meaning sits outside the raw bytes.

Examples:

- what does `countryCode` represent for a specific provider: residence, domicile, incorporation, or another country attribute?
- what sanctions lists are actually covered when a provider asserts `sanctionsStatus = CLEAR`?
- what evidence package was committed into `evidenceHash`?
- what legal test did the provider apply before setting `accreditationType = ACCREDITED`?

A conformance profile answers those questions for a specific provider / jurisdiction combination without forcing a schema migration.

---

## 2. Structure of a Shibui conformance profile

Each profile in this draft follows the same structure:

1. **Profile scope** — provider, jurisdiction, and onboarding context.
2. **Schema coverage** — whether the profile populates Schema 1, Schema 2, or both.
3. **Field interpretation** — how the provider/jurisdiction interprets the live fields.
4. **Evidence floor** — what minimum evidence or process is assumed.
5. **Known gaps / issuer cautions** — where additional bilateral diligence may still be required.

---

## 3. Profile A — Parallel Markets / United States private-offering workflow

### 3.1 Scope

**Provider:** Parallel Markets  
**Jurisdictional focus:** United States  
**Representative use case:** Reg D / Rule 506(c) private offerings, including accredited-investor onboarding and institutional onboarding.

### 3.2 Public-source basis

Public Parallel Markets materials describe:

- white-glove onboarding and KYC services,
- corporate onboarding / KYB workflows,
- 506(c) accreditation services,
- support for both individuals and institutions.

This profile uses those public claims as the basis for an illustrative Shibui mapping. It is **not** a statement that Parallel Markets has adopted Shibui or agreed to this profile.

### 3.3 Schema coverage

- **Schema 1 — Investor Eligibility:** yes
- **Schema 2 — Issuer Authorization:** only if the issuer separately authorizes Parallel Markets' attester address under Shibui governance

### 3.4 Recommended Schema-1 interpretation

| Field | Recommended interpretation in this profile |
|---|---|
| `identity` | ERC-3643 identity address corresponding to the onboarded investor or entity |
| `kycStatus` | KYC outcome after Parallel Markets identity / onboarding review |
| `amlStatus` | AML outcome for the onboarding context |
| `sanctionsStatus` | sanctions-screening outcome under the provider's applied screening perimeter |
| `sourceOfFundsStatus` | set only where the offering / issuer requires source-of-funds verification and the provider has completed that review |
| `accreditationType` | US investor-category outcome, especially `ACCREDITED`, `QUALIFIED_PURCHASER`, or `INSTITUTIONAL` where supported by the workflow |
| `countryCode` | primary jurisdiction used for offering eligibility, typically residence for individuals or organization jurisdiction for entities; this should be disclosed explicitly to issuers |
| `expirationTimestamp` | review horizon aligned with the offering's refresh standard |
| `evidenceHash` | commitment to the provider-held onboarding / accreditation file set |
| `verificationMethod` | typically `THIRD_PARTY`; `PROFESSIONAL_LETTER` where classification materially depends on a professional attestation |

### 3.5 Topic-by-topic mapping

| Shibui topic | Practical outcome for this profile |
|---|---|
| KYC (1) | available |
| AML (2) | available where provider AML review is in scope |
| COUNTRY (3) | available |
| ACCREDITATION (7) | strong fit for US private offerings |
| PROFESSIONAL (9) | not the core US label; should be used only if the issuer explicitly accepts the mapped outcome |
| INSTITUTIONAL (10) | available for institutional onboarding flows |
| SANCTIONS_CHECK (13) | available where screening is in scope |
| SOURCE_OF_FUNDS (14) | offering-specific; should not be assumed universally |

### 3.6 Evidence floor

At minimum, an issuer relying on this profile should expect the provider workflow to include:

- subject identification and onboarding review,
- documentary or workflow-based accredited-investor determination for Rule 506(c)-style cases where applicable,
- beneficial-owner capture for entity onboarding where required,
- sanctions screening,
- retention of underlying evidence off-chain with `evidenceHash` committing to the review set.

### 3.7 Recommended enum use

| Use case | Suggested `accreditationType` |
|---|---|
| No qualifying US investor determination completed | `NONE` |
| US accredited investor | `ACCREDITED` |
| US qualified purchaser | `QUALIFIED_PURCHASER` |
| Institutional entity treated as institutional investor | `INSTITUTIONAL` |

### 3.8 Issuer cautions

1. `countryCode` must be clarified in the issuer-provider onboarding pack.
2. `sourceOfFundsStatus` should be treated as optional unless explicitly contracted.
3. `PROFESSIONAL` under MiFID-style logic should not be inferred from US accreditation without issuer approval.

---

## 4. Profile B — Sumsub / global KYC-AML screening workflow with EU distribution context

### 4.1 Scope

**Provider:** Sumsub  
**Jurisdictional focus:** multi-jurisdiction onboarding, illustrated here with an EU distribution context  
**Representative use case:** global user verification, business verification, transaction monitoring, and compliance workflows feeding a tokenized-asset onboarding stack.

### 4.2 Public-source basis

Public Sumsub materials describe a configurable identity-verification platform offering user verification, business verification, transaction monitoring, and fraud/compliance tooling for fintech, trading, and crypto workflows.

This profile treats Sumsub as a representative global verification provider whose outputs may populate Schema 1 for EU-oriented token distribution flows.

### 4.3 Schema coverage

- **Schema 1 — Investor Eligibility:** yes
- **Schema 2 — Issuer Authorization:** only if the issuer separately authorizes the provider attester address under Shibui governance

### 4.4 Recommended Schema-1 interpretation

| Field | Recommended interpretation in this profile |
|---|---|
| `identity` | ERC-3643 identity address for the natural person or entity being onboarded |
| `kycStatus` | outcome of the provider's configured KYC program |
| `amlStatus` | outcome of the provider's AML / risk review flow where configured |
| `sanctionsStatus` | outcome of sanctions and watchlist screening as configured for the issuer |
| `sourceOfFundsStatus` | set only if the configured workflow includes source-of-funds review |
| `accreditationType` | EU distribution bucket mapped by the issuer from professional / institutional treatment criteria |
| `countryCode` | country attribute configured by the issuer-provider workflow; this must be disclosed explicitly |
| `expirationTimestamp` | refresh horizon set by the issuer's review policy |
| `evidenceHash` | commitment to the provider-held case package or evidence manifest |
| `verificationMethod` | ordinarily `THIRD_PARTY` |

### 4.5 MiFID-oriented interpretation guidance

Under MiFID II Annex II, a professional client is a client with the experience, knowledge, and expertise to make investment decisions and properly assess the risks, including specified per se professional categories and large undertakings meeting size tests.

For Shibui purposes, an issuer using a Sumsub-based workflow in an EU distribution context may apply the following guidance:

| EU-facing outcome | Suggested Shibui bucket |
|---|---|
| retail client with no professional treatment | `NONE` or issuer-specific `RETAIL_QUALIFIED` only if an explicit qualified-retail regime is in play |
| professional client | `RETAIL_QUALIFIED` or `ACCREDITED`, depending on the issuer's adopted equivalence policy; this choice must be documented in the issuer conformance appendix |
| per se institutional / entity class | `INSTITUTIONAL` |

### 4.6 Topic-by-topic mapping

| Shibui topic | Practical outcome for this profile |
|---|---|
| KYC (1) | strong fit |
| AML (2) | strong fit |
| COUNTRY (3) | strong fit |
| ACCREDITATION (7) | only where issuer has defined a clear EU-to-Shibui equivalence rule |
| PROFESSIONAL (9) | strong fit when issuer maps MiFID professional treatment into Shibui |
| INSTITUTIONAL (10) | strong fit for entity and institutional classifications |
| SANCTIONS_CHECK (13) | strong fit |
| SOURCE_OF_FUNDS (14) | configurable; do not assume by default |

### 4.7 Evidence floor

An issuer relying on this profile should expect at least:

- configured KYC verification,
- sanctions / watchlist screening,
- AML or risk checks where required by the use case,
- explicit issuer policy for how MiFID-style classification maps into `accreditationType`,
- off-chain evidence retention sufficient to reproduce the `evidenceHash` preimage.

### 4.8 Issuer cautions

1. This profile is operationally strong for KYC / AML / sanctions, but **investor-category mapping still belongs to the issuer policy layer**.
2. `ACCREDITATION` and `PROFESSIONAL` must not be treated as automatically interchangeable across US and EU regimes.
3. Any issuer using this profile should publish a short appendix stating exactly how it maps MiFID professional-client categories into Shibui enum values.

---

## 5. Profile C — Jurisdiction profile for the United States / Rule 501 accredited-investor determinations

### 5.1 Scope

**Profile type:** jurisdiction-first profile  
**Jurisdiction:** United States  
**Representative legal basis:** Regulation D / Rule 501 accredited-investor framework

### 5.2 Public-source basis

Investor.gov describes accredited investors as investors eligible to participate in offerings relying on exemptions such as Rule 506 of Regulation D, with the term defined in Rule 501 of Regulation D.

### 5.3 Schema-1 implications

This jurisdictional profile is not tied to a single provider. It defines how any provider should map US accredited-investor outcomes into Shibui.

| US legal / market outcome | Recommended Shibui value |
|---|---|
| investor is not established as accredited | `NONE` |
| investor meets Rule 501 accredited-investor criteria | `ACCREDITED` |
| investor meets qualified-purchaser threshold | `QUALIFIED_PURCHASER` |
| regulated institution / entity eligible under issuer policy for institutional treatment | `INSTITUTIONAL` |

### 5.4 Minimum evidence floor

For `ACCREDITED`, the provider or issuer-controlled review process should document the basis for the determination under the applicable US rule set.

For `QUALIFIED_PURCHASER`, the provider or issuer-controlled review process should document the higher-threshold basis separately; it must not be inferred automatically from ordinary accredited-investor status.

### 5.5 Issuer cautions

1. US `ACCREDITED` and EU `PROFESSIONAL` are not identical legal categories.
2. A provider should disclose whether its `verificationMethod` relied on third-party review, professional letters, broker-dealer files, or another process.
3. Rule-specific offering conditions still sit outside Shibui and must be handled by the issuer.

---

## 6. Profile D — Jurisdiction profile for the European Union / MiFID II professional-client treatment

### 6.1 Scope

**Profile type:** jurisdiction-first profile  
**Jurisdiction:** European Union  
**Representative legal basis:** MiFID II Annex II professional-client framework

### 6.2 Public-source basis

ESMA's MiFID II Annex II materials describe professional clients as clients with the experience, knowledge, and expertise to make their own investment decisions and properly assess risks, including specified regulated entities, large undertakings meeting size thresholds, governments/central banks, and other institutional investors.

### 6.3 Schema-1 implications

Shibui does not yet have a dedicated `professionalClientType` enum. In the current schema, the issuer must publish an equivalence rule.

**Recommended default mapping for EU-facing Shibui deployments:**

| EU classification | Recommended Shibui value |
|---|---|
| retail client | `NONE` |
| professional client | `RETAIL_QUALIFIED` for conservative mapping, or `ACCREDITED` only if the issuer explicitly adopts that equivalence |
| large undertaking / institutional investor / per se professional entity | `INSTITUTIONAL` where issuer policy supports that treatment |

### 6.4 Minimum evidence floor

The provider or issuer workflow should document the basis on which the client was treated as professional, including per se category or opt-up treatment where relevant.

### 6.5 Issuer cautions

1. The current Shibui schema compresses multiple legal ideas into a single `accreditationType` field. Issuers should publish their chosen MiFID-to-Shibui mapping.
2. If a deployment depends heavily on EU distribution logic, a future schema revision may warrant a more explicit professional-client field.

---

## 7. How issuers should use these profiles

The practical recommendation for a Shibui deployment is:

1. adopt the Semantics Catalog as the baseline reference;
2. attach one short provider profile per approved attester;
3. attach one short jurisdiction appendix per target market;
4. require any trusted attester to disclose:
   - country semantics,
   - sanctions-list coverage,
   - evidence-hash construction rule,
   - investor-classification mapping rule,
   - refresh / revocation cadence.

This gives issuers a usable interoperability layer without changing the live schema strings.

---

## 8. Recommended next document

If the EEA wants to operationalize this further, the next useful artifact is a one-page checklist template for attesters:

- legal entity name
- attester address
- Schema-2 authorization UID
- covered jurisdictions
- covered topic IDs
- country-code interpretation
- sanctions coverage statement
- accreditation / professional mapping statement
- evidenceHash construction statement
- refresh schedule

That would convert this draft from informative examples into a reusable onboarding packet.

---

## Appendix A — Public references used in this draft

- Parallel Markets public site: white-glove onboarding, KYC, KYB, and 506(c) accreditation services
- Sumsub public site: user verification, business verification, transaction monitoring, and compliance workflows
- Investor.gov: accredited investor overview referencing Regulation D / Rule 501
- ESMA MiFID II Annex II: professional-client categories and criteria
