# Documentation Harmonization Brief

## Goal
Create a complete, harmonized documentation set that tells a clear story: why this project exists, how identity works today, what the bridge changes, and how to use it. Every doc should be consistent in tone, terminology, and cross-references.

## Current State
- README.md — has "Why This Exists", benefits, use case, implementation example, personas
- docs/architecture/system-architecture.md — technical component inventory (good but dry)
- docs/architecture/data-flow.md — operation-by-operation data flow
- docs/architecture/contract-interaction-diagrams.md — references Mermaid diagrams
- docs/integration-guide.md — step-by-step integration (recently updated with user stories)
- docs/gas-benchmarks.md — gas costs (stub, needs data)
- docs/research/gap-analysis.md — ONCHAINID vs EAS comparison
- docs/research/claim-topic-analysis.md — ERC-3643 claim topic mapping
- docs/research/minimal-identity-structure.md — identity design decisions
- docs/schemas/schema-definitions.md — EAS schema specs
- docs/schemas/schema-governance.md — schema versioning
- diagrams/ — 10 Mermaid diagrams (5 context + 5 technical)

## What Needs to Happen

### 1. Create `docs/architecture/identity-architecture-explained.md` (NEW — the main doc)

This is the key new document. It should explain, in clear language with diagrams, the full identity architecture story:

**Section 1: How ERC-3643 Identity Works Today**
- Explain the ONCHAINID model (ERC-734 keys, ERC-735 claims)
- Show the flow: investor → KYC provider → ONCHAINID contract → Identity Registry → token transfer
- Reference diagram: `current-erc3643-identity.mmd`
- List the pain points: vendor lock-in, per-user contract deployment, no cross-chain portability, limited provider ecosystem

**Section 2: What EAS Brings to the Table**
- Explain EAS in simple terms (attestation = signed statement on-chain)
- Why EAS is gaining adoption (multi-chain, open, composable, used by Coinbase, Optimism, etc.)
- How EAS attestations differ from ONCHAINID claims (schema-based vs ERC-735, no per-user contract, revocable, expirable)

**Section 3: How the Bridge Works**
- Architecture overview — reference `architecture-overview.mmd` and `bridge-before-after.mmd`
- Each contract's role explained in plain language (not just "Core verification logic" — explain WHAT it verifies and WHY)
- The verification flow step by step — reference `transfer-verification-flow.mmd`
- Multi-wallet identity — reference `wallet-identity-mapping.mmd`

**Section 4: Integration Paths**
- Path A vs Path B — when to use each, with diagrams
- Reference `dual-mode-verification.mmd`
- Brief code snippets (point to integration-guide.md for full details)

**Section 5: Compliance & Revocation**
- How revocation works — reference `revocation-flow.mmd`
- Provider trust management
- Attestation lifecycle — reference `attestation-lifecycle.mmd`
- Why this matters for regulated securities

**Section 6: Multi-Chain Vision**
- One KYC, many chains — reference `multi-chain-reuse.mmd`
- EAS network support
- Cross-chain attestation strategy

**Section 7: Stakeholder Guide**
- Reference `stakeholder-interactions.mmd`
- For each stakeholder (token issuer, KYC provider, investor, compliance officer): what they do, what they see, what they care about

### 2. Update `docs/architecture/system-architecture.md`
- Add a "Start Here" note at the top pointing to `identity-architecture-explained.md` for the full picture
- Keep as the technical reference (component inventory, dependencies, error handling)
- Add cross-references to the new diagrams

### 3. Update `docs/architecture/contract-interaction-diagrams.md`
- Add entries for all 5 new diagrams (current identity, before/after, multi-chain, stakeholders, revocation)
- Each entry: filename, what it shows, when to reference it

### 4. Update `docs/gas-benchmarks.md`
- Fill in with actual data from our test suite. The gas benchmark tests output:
  - isVerified (1 topic): ~27,878 gas
  - isVerified (3 topics): ~57,309 gas
  - isVerified (5 topics): ~86,808 gas
  - Create attestation: ~217,853 gas
  - Register attestation: ~33,907 gas
  - Register wallet: ~76,019 gas
  - Add trusted attester: ~151,711 gas
- Add cost estimates at current gas prices (use 30 gwei as baseline)
- Compare with ONCHAINID gas costs if available

### 5. Harmonize terminology across ALL docs
- "attestation" not "claim" when talking about EAS
- "claim" only when talking about ONCHAINID/ERC-735
- "trusted attester" not "trusted issuer" when talking about EAS providers
- "token issuer" not "deployer" or "owner" when talking about the entity running the token
- "bridge" always refers to the EAS-ERC3643 bridge
- Consistent capitalization: EAS, ONCHAINID, ERC-3643, ERC-735, ERC-734

### 6. Add `docs/README.md` (documentation index)
Create a docs index that maps the documentation structure:

```
docs/
├── README.md                              # This index
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

## Style Guide for All Docs
- **Audience:** Technical readers who know Ethereum but may not know ERC-3643 or EAS
- **Tone:** Clear, direct, professional. Explain WHY before HOW.
- **Structure:** Start each section with a 1-2 sentence summary. Use tables for comparisons. Use diagrams where they add clarity.
- **Cross-references:** Link to other docs and diagrams. Never duplicate content — point to the source.
- **Code:** Include minimal code snippets inline. Point to integration guide or test files for full examples.

## What NOT to Do
- Don't rewrite the README — it's already good
- Don't change the research docs — they're reference material
- Don't remove any existing content — only add and reorganize
- Don't create new diagrams — we have 10, use them

When completely finished, run this command:
openclaw system event --text "Done: Documentation harmonized — new architecture doc, updated gas benchmarks, docs index, terminology aligned" --mode now
