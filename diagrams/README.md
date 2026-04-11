# Diagrams (Shibui MVP)

These diagrams are **Mermaid** source files (`.mmd`). They are intended to explain the **current MVP production path**:
- Shibui Identity Layer (EAS-backed): `EASClaimVerifier`, `EASTrustedIssuersAdapter`, `EASIdentityProxy`
- Optional legacy compatibility: ONCHAINID / existing ERC-3643 flows

## How to Read Them

- **Conceptual diagrams (product / architecture):**
  - `architecture-overview.mmd`
  - `bridge-before-after.mmd`
  - `stakeholder-interactions.mmd`
  - `multi-chain-reuse.mmd`

- **Behavioral flow diagrams (what happens on transfer / revocation):**
  - `transfer-verification-flow.mmd`
  - `revocation-flow.mmd`
  - `attestation-lifecycle.mmd`
  - `wallet-identity-mapping.mmd`

- **Legacy baseline context (optional):**
  - `current-erc3643-identity.mmd`
  - `dual-mode-verification.mmd` (shows legacy ONCHAINID path alongside Shibui EAS path)

## Rendering

GitHub can render Mermaid in Markdown, but `.mmd` files may require viewing via a Mermaid-enabled renderer.
Common options:
- Mermaid Live Editor: https://mermaid.live/
- VS Code Mermaid extensions

## Scope Note

These diagrams are MVP-focused and intentionally avoid Valence/Diamond exploration, which is archived on branch `research/valence-spike`.
