# Changelog

All notable changes to Shibui are documented here. Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows [Semantic Versioning](https://semver.org/).

Breaking changes land under **Changed (breaking)** and require a major or minor bump depending on the public API affected. Integrators pinning a specific version should read that section before upgrading.

## [Unreleased]

## [0.4.0] — 2026-04-18

Governance + engineering follow-ups from the structured EEA review (issues #64–#71). No behavioural change to the verifier's hot path; Shibui's runtime semantics are identical to v0.3.0. All changes are to the project's posture — license, directory structure, events, pragma pinning, and CI hygiene — so integrators pinning to v0.3.0 can upgrade without code changes, but will pick up new import paths for the wrapper and new license headers throughout.

### Changed (breaking)

- **Relicensed from MIT to Apache-2.0** (resolves #64). Every `.sol` file in `contracts/`, `script/`, and `test/` now carries `SPDX-License-Identifier: Apache-2.0` and a `Copyright © 2026 Enterprise Ethereum Alliance Inc.` line. Root `LICENSE` added. Both licenses are OSI-approved permissive; anyone holding a prior MIT-licensed snapshot retains MIT rights to that snapshot.
- **`EASClaimVerifierIdentityWrapper` moved** from `contracts/` to `contracts/compat/` (resolves #68). Import path changes for anyone using Path B: `contracts/EASClaimVerifierIdentityWrapper.sol` → `contracts/compat/EASClaimVerifierIdentityWrapper.sol`. The wrapper's behaviour is unchanged; the move signals its EthTrust SL Level-1 classification (vs Level 2 for the core). New `contracts/compat/README.md` documents the boundary.
- **`EASTrustedIssuersAdapter.setEASAddress`** now emits an `EASAddressSet` event (resolves #67). New event added to `IEASTrustedIssuersAdapter`.
- **Solidity pragma pinned to `=0.8.24`** across all production contracts (resolves #66). Floating `^0.8.24` removed from 23 `.sol` files under `contracts/` (mocks keep the caret). Downstream projects building against Shibui sources now get deterministic bytecode.

### Added

- **`CHANGELOG.md`** (resolves #70) — this file. Keep-a-Changelog format.
- **Gitleaks secret-scanning** CI job (resolves #71) on every PR and push.
- **Gas regression guards** on `isVerified` at 1/3/5 topic configurations (resolves #69). `assertLt` ceilings set at current baseline + ~10k headroom; `docs/gas-benchmarks.md` annotated to explain the post-refactor delta is intentional (audit C-1).
- **`contracts/compat/README.md`** — documents the Level-1 audit bar for the compat directory.
- **New tests** for the `EASAddressSet` event: emission, zero-address reject, admin-only gating.

### Changed

- `docs/research/claim-topic-analysis.md` — named KYC / accreditation vendors replaced with category descriptions plus a neutrality disclaimer (resolves #65, EEA antitrust guidance).
- `README.md` — repo layout tree updated for the `contracts/compat/` subdirectory; License section points at the new LICENSE file.

### Tests

- 115 tests passing (was 107 pre-follow-up). Additions: 3 adapter event tests, regression guards on gas benchmarks.

## [0.3.0] — 2026-04-17

Audit-driven refactor. Multiple breaking changes; the pre-refactor API is gone. No production deployment existed at any prior version, so no migration path is provided.

### Changed (breaking)

- `EASTrustedIssuersAdapter.addTrustedAttester(attester, topics)` → `addTrustedAttester(attester, topics, authUID)`. The third argument must reference a live EAS Schema-2 (Issuer Authorization) attestation whose recipient equals the attester and whose `authorizedTopics` is a superset of `topics`. See [`docs/schemas/schema-definitions.md`](docs/schemas/schema-definitions.md).
- `EASTrustedIssuersAdapter.updateAttesterTopics(attester, topics)` takes the same new `authUID` argument.
- Admin surface migrated from OpenZeppelin `Ownable` to `AccessControl`. Roles: `DEFAULT_ADMIN_ROLE`, `OPERATOR_ROLE`, `AGENT_ROLE`. Deploy scripts transfer all roles to a multisig in production.
- `EASClaimVerifier.setIdentityProxy(address(0))` now reverts. Identity proxy is required; there is no "wallet is its own identity" fallback.
- `EASClaimVerifier.registerAttestation` no longer accepts `msg.sender == identity`. Only the attester or an `AGENT_ROLE` holder may register.
- **Investor Eligibility schema** expanded to 10 fields: adds `bytes32 evidenceHash` and `uint8 verificationMethod` to the ABI-encoded payload (audit finding C-7). The schema string changes, so the registered schema UID changes too; any pre-0.3.0 testnet attestations are not compatible and must be re-issued. Greenfield — no production deployment existed at any prior version.

### Added

- `contracts/policies/ITopicPolicy.sol` — single-method predicate interface for per-topic payload validation.
- 8 concrete `ITopicPolicy` modules: KYC, AML, country allow/block-list, accreditation allow-list, professional, institutional, sanctions, source-of-funds.
- `contracts/resolvers/TrustedIssuerResolver.sol` — EAS schema resolver that gates Schema-2 writes to an admin-curated set of authorizers (audit finding C-5).
- `EASClaimVerifier.setTopicPolicy(topic, policy)` admin function + `TopicPolicySet` event.
- `IEASClaimVerifier.PolicyNotConfiguredForTopic` custom error.
- `BridgeHarness` test helper + `PolicyDrivenVerification.t.sol` flagship integration test.
- `docs/architecture/enforcement-boundary.md` — explicit scope boundary document ("what Shibui does NOT provide").

### Fixed

- Payload-aware verification (audit finding C-1): `isVerified` no longer passes an attestation whose decoded payload fails its topic's rule (e.g. `kycStatus = PENDING`, `accreditationType = NONE`).
- Multi-attester resilience (audit finding C-2): `_activeAttestations` single-slot cache removed; verification iterates the trusted-attester list (≤5) so removing a compromised provider doesn't invalidate investors covered by others.

## [0.2.x and earlier]

Pre-audit. Not formally versioned. All APIs referenced in earlier commits predate v0.3.0 and should not be assumed stable.
