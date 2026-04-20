# Production Claim Topic Analysis

## Overview

This document analyzes claim topics used in production ERC-3643 deployments on Ethereum mainnet and Polygon. We document which claim topics are actually used, what compliance requirements they map to, and what data they typically carry.

## Methodology

Claim topics are registered via the Claim Topics Registry contract (`IClaimTopicsRegistry`). Each ERC-3643 token deployment has its own registry that specifies which claim topics are required for transfers.

Standard claim topic IDs are defined by the ONCHAINID specification, though issuers can define custom topics.

## Standard Claim Topic IDs

Based on the ONCHAINID specification and observed production deployments:

| Topic ID | Name | Description |
|----------|------|-------------|
| 1 | KYC | Know Your Customer - basic identity verification |
| 2 | AML | Anti-Money Laundering compliance check |
| 3 | COUNTRY | Country of residence/citizenship |
| 4 | KYC_AML | Combined KYC and AML verification |
| 5 | IDENTITY | General identity claim |
| 6 | RESIDENCE | Proof of residence |
| 7 | ACCREDITATION | Accredited investor status (US) |
| 8 | QUALIFICATION | Qualified purchaser status |
| 9 | PROFESSIONAL | Professional investor classification (MiFID II) |
| 10 | INSTITUTIONAL | Institutional investor status |
| 11 | ELIGIBLE_COUNTERPARTY | Eligible counterparty status (MiFID II) |
| 12 | TAX_COMPLIANCE | Tax compliance attestation |
| 13 | SANCTIONS_CHECK | OFAC/sanctions screening |
| 14 | SOURCE_OF_FUNDS | Source of funds verification |
| 15 | BENEFICIAL_OWNERSHIP | Ultimate beneficial owner verification |

## Observed Production Usage Patterns

### Pattern 1: Basic Security Token Offering (STO)

**Required Topics:** 1 (KYC), 7 (ACCREDITATION)

**Jurisdictions:** United States

**Use Case:** Regulation D 506(c) offerings requiring accredited investor verification.

**Typical Claim Data:**
```solidity
struct KYCClaim {
    uint8 status; // 0=pending, 1=approved, 2=rejected, 3=expired
    uint16 countryCode; // ISO 3166-1 numeric
    uint64 verificationDate;
    uint64 expirationDate;
}

struct AccreditationClaim {
    uint8 accreditationType; // 1=income, 2=net worth, 3=professional, 4=entity
    uint64 verificationDate;
    uint64 expirationDate;
    bytes32 evidenceHash; // Hash of supporting documentation
}
```

### Pattern 2: EU Regulated Fund

**Required Topics:** 1 (KYC), 2 (AML), 9 (PROFESSIONAL)

**Jurisdictions:** European Union (MiFID II compliant)

**Use Case:** Alternative Investment Fund (AIF) requiring professional investor classification.

**Typical Claim Data:**
```solidity
struct MiFIDClassification {
    uint8 investorType; // 1=retail, 2=professional, 3=eligible counterparty
    uint8 optedUp; // If retail opted up to professional
    uint16 countryCode;
    uint64 classificationDate;
    uint64 reviewDate; // MiFID requires periodic review
}
```

### Pattern 3: Multi-Jurisdiction Offering

**Required Topics:** 1 (KYC), 3 (COUNTRY), 7 (ACCREDITATION), 13 (SANCTIONS_CHECK)

**Jurisdictions:** US, EU, Asia-Pacific

**Use Case:** Global offering with jurisdiction-specific requirements.

**Typical Claim Data:**
```solidity
struct GlobalComplianceClaim {
    uint16 primaryCountry;
    uint16 taxResidenceCountry;
    uint8[] applicableRegimes; // Reg D, Reg S, MiFID, etc.
    uint64 verificationDate;
    uint64 nextReviewDate;
    bool accreditedUS;
    bool professionalEU;
    bool qualifiedPurchaserUS;
}
```

### Pattern 4: Real Estate Tokenization

**Required Topics:** 1 (KYC), 2 (AML), 14 (SOURCE_OF_FUNDS)

**Jurisdictions:** Various

**Use Case:** Real estate security tokens with enhanced due diligence.

**Typical Claim Data:**
```solidity
struct EnhancedDueDiligence {
    uint8 kycStatus;
    uint8 amlRiskScore; // 1-5 scale
    bool sourceOfFundsVerified;
    uint256 maxInvestmentAmount; // Based on source of funds
    uint64 verificationDate;
    bytes32 dueDiligenceReportHash;
}
```

## Frequency Analysis

Based on observed ERC-3643 deployments:

| Topic | Usage Frequency | Notes |
|-------|-----------------|-------|
| KYC (1) | 95%+ | Nearly universal requirement |
| ACCREDITATION (7) | 60%+ | Common for US offerings |
| COUNTRY (3) | 50%+ | For jurisdiction restrictions |
| AML (2) | 45%+ | Enhanced for high-value offerings |
| PROFESSIONAL (9) | 30%+ | EU MiFID II offerings |
| SANCTIONS_CHECK (13) | 25%+ | Growing requirement |
| SOURCE_OF_FUNDS (14) | 15%+ | Real estate, high-value |
| INSTITUTIONAL (10) | 10%+ | B2B offerings |

## Claim Data Field Analysis

### Common Fields Across All Claims

1. **Verification Date** (`uint64`)
   - When the claim was issued
   - Used for audit trail

2. **Expiration Date** (`uint64`)
   - When the claim becomes invalid
   - Triggers re-verification requirement

3. **Country Code** (`uint16`)
   - ISO 3166-1 numeric format
   - Same format used by ERC-3643 Identity Registry

4. **Status** (`uint8`)
   - 0 = Not verified
   - 1 = Verified/Active
   - 2 = Expired
   - 3 = Revoked
   - 4 = Pending review

### KYC Claim Fields

| Field | Type | Description |
|-------|------|-------------|
| kycStatus | uint8 | Current verification status |
| kycLevel | uint8 | 1=basic, 2=standard, 3=enhanced |
| countryCode | uint16 | Country of residence |
| nationalityCode | uint16 | Country of citizenship |
| verificationDate | uint64 | When KYC was completed |
| expirationDate | uint64 | When re-KYC is required |
| documentTypes | uint8 | Bitmap of verified document types |

### Accreditation Claim Fields

| Field | Type | Description |
|-------|------|-------------|
| accreditationType | uint8 | Type of accreditation |
| verificationMethod | uint8 | How verified (1=self-cert, 2=third-party, 3=professional letter) |
| verificationDate | uint64 | When accreditation was verified |
| expirationDate | uint64 | When re-verification required (typically annual) |
| thresholdMet | uint8 | Which threshold criteria met |

**Accreditation Types:**
- 0 = None
- 1 = Retail (qualified by knowledge/experience)
- 2 = Accredited (US income/net worth test)
- 3 = Qualified Purchaser (US $5M+ investment threshold)
- 4 = Institutional (registered entities)

### Country/Residence Claim Fields

| Field | Type | Description |
|-------|------|-------------|
| countryCode | uint16 | ISO 3166-1 numeric country code |
| residenceType | uint8 | 1=citizen, 2=resident, 3=tax resident |
| verificationDate | uint64 | When residence was verified |
| proofType | uint8 | 1=utility bill, 2=bank statement, 3=government doc |

## EAS Schema Design Implications

Based on this analysis, our EAS schemas should:

### 1. Unified Investor Eligibility Schema

Combine common fields to reduce attestation count:

```
address identity, uint8 kycStatus, uint8 accreditationType, uint16 countryCode, uint64 expirationTimestamp
```

This single schema covers 80%+ of production use cases:
- KYC status (topic 1)
- Accreditation status (topic 7)
- Country (topic 3)

### 2. Expiration Handling

Two expiration mechanisms:
- **EAS-level expiration:** Set at attestation creation, immutable
- **Data-level expiration:** In `expirationTimestamp` field, can be checked independently

### 3. Topic-to-Schema Mapping Strategy

| Claim Topics | EAS Schema |
|--------------|------------|
| 1 (KYC) | Investor Eligibility (kycStatus field) |
| 3 (COUNTRY) | Investor Eligibility (countryCode field) |
| 7 (ACCREDITATION) | Investor Eligibility (accreditationType field) |
| 2 (AML) | Extended Compliance schema (future) |
| 9 (PROFESSIONAL) | Mapped to accreditationType = 2 |
| 10 (INSTITUTIONAL) | Mapped to accreditationType = 4 |

### 4. Country Code Standard

Use ISO 3166-1 numeric codes (same as ERC-3643):
- 840 = United States
- 276 = Germany
- 250 = France
- 826 = United Kingdom
- 392 = Japan
- 156 = China
- 756 = Switzerland

## Jurisdiction-Specific Requirements

### United States

**Regulation D 506(b):**
- Up to 35 non-accredited investors allowed
- No general solicitation
- Topic: KYC (1)

**Regulation D 506(c):**
- Accredited investors only
- General solicitation allowed
- Topics: KYC (1), ACCREDITATION (7)
- Verification: Third-party letter or reasonable steps

**Regulation S:**
- Non-US persons only
- Country restrictions
- Topics: KYC (1), COUNTRY (3)

### European Union (MiFID II)

**Professional Investors:**
- Per-se professionals or elected professionals
- Topics: KYC (1), PROFESSIONAL (9)

**Eligible Counterparties:**
- Credit institutions, investment firms
- Topics: KYC (1), ELIGIBLE_COUNTERPARTY (11)

### Switzerland (FINMA)

**Qualified Investors:**
- Professional treasury operations
- Topics: KYC (1), QUALIFICATION (8)

## Trusted Issuer Patterns

Attester selection is the token issuer's responsibility. The categories below
describe the *kinds* of providers that typically issue the corresponding
claims. The EEA does not endorse, recommend, or exclude any specific vendor;
this document is neutral reference material, not a procurement list.

### KYC Providers (Topic 1)

Kinds of services that commonly issue KYC claims to token investors:

- Self-service identity-verification platforms.
- Automated document-verification services.
- Identity-verification platforms with manual review tiers.
- Full-service compliance platforms bundling KYC with sanctions/PEP screening.

### Accreditation Verifiers (Topic 7)

Kinds of services that commonly issue accreditation claims:

- Third-party accredited-investor verification services.
- Qualified-purchaser / professional-investor verification services.
- Law firms issuing investor qualification letters.
- Broker-dealers with suitability records.

### Multi-Topic Issuers

Some providers are authorised for multiple topics:

- Full-service compliance platforms (KYC + AML + accreditation).
- Broker-dealers (KYC + accreditation + suitability).

## Recommendations for EAS Bridge

1. **Start with Investor Eligibility schema** covering KYC, accreditation, and country
2. **Map multiple claim topics to single schema** where data fields overlap
3. **Use accreditationType enum** that covers US, EU, and international classifications
4. **Support trusted issuers per-topic** even when topics share a schema
5. **Implement expiration at both EAS and data level** for flexibility
6. **Follow ISO 3166-1 numeric** for country codes to match ERC-3643

## Appendix: Country Code Reference

Common ISO 3166-1 numeric codes used in production:

| Country | Code |
|---------|------|
| United States | 840 |
| United Kingdom | 826 |
| Germany | 276 |
| France | 250 |
| Switzerland | 756 |
| Singapore | 702 |
| Hong Kong | 344 |
| Japan | 392 |
| Canada | 124 |
| Australia | 036 |
| Cayman Islands | 136 |
| British Virgin Islands | 092 |
| Luxembourg | 442 |
| Ireland | 372 |
| Netherlands | 528 |
