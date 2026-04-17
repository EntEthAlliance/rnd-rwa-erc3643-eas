# Shibui (EAS ↔ ERC-3643)

**Shibui is an attestation retrieval adapter for ERC-3643 identity verification**, not a full identity layer. It lets an ERC-3643 security-token deployment answer "is this wallet compliant right now?" from EAS attestations issued by any trusted provider, decoupled from ONCHAINID.

## Scope

Shibui is the component that a token's ERC-3643 compliance module calls from `canTransfer`/`isVerified`. It:

- Decodes EAS attestation payloads against a registered schema.
- Applies a **per-topic policy** to each required claim topic (e.g. `kycStatus == VERIFIED`, `countryCode ∈ allow-list`, `accreditationType ∈ allowed-set`).
- Iterates trusted attesters for each topic until one passes — so removing a single compromised provider does not invalidate investors attested by others.
- Gates trusted-attester admin actions behind a cryptographic audit trail (EAS Schema 2 + `TrustedIssuerResolver`).

## Out of scope (see `docs/architecture/enforcement-boundary.md`)

The following live in the ERC-3643 **token contract**, not in Shibui, and revoking a Shibui attestation is **not** a substitute for them:

- Forced transfer (court orders)
- Account freeze / partial freeze (sanctions)
- Lost-key recovery
- Lock-up schedules, per-investor caps, ownership limits
- Cross-chain attestation canonicity — EAS attestations are per-chain today; multi-chain attestation portability is on the V2 roadmap.
- Off-chain attestation verification — deferred to V2.

## Core Contracts

| Contract | Role |
|---|---|
| `EASClaimVerifier` | Payload-aware verification: runs per-topic `ITopicPolicy.validate()` against the trusted-attester list for each required topic. |
| `EASTrustedIssuersAdapter` | Per-topic trusted-attester management; every add/update must reference a live EAS Schema-2 attestation (`authUID`). |
| `EASIdentityProxy` | Wallet→identity binding, `AGENT_ROLE`-gated. |
| `TrustedIssuerResolver` | EAS resolver that gates Schema-2 writes to admin-curated authorizers. |
| `ITopicPolicy` + 8 policy modules | Decode Schema v2 payload, enforce per-topic semantics (KYC, AML, country allow-list, accreditation allow-list, professional, institutional, sanctions, source-of-funds). |
| `EASClaimVerifierIdentityWrapper` | Read-compat shim for legacy ERC-3643 Identity Registries that cannot be modified (Path B). Does **not** implement ERC-734 keys, recovery, or claim signature verification. New deployments should use Path A. |

## Validate (MVP)

```bash
forge install
forge build
forge test
```

## Demo

```bash
anvil
forge script script/SetupPilot.s.sol:SetupPilot --rpc-url http://127.0.0.1:8545 --broadcast
```

The pilot deploys MockEAS, the full Shibui stack (including all 8 policies and a Schema-2 authorizer), seeds five investors with Schema v2 attestations, and prints `isVerified()` for each wallet.

## Administration

All core contracts use OpenZeppelin `AccessControl`. Roles:

- `DEFAULT_ADMIN_ROLE` — can grant/revoke other roles. **Expected to be a multisig in production** (audit finding R-6).
- `OPERATOR_ROLE` — day-to-day topic-schema mapping, topic-policy mapping, trusted-attester changes.
- `AGENT_ROLE` (identity proxy) — wallet-identity binding.

No timelock is applied by default; the multisig is the control. Deployers should transfer `DEFAULT_ADMIN_ROLE` to the multisig and renounce their own grant immediately after deploy.

## Security Note

Mainnet usage must be gated by explicit audit readiness controls (see `AUDIT.md`). This repo represents the post-audit-findings refactor; an independent audit of the refactored contracts is still required before mainnet.

## Documentation

- `docs/architecture/enforcement-boundary.md` — **start here** for scope boundaries.
- `PRD.md` — MVP scope and acceptance criteria.
- `docs/architecture/identity-architecture-explained.md` — architectural walkthrough.
- `docs/integration-guide.md` — integration paths (pluggable verifier vs wrapper).
- `docs/schemas/schema-definitions.md` — EAS schema v2 spec.
- `docs/research/gap-analysis.md` — ONCHAINID vs EAS comparison.

## License

MIT
