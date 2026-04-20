# Documentation

Production docs for Shibui — the payload-aware identity verifier backend for ERC-3643 security tokens. See the [repo README](../README.md) for the one-page product overview.

## Start here

| If you're… | Read this |
|---|---|
| Integrating Shibui into an ERC-3643 token | [`integration-guide.md`](integration-guide.md) |
| Trying to understand what Shibui is and isn't | [`architecture/enforcement-boundary.md`](architecture/enforcement-boundary.md) |
| Sizing gas costs | [`gas-benchmarks.md`](gas-benchmarks.md) · [`integration-gas.md`](integration-gas.md) |
| Writing or reviewing EAS attestations for Shibui | [`schemas/schema-definitions.md`](schemas/schema-definitions.md) |
| Reviewing product scope | [`../PRD.md`](../PRD.md) |
| Reviewing audit posture & launch gates | [`../AUDIT.md`](../AUDIT.md) |
| Reading release history | [`../CHANGELOG.md`](../CHANGELOG.md) |

## Structure

```
docs/
├── README.md                       # this index
├── integration-guide.md            # Path A / Path B integration
├── gas-benchmarks.md               # Shibui-internal gas numbers
├── integration-gas.md              # ERC-3643 × Shibui end-to-end gas
├── alerts-webhook.md               # GitHub Actions issue/comment webhook
├── ci-cd.md                        # CI overview
│
├── architecture/
│   ├── enforcement-boundary.md      # what Shibui does NOT provide
│   ├── identity-architecture-explained.md
│   ├── system-architecture.md
│   ├── data-flow.md
│   └── contract-interaction-diagrams.md
│
├── schemas/
│   ├── schema-definitions.md        # Schema 1 v2 + Schema 2 (canonical)
│   └── schema-governance.md         # versioning + resolver policy
│
└── research/                        # forward-looking, non-canonical
    ├── gap-analysis.md              # ONCHAINID vs EAS
    ├── claim-topic-analysis.md      # topics observed in production ERC-3643
    ├── minimal-identity-structure.md
    └── passport-format-v0.1.md      # broader schema proposal (not deployed)
```

`research/` contains proposals and analysis, not deployed specs. Build against `schemas/` for what's actually on-chain.

## Diagrams

Architecture and flow diagrams live at [`../diagrams/`](../diagrams/) as Mermaid sources. Start with [`../diagrams/README.md`](../diagrams/README.md) for the index.
