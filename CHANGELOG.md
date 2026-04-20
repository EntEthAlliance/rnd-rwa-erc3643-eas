# Changelog

All notable changes to Shibui are documented here. Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows [Semantic Versioning](https://semver.org/).

Breaking changes land under **Changed (breaking)** and require a major or minor bump depending on the public API affected. Integrators pinning a specific version should read that section before upgrading.

## [Unreleased]

## [0.3.0] — 2026-04-17

Audit-driven refactor. Multiple breaking changes; the pre-refactor API is gone. No production deployment existed at any prior version, so no migration path is provided.

### Changed (breaking)

- `EASTrustedIssuersAdapter.addTrustedAttester(attester, topics)` → `addTrustedAttester(attester, topics, authUID)`. The third argument must reference a live EAS Schema-2 (Issuer Authorization) attestation whose recipient equals the attester and whose `authorizedTopics` is a superset of `topics`. See [`docs/schemas/schema-definitions.md`](docs/schemas/schema-definitions.md).
- `EASTrustedIssuersAdapter.updateAttesterTopics(attester, topics)` takes the same new `authUID` argument.
- Admin surface migrated from OpenZeppelin `Ownable` to `AccessControl`. Roles: `DEFAULT_ADMIN_ROLE`, `OPERATOR_ROLE`, `AGENT_ROLE`. Deploy scripts transfer all roles to a multisig in production.
- `EASClaimVerifier.setIdentityProxy(address(0))` now reverts. Identity proxy is required; there is no "wallet is its own identity" fallback.
- `EASClaimVerifier.registerAttestation` no longer accepts `msg.sender == identity`. Only the attester or an `AGENT_ROLE` holder may register.
- Investor Eligibility schema bumped from v1 to **v2**: adds `bytes32 evidenceHash` and `uint8 verificationMethod` to the ABI-encoded payload. The Schema UID changes as a result; any testnet v1 attestations are no longer compatible.

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
