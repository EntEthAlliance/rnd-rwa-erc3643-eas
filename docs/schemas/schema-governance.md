# Schema Governance Process

## Overview

This document defines the process for proposing, reviewing, and approving EAS schemas for the EAS-to-ERC-3643 Identity Bridge. Schema governance ensures schemas meet compliance requirements, maintain backward compatibility, and follow established standards.

## Governance Authority

### EEA (Enterprise Ethereum Alliance) Working Group

The EEA Token Taxonomy Working Group or designated Security Token Standards group owns schema governance for:

- Core compliance schemas (Investor Eligibility, Issuer Authorization)
- Cross-organization interoperability schemas
- Schema versioning and deprecation decisions

### Token Issuer Authority

Individual token issuers have authority over:

- Trusted attester configuration (which KYC providers to accept)
- Claim topic requirements (which topics are required for their token)
- Custom schemas for token-specific compliance needs

### Schema Registry Immutability

Once registered, EAS schemas are **immutable**. The schema string, resolver, and revocability cannot be changed. Governance decisions are about:

- Whether to register new schemas
- Which schema UIDs to recommend for adoption
- When to deprecate old schemas

---

## Schema Proposal Process

### Step 1: Proposal Submission

Submit a schema proposal via:
- GitHub issue on the eas-erc3643-bridge repository
- EEA working group submission (for standardization track)

**Required Information:**

```markdown
## Schema Proposal

**Name:** [Human-readable schema name]

**Schema String:**
```
[Field types and names in Solidity ABI format]
```

**Purpose:**
[What compliance requirement does this schema address?]

**Resolver:**
[Resolver contract address or "None"]

**Revocable:**
[Yes/No with justification]

**Claim Topic Mapping:**
[Which ERC-3643 claim topics does this schema support?]

**Jurisdiction:**
[Which jurisdictions is this schema designed for?]

**Backward Compatibility:**
[How does this affect existing attestations and verifications?]

**Example Data:**
[Sample encoded attestation data]

**Proposer:**
[Organization and contact]
```

### Step 2: Technical Review

Technical review checks:

1. **Schema syntax** - Valid Solidity ABI types
2. **Gas efficiency** - Reasonable encoding size
3. **Decoding safety** - No ambiguous or variable-length types that cause issues
4. **Resolver compatibility** - Resolver logic matches schema structure

### Step 3: Compliance Review

Compliance review checks:

1. **Regulatory alignment** - Meets requirements of target jurisdictions
2. **Data minimization** - Only necessary fields included
3. **Privacy considerations** - Sensitive data handling
4. **Interoperability** - Works with existing claim topics and schemas

### Step 4: Working Group Vote

For standardization track schemas:

1. Proposal presented at EEA working group meeting
2. Discussion period (minimum 2 weeks)
3. Vote by working group members
4. Approval requires majority consensus

### Step 5: Registration

After approval:

1. Register schema on testnet (Sepolia)
2. Integration testing with bridge contracts
3. Register schema on mainnet
4. Update SchemaUIDs constants file
5. Document schema UID in official registry

---

## Schema UID Management

### UID Determinism

Schema UIDs are deterministic:

```
schemaUID = keccak256(abi.encodePacked(
    schemaString,
    resolverAddress,
    revocable
))
```

Same schema registered with same resolver and revocability = same UID across chains.

### UID Registry

Maintain a public registry of approved schema UIDs:

| Schema Name | Testnet UID | Mainnet UID | Status |
|-------------|-------------|-------------|--------|
| Investor Eligibility v1 | 0x... | 0x... | Active |
| Issuer Authorization v1 | 0x... | 0x... | Active |
| Wallet-Identity Link v1 | 0x... | 0x... | Active |

### Cross-Chain Consistency

To maintain same schema UIDs across chains:

1. Use deterministic resolver deployment (CREATE2)
2. Deploy resolvers with same address on all chains
3. Register schemas with identical parameters

---

## Backward Compatibility

### Adding Fields

New schemas with additional fields create new UIDs. Handle via:

1. **Dual support** - Accept both old and new schema UIDs for a transition period
2. **Claim topic mapping** - Map topic to array of acceptable schema UIDs
3. **Deprecation timeline** - Announce deprecation, set deadline

### Changing Fields

Changing existing field types or semantics requires:

1. New schema registration
2. Migration period with dual support
3. Clear documentation of differences
4. Issuer notification and re-attestation guidance

### Removing Fields

Not recommended. If necessary:

1. Create new schema without field
2. Document which verifications will fail
3. Allow long migration period

---

## Schema Deprecation

### Deprecation Process

1. **Announcement** - 90-day notice before deprecation
2. **Alternative** - New schema must be available
3. **Migration guide** - Clear instructions for re-attestation
4. **Grace period** - Continue accepting deprecated schema for 90 days
5. **Removal** - Remove deprecated schema from recommended list

### Deprecation Criteria

Schemas may be deprecated when:

- Security vulnerability discovered
- Regulatory requirements change
- Better alternative schema available
- Low adoption after reasonable period

---

## Schema Categories

### Core Schemas (Standardization Track)

Managed by EEA working group:

- **Investor Eligibility** - Required for basic compliance
- **Issuer Authorization** - Required for trust management
- **Wallet-Identity Link** - Required for multi-wallet support

Changes require working group approval.

### Extension Schemas (Community Track)

Managed by community with lighter governance:

- Additional compliance schemas (AML, sanctions)
- Jurisdiction-specific schemas
- Industry-specific schemas (real estate, private equity)

Proposals reviewed for technical validity but don't require working group vote.

### Private Schemas (Issuer Track)

Managed by individual token issuers:

- Custom compliance requirements
- Internal organizational schemas
- Not recommended for cross-organization use

No governance required, but documentation encouraged.

---

## Resolver Governance

### Resolver Requirements

Schema resolvers must:

1. Be verified and audited
2. Have clear upgrade path if upgradeable
3. Not introduce single points of failure
4. Handle failures gracefully (don't block attestation creation)

### Resolver Changes

To change a schema's resolver:

1. Cannot modify existing schema
2. Must register new schema with new resolver
3. Follow standard deprecation process for old schema

### Approved Resolvers

| Resolver | Purpose | Address (Sepolia) | Address (Mainnet) |
|----------|---------|-------------------|-------------------|
| EASTrustedIssuersAdapter | Validate attester authorization | 0x... | 0x... |
| WalletLinkResolver | Validate identity ownership | 0x... | 0x... |

---

## Versioning Convention

### Schema Version Format

`SchemaName_v{major}.{minor}`

- **Major**: Breaking changes (new fields, changed semantics)
- **Minor**: Documentation updates, clarifications

Example: `InvestorEligibility_v1.0`, `InvestorEligibility_v2.0`

### Version in Documentation

Each schema document includes:

```yaml
version: 1.0
status: active | deprecated | draft
created: 2024-01-01
deprecated: null | 2025-01-01
replacement: null | InvestorEligibility_v2
```

---

## Dispute Resolution

### Technical Disputes

Resolved by:

1. Technical working group review
2. Reference implementation testing
3. Majority vote if consensus not reached

### Governance Disputes

Resolved by:

1. EEA working group mediation
2. Escalation to EEA board if needed
3. Final decision binding on all participants

### Adoption Disputes

Individual issuers always have authority to:

1. Choose which schemas to accept
2. Add additional schemas beyond standards
3. Implement stricter requirements than standards

---

## Documentation Requirements

### Schema Documentation

Each approved schema must have:

1. **Schema definition file** - Technical specification
2. **Usage guide** - How to create and verify attestations
3. **Example code** - Solidity and TypeScript examples
4. **Claim topic mapping** - Which ERC-3643 topics it supports

### Change Log

Maintain changelog for governance decisions:

```markdown
## Schema Governance Changelog

### 2024-01-15
- Approved Investor Eligibility v1 schema
- Registered on Sepolia and Mainnet

### 2024-02-01
- Added WalletLinkResolver to approved resolvers
- Registered Wallet-Identity Link v1 schema
```

---

## Emergency Procedures

### Security Vulnerability

If a security issue is discovered:

1. **Immediate** - Private disclosure to working group
2. **24-48 hours** - Assess impact and develop fix
3. **72 hours** - Deploy fixed resolver if possible
4. **1 week** - Public disclosure with mitigation guidance
5. **30 days** - Deprecate vulnerable schema if needed

### Regulatory Emergency

If regulatory requirement changes urgently:

1. Emergency working group meeting
2. Fast-track schema proposal (skip standard timeline)
3. Immediate testnet deployment
4. Expedited mainnet deployment

---

## Participation

### Working Group Membership

Open to:

- EEA member organizations
- Security token issuers
- KYC/compliance providers
- Blockchain infrastructure providers
- Regulators (observer status)

### Contribution Process

1. Join EEA working group
2. Participate in schema discussions
3. Submit proposals via standard process
4. Vote on standardization track schemas

### Contact

- GitHub: github.com/[org]/eas-erc3643-bridge
- EEA Working Group: [contact information]
- Mailing List: [mailing list address]
