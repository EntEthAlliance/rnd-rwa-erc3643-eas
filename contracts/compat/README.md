# contracts/compat/

Compatibility shims. **Not** part of the production verification path.

Contracts under this directory are targeted at EEA EthTrust Security Level **1**, not Level 2. They exist to unblock specific integration cases where the primary Shibui contracts (under `contracts/`) cannot be wired directly — typically because an existing ERC-3643 deployment's Identity Registry Storage is immutable and its on-chain `IIdentity` expectations must be satisfied by a shim.

Do not use anything in this directory for a new deployment. Use the payload-aware verifier in the parent `contracts/` directory (Path A integration) instead. See [`docs/integration-guide.md`](../../docs/integration-guide.md) for the decision matrix.

## What lives here

### `EASClaimVerifierIdentityWrapper.sol`

Read-compat shim that exposes EAS attestations behind the `IIdentity` / ERC-735 / ERC-734 interface. Deliberate non-features:

- `isClaimValid()` does **not** run topic policies; it only checks attestation existence, revocation, and EAS-level expiration.
- `addKey`, `removeKey`, `execute`, `approve`, `addClaim`, `removeClaim` all revert.
- `getClaim` returns empty `signature` bytes. ERC-3643 consumers that re-verify claim signatures out-of-band will fail.
- `getClaim` iterates the (attester × topic) space bounded by `MAX_ATTESTERS × MAX_TOPICS_PER_ATTESTER` = 50 × 15 = 750 combinations per call. Not suitable for hot paths without an external cache.
- `identityAddress` is immutable; no recovery flow.

Every one of these is documented in the contract's NatSpec, and is asserted by `test/unit/EASClaimVerifierIdentityWrapper.t.sol` — the tests exist specifically to prevent silent regressions that would elevate the shim to a role it shouldn't play.

## Audit bar

Contracts under `contracts/` are audited to EthTrust SL Level 2. Contracts under `contracts/compat/` are documented explicitly as Level 1. If a Level-2 audit finding applies to something here and the finding is out-of-scope for a compat shim, it is acceptable to note the finding in the PR description and leave it unaddressed. Do not silently raise the bar by moving a file out of `compat/` without a separate audit cycle.
