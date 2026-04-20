# Diagrams

Mermaid source files (`.mmd`) explaining Shibui's current architecture (post audit refactor, v0.4.x).

## Structure

**Architecture — what lives where and who controls it:**

- [`architecture-overview.mmd`](architecture-overview.mmd) — full component + control plane (token, verifier, policies × 8, adapter, resolver, proxy, multisig).
- [`pluggable-backend-verification.mmd`](pluggable-backend-verification.mmd) — `IIdentityVerifier` extension point in the ERC-3643 Identity Registry: either the default ONCHAINID path runs, or Shibui runs. Delegation is total, not hybrid.
- [`shibui-before-after.mmd`](shibui-before-after.mmd) — single-vendor identity stack vs. pluggable backend with payload-aware verification.

**Behavioural flows — what happens on a transfer / revocation:**

- [`transfer-verification-flow.mmd`](transfer-verification-flow.mmd) — sequence from `token.transfer` through compliance → Identity Registry → `EASClaimVerifier` → per-topic `ITopicPolicy.validate`.
- [`revocation-flow.mmd`](revocation-flow.mmd) — attester revokes on EAS → next `isVerified` returns false → transfer blocked.
- [`attestation-lifecycle.mmd`](attestation-lifecycle.mmd) — state machine from unverified → active → revoked / expired → renewed. Includes Schema v2 payload fields.
- [`wallet-identity-mapping.mmd`](wallet-identity-mapping.mmd) — how multiple wallets resolve to a single identity in `EASIdentityProxy`.

**People / roles:**

- [`stakeholder-interactions.mmd`](stakeholder-interactions.mmd) — token issuer, compliance multisig (DEFAULT_ADMIN_ROLE), operators (OPERATOR_ROLE), agents (AGENT_ROLE), KYC providers, investors, token contract.

**Legacy baseline (for contrast):**

- [`current-erc3643-identity.mmd`](current-erc3643-identity.mmd) — how ERC-3643 identity works with ONCHAINID alone, which pain points Shibui addresses, and which it explicitly does not.

## Rendering

GitHub renders Mermaid in `.md` inline; `.mmd` files need a Mermaid-aware viewer:

- Mermaid Live Editor: <https://mermaid.live/>
- VS Code: *Mermaid Preview* extension

## Scope note

Diagrams match the **v0.4** production path. The core is targeted at EthTrust SL Level 2 (see `AUDIT.md`); the Path-B wrapper under `contracts/compat/` is Level 1 and not the subject of these diagrams. Older exploratory Valence/Diamond work is archived on branch `research/valence-spike`.
