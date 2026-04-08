# Documentation Index

This directory contains the documentation for the EAS-to-ERC-3643 Identity Bridge.

## Where to Start

| Goal | Start Here |
|------|------------|
| **Understand the architecture** | [Identity Architecture Explained](architecture/identity-architecture-explained.md) — Full story of how ERC-3643 identity works, what EAS brings, and how the bridge connects them |
| **Understand implementation quickly (GitHub-ready)** | [ERC-3643 + EAS Implementation Guide](erc3643-eas-implementation-guide.md) — Practical architecture + validation + review checklist |
| **Integrate the bridge** | [Integration Guide](integration-guide.md) — Step-by-step integration instructions with code examples |
| **Estimate gas costs** | [Gas Benchmarks](gas-benchmarks.md) — Gas costs for all operations with USD estimates |

## Documentation Structure

```
docs/
├── README.md                              # This index
├── erc3643-eas-implementation-guide.md    # GitHub-friendly implementation guide
├── alerts-webhook.md                      # Issue/comment alerts to EEA agent channel
├── integration-guide.md                   # How to integrate (step by step)
├── gas-benchmarks.md                      # Gas costs and optimization
├── architecture/
│   ├── identity-architecture-explained.md # START HERE — full architecture story
│   ├── system-architecture.md             # Technical component reference
│   ├── contract-interaction-diagrams.md   # Diagram catalog
│   └── data-flow.md                       # Operation-by-operation data flows
├── schemas/
│   ├── schema-definitions.md              # EAS schema specifications
│   └── schema-governance.md               # Schema versioning and updates
└── research/
    ├── gap-analysis.md                    # ONCHAINID vs EAS comparison
    ├── claim-topic-analysis.md            # ERC-3643 claim topic mapping
    └── minimal-identity-structure.md      # Identity design decisions
```

## Architecture Documentation

| Document | Description |
|----------|-------------|
| [ERC-3643 + EAS Implementation Guide](erc3643-eas-implementation-guide.md) | Fast, GitHub-friendly guide for reviewers and integrators: architecture, validation path, production readiness, and checklist. |
| [Identity Architecture Explained](architecture/identity-architecture-explained.md) | The main architecture document. Explains how ERC-3643 identity works today, what EAS brings, how the bridge works, integration paths, compliance/revocation, multi-chain vision, and stakeholder perspectives. |
| [System Architecture](architecture/system-architecture.md) | Technical component inventory: contracts, dependencies, integration paths, trust boundaries, upgrade paths, data flow. |
| [Contract Interaction Diagrams](architecture/contract-interaction-diagrams.md) | Catalog of all Mermaid diagrams with descriptions of what each shows and when to reference it. |
| [Data Flow](architecture/data-flow.md) | Operation-by-operation data flow documentation for each major operation (register identity, issue attestation, verify transfer, revoke, etc.). |

## Schema Documentation

| Document | Description |
|----------|-------------|
| [Schema Definitions](schemas/schema-definitions.md) | EAS schema specifications for the bridge: Investor Eligibility, Issuer Authorization, Wallet-Identity Link. Includes field definitions, encoding examples, and validation logic. |
| [Schema Governance](schemas/schema-governance.md) | Process for proposing, reviewing, and approving schema changes. Includes versioning, deprecation, and emergency procedures. |

## Research Documentation

These documents capture the design decisions and analysis that informed the bridge architecture. They are reference material and are not modified during routine documentation updates.

| Document | Description |
|----------|-------------|
| [Gap Analysis](research/gap-analysis.md) | Detailed comparison of ONCHAINID vs EAS capabilities across key dimensions: key management, multi-wallet identity, cross-chain portability, off-chain attestations, claim structure, revocation, trusted issuer registry. |
| [Claim Topic Analysis](research/claim-topic-analysis.md) | Analysis of ERC-3643 claim topics used in production: standard topic IDs, usage patterns by jurisdiction, data field analysis, and recommendations for EAS schema design. |
| [Minimal Identity Structure](research/minimal-identity-structure.md) | Traces the `isVerified()` call path in ERC-3643 to understand minimal requirements, then maps each step to EAS equivalents. |

## Diagrams

All diagrams are in the `diagrams/` directory as Mermaid source files (`.mmd`). Render with any Mermaid viewer ([mermaid.live](https://mermaid.live), GitHub, VS Code extension).

### Context & Strategy Diagrams

| Diagram | File | Description |
|---------|------|-------------|
| Current ERC-3643 Identity | `current-erc3643-identity.mmd` | How ONCHAINID works today, with pain points |
| Before/After | `bridge-before-after.mmd` | Comparison of closed vs open identity layer |
| Multi-Chain Reuse | `multi-chain-reuse.mmd` | One KYC across multiple chains |
| Stakeholder Interactions | `stakeholder-interactions.mmd` | Who does what: issuer, provider, investor, compliance |
| Revocation Flow | `revocation-flow.mmd` | Real-time revocation process |

### Technical Architecture Diagrams

| Diagram | File | Description |
|---------|------|-------------|
| Architecture Overview | `architecture-overview.mmd` | Contract relationships |
| Transfer Verification Flow | `transfer-verification-flow.mmd` | Full verification sequence |
| Dual Mode Verification | `dual-mode-verification.mmd` | Path A vs Path B |
| Attestation Lifecycle | `attestation-lifecycle.mmd` | Attestation state machine |
| Wallet-Identity Mapping | `wallet-identity-mapping.mmd` | Multi-wallet support |

## Related Resources

- **Main README:** [../README.md](../README.md) — Project overview, quickstart, deployment
- **Deployment Scripts:** [../script/](../script/) — Foundry deployment scripts
- **Test Suite:** [../test/](../test/) — Comprehensive test coverage
- **EAS Documentation:** [docs.attest.org](https://docs.attest.org)
- **ERC-3643 Specification:** [github.com/TokenySolutions/T-REX](https://github.com/TokenySolutions/T-REX)
