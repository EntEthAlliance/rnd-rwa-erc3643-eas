# Shibui — Product Specification

**Status:** `v0.4.0-rc1` pre-release
**License:** Apache-2.0
**Owner:** Enterprise Ethereum Alliance

---

## What Shibui is

Shibui is a **payload-aware identity verifier backend for ERC-3643 security tokens**, built on the Ethereum Attestation Service (EAS).

It answers one question, authoritatively, for the compliance hook of an ERC-3643 token contract:

> *"Does this wallet hold the attestations the issuer requires, with current payloads, right now?"*

Shibui is intentionally narrow. It is not a full identity layer, not a token standard, not a KYC service. It is the answer to `isVerified(wallet)` when a token wants a cryptographic, payload-semantic, multi-provider answer.

---

## Why Shibui exists

ERC-3643 mandates an on-chain identity check on every transfer. The reference path (ONCHAINID + `IdentityRegistry` claim validation) works but creates three friction points for institutional deployments:

1. **Vendor coupling.** Only ONCHAINID-compatible providers can participate. There is no clean way to plug in an EAS-based, ZK-based, or future identity backend.
2. **No on-chain payload enforcement.** The default path checks *whether* a claim was issued by a trusted issuer, not *what the claim says*. A pending KYC, an expired accreditation, or a restricted jurisdiction can pass `isVerified` as long as the credential exists.
3. **No auditable trust-change trail.** Adding or removing a trusted KYC provider is an on-chain state change with no cryptographic authorisation artifact — compliance teams get the event but no signed record of who authorised the change.

Shibui addresses all three via a small stack of EAS-backed contracts plugged behind the ERC-3643 Identity Registry.

---

## Target users

| Role | What they do with Shibui |
|---|---|
| **Security-token issuer** | Deploys the stack (one script), selects required topics, delegates the Identity Registry to Shibui via `setIdentityVerifier`. |
| **Compliance multisig** (`DEFAULT_ADMIN_ROLE`) | Curates Schema-2 authorizers; approves trusted-attester changes; responds to incidents. |
| **Day-to-day operators** (`OPERATOR_ROLE`) | Bind topics to policies; manage trusted attesters; update schema mappings. |
| **Issuer agents** (`AGENT_ROLE`) | Bind investor wallets to identities. |
| **KYC / AML / sanctions providers** | Attest investors under the Investor Eligibility schema; revoke when circumstances change. |
| **Investors** | Complete KYC once with a trusted provider; no per-investor contract deployed. |

---

## Scope

### In scope (v0.4.x)

**Core contracts**

- `EASClaimVerifier` — payload-aware verification entry point.
- `EASTrustedIssuersAdapter` — Schema-2-gated per-topic attester trust.
- `EASIdentityProxy` — wallet → identity binding under `AGENT_ROLE`.
- `TrustedIssuerResolver` — EAS schema resolver that gates Schema-2 writes to admin-curated authorizers.
- 8 `ITopicPolicy` modules — one per production-use ERC-3643 claim topic (KYC, AML, country allow-list, accreditation, professional, institutional, sanctions, source-of-funds).
- UUPS upgradeable variants of the three core contracts.

**Read-compat shim (Path B)**

- `EASClaimVerifierIdentityWrapper` — lives under `contracts/compat/`, targeted at EthTrust SL **Level 1**. Bridges to legacy Identity Registries that cannot be modified. Documented non-features: no ERC-734 keys, no topic policies in `isClaimValid`, no signature verification, O(N×M) gas profile. Use Path A for new deployments.

**Schemas**

- Investor Eligibility — 10 fields, including `evidenceHash` and `verificationMethod` for auditability.
- Issuer Authorization — gates adapter trust changes.

**Administration**

- OpenZeppelin `AccessControl`: `DEFAULT_ADMIN_ROLE` (multisig), `OPERATOR_ROLE`, `AGENT_ROLE`.
- Deploy scripts: testnet, mainnet (gated by `AUDIT_ACKNOWLEDGED=true`), UUPS, local pilot.

**Standards-body engagement**

- Upstream PR [`ERC-3643/ERC-3643#98`](https://github.com/ERC-3643/ERC-3643/pull/98) proposing a minimal `IIdentityVerifier` extension point so the backend is pluggable per ERC-3643 deployment without forking the standard.

### Out of scope (explicit)

These remain the responsibility of the ERC-3643 **token contract** or off-chain operational tooling. Revoking a Shibui attestation does *not* substitute for any of them.

| Primitive | Where it lives |
|---|---|
| Forced transfer (court orders) | ERC-3643 token |
| Account freeze / partial freeze | ERC-3643 token |
| Lost-key recovery | ERC-3643 `recoveryAddress` flow |
| Lock-ups, per-investor caps, ownership limits | ERC-3643 compliance modules |
| Cross-chain attestation canonicity | Per-chain today; V2 roadmap |
| Off-chain / privacy-preserving verification | V2 roadmap |
| Tax withholding, FATCA / CRS | Off-chain |

See [`docs/architecture/enforcement-boundary.md`](docs/architecture/enforcement-boundary.md) for the full scope boundary.

---

## How it works (in one paragraph)

When an ERC-3643 token's compliance hook calls `isVerified(wallet)`, the Identity Registry delegates to `EASClaimVerifier`. The verifier resolves the wallet to an investor identity via `EASIdentityProxy`, enumerates the required claim topics from the `ClaimTopicsRegistry`, and for each topic: iterates the ≤5 trusted attesters, fetches each one's registered attestation from EAS, runs structural checks (schema match, not revoked, not expired, attester still trusted), then invokes the topic's `ITopicPolicy.validate()` to enforce payload semantics (e.g. `kycStatus == VERIFIED`, `countryCode` in allow-list, `accreditationType` in allowed set). Short-circuits to pass on the first attester whose attestation clears every check. Returns true only if every required topic is satisfied.

Diagrams: [`architecture-overview`](diagrams/architecture-overview.mmd), [`transfer-verification-flow`](diagrams/transfer-verification-flow.mmd), [`pluggable-backend-verification`](diagrams/pluggable-backend-verification.mmd).

---

## Acceptance criteria

### A) Payload-aware verification

- `isVerified(wallet)` returns `true` only when every required topic is satisfied by an attestation whose **decoded payload** passes the topic's `ITopicPolicy`.
- A valid-looking attestation whose payload fails the policy returns `false`.
- Missing, revoked, expired, schema-mismatched, or untrusted attestation returns `false`.

### B) Multi-attester resilience

- Multiple attesters per topic supported (cap: `MAX_ATTESTERS_PER_TOPIC = 5`).
- Removing one attester does not invalidate investors covered by another.
- `isVerified` short-circuits on the first passing attestation.

### C) Schema-2 gated trust changes

- Every `addTrustedAttester` / `updateAttesterTopics` call requires a live EAS Schema-2 attestation whose recipient equals the attester and whose `authorizedTopics` is a superset of the passed topics.
- `TrustedIssuerResolver` gates Schema-2 writes to admin-curated authorizers; authorizer changes emit `AuthorizerAdded` / `AuthorizerRemoved`.

### D) Role-separated administration

- Three-role split: `DEFAULT_ADMIN_ROLE`, `OPERATOR_ROLE`, `AGENT_ROLE`.
- Production deploy transfers `DEFAULT_ADMIN_ROLE` to a multisig atomically and renounces the deployer's grant in the same broadcast.

### E) Audit trail

- Every state-changing admin action emits an event (setter, role grant, attester add/remove/update, schema UID changes).
- The Investor Eligibility schema carries `evidenceHash` + `verificationMethod` so examiners can trace an on-chain decision back to the KYC file held off-chain by the provider.

### F) Pluggability

- Backend integrates with a standards-aligned ERC-3643 Identity Registry via the `IIdentityVerifier` extension point (upstream PR [`#98`](https://github.com/ERC-3643/ERC-3643/pull/98)).
- Default ONCHAINID path is unchanged when the extension point is not used.

### G) Test, CI, and engineering posture

- `forge test` passes (currently 115 tests).
- Gas regression guards on `isVerified` at 1 / 3 / 5 topic configurations.
- `forge fmt --check` clean.
- Gitleaks secret-scan on every push and PR.
- `forge coverage --ir-minimum` green on master.
- Pinned `pragma solidity =0.8.24` across production contracts.

---

## Validation

### Local

```bash
forge install
forge build
forge test
```

### End-to-end pilot (anvil)

```bash
anvil
forge script script/SetupPilot.s.sol:SetupPilot \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast
```

Expected: 5 investors seeded; `isVerified(wallet)` returns `true` for each; revoking one investor's KYC attestation via `eas.revoke()` flips their `isVerified` to `false`; removing trust in the provider blocks all 5.

### Integration against a real ERC-3643 stack

See [`test/integration/ERC3643Token.integration.t.sol`](test/integration/ERC3643Token.integration.t.sol). Deploys the full T-REX / ERC-3643 stack from the `lib/ERC-3643` submodule, wires Shibui behind it via `setIdentityVerifier`, and exercises five scenarios: happy-path transfer, EAS revocation, policy rejection, default-path fallback, provider retirement. All green.

---

## Release criteria

### `v0.4.0-rc1` → `v0.4.0` (final)

- [ ] Independent audit of the post-refactor surface completed (scope in [`AUDIT.md`](AUDIT.md)).
- [ ] Findings above high severity resolved or formally accepted.
- [ ] Multisig signing ceremony documented for the target deployment.
- [ ] `AUDIT_ACKNOWLEDGED=true` appropriate to flip for the target chain.

### `v0.4.x` → `v0.5.0`

- [ ] Upstream `IIdentityVerifier` extension point merged at `ERC-3643/ERC-3643`.
- [ ] OpenZeppelin 5.x / pragma-loosening migration on the ERC-3643 fork (tracked at [`EntEthAlliance/ERC-3643#1`](https://github.com/EntEthAlliance/ERC-3643/issues/1)).
- [ ] Cross-chain attestation portability pattern chosen and documented (LayerZero / Axelar / mirroring).

---

## Risks & assumptions

### Risks

- **Policy misconfiguration.** Binding the wrong `ITopicPolicy` to a topic causes mass false-accepts or false-rejects. *Mitigation:* policy unit tests, deploy-time checks that `policy.topicId()` matches the binding, multisig approval for policy changes, visible `TopicPolicySet` events.
- **Schema-2 resolver compromise.** Unauthorised Schema-2 attestations enable rogue trusted-attester adds. *Mitigation:* `TrustedIssuerResolver` restricts writes to admin-curated authorizers; changes emit events.
- **`DEFAULT_ADMIN_ROLE` compromise.** Loss or compromise of the admin multisig permits arbitrary role grants. *Mitigation:* hardware-signer multisig with distributed signers; monitoring on `RoleGranted` / `RoleRevoked`; documented rotation procedure.
- **Unaudited mainnet deployment.** Any mainnet deploy before audit sign-off. *Mitigation:* `DeployMainnet.s.sol` reverts unless `AUDIT_ACKNOWLEDGED=true`.

### Assumptions

- EAS is deployed on the target chain and the two Shibui schemas are registered there (see [`script/RegisterSchemas.s.sol`](script/RegisterSchemas.s.sol)).
- The token issuer runs a compliance multisig for `DEFAULT_ADMIN_ROLE`.
- KYC/AML providers issue attestations conforming to the Investor Eligibility schema ([`docs/schemas/schema-definitions.md`](docs/schemas/schema-definitions.md)).
- Integrators accept per-chain attestation posting until cross-chain portability lands.

---

## Documentation

Start here:

- [`README.md`](README.md) — one-page product overview
- [`docs/architecture/enforcement-boundary.md`](docs/architecture/enforcement-boundary.md) — scope boundary (what Shibui does *not* provide)
- [`docs/integration-guide.md`](docs/integration-guide.md) — Path A and Path B integration step-by-step
- [`docs/schemas/schema-definitions.md`](docs/schemas/schema-definitions.md) — Investor Eligibility and Issuer Authorization specs
- [`AUDIT.md`](AUDIT.md) — threat model, launch gate, pre-flight checklist
- [`CHANGELOG.md`](CHANGELOG.md) — release history
- [`diagrams/`](diagrams/) — current architecture diagrams
