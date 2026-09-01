# PR: Demo integration: seeding, regression suite, VLEIPolicy tests, vLEI wiring

**Base:** `deploy/sepolia` (`87009d1`) · **Head:** `fix/sepolia-deploy-wiring` · **2 commits**

## What this PR does

Makes the Sepolia demo real, tested, and regression-locked. It stacks on the
wiring fix (commit 1) and closes every remaining gap between "contracts
deployed" and "demo works": one command seeds Alice/Bob/Carol on real EAS,
one test suite locks the three demo storylines to on-chain behavior, and the
untested `VLEIPolicy` from PR #98 gets full coverage plus the topic wiring it
was missing.

Simplest-solution choices, made deliberately:
- **No new abstractions.** The scenario test reuses the existing
  `BridgeHarness`; `SeedDemo` reuses the existing single-admin testnet model.
- **Identity = wallet.** `EASIdentityProxy.getIdentity` already falls back to
  self-identity for unregistered wallets, so the demo needs zero proxy
  registrations. The orphaned draft's `registerWallet` block was dead code
  (its `== address(0)` guard can never be true): removed.
- **No core-contract changes.** Fail-closed on empty topics stays a
  follow-up through the audit gate (guarded operationally by
  `VerifyDeployment`).

## Commit 1: `fix(deploy)` (carried, rebased onto `87009d1`)

Wiring fix + `ClaimTopicsRegistry` + orchestrated `DeploySepolia` +
`VerifyDeployment` smoke test + runbook. Unchanged from prior review; see
`docs/deployment-runbook.md`.

## Commit 2: `feat(demo)`

### `script/SeedDemo.s.sol` (new)
Seeds the three demo investors on **real** EAS (Sepolia / Base Sepolia): previously only the MockEAS-only `SetupPilot` existed. Single admin key acts
as authorizer → Schema-2 self-authorization → trusted attester →
InvestorEligibility attestation per investor → per-topic registration.
Idempotent per step; prints wallets + UIDs to paste into
`deployments/sepolia.json#demo`. Also fixes a latent demo-breaker: the
deployed `AccreditationPolicy` allow-set is **empty** (DeployTestnet ships it
that way), so even Alice would fail topic 7: the script allows type 2
(ACCREDITED) when missing.

### `test/scenarios/DemoFlow.t.sol` (new: the demo regression suite)
7 tests locking the demo storylines end-to-end on `BridgeHarness` +
`DemoERC3643Token`:
- Alice verified; transfer Alice→Carol clears.
- Bob unverified (accreditationType 0 → topic 7 fails); Alice→Bob reverts
  `DemoTransferBlocked`.
- Carol verified → attester revokes on EAS → next transfer blocked, both
  directions. The demo's live-revocation moment, as an assertion.
- Mint to unverified reverts (see comment fix below).

### `contracts/demo/DemoERC3643Token.sol` (comment-only fix)
The test suite caught a contradiction: the comment claimed "mints skip the
compliance gate" but the code checks the recipient on mint: and the **code**
is correct (T-REX semantics: tokens are only ever delivered to verified
investors). Comment corrected to match behavior; zero bytecode change.

### `test/unit/policies/VLEIPolicy.t.sol` (new)
PR #98 shipped `VLEIPolicy` with no tests. 10 tests covering all four
validate() gates: decode safety (empty, malformed, and a cross-schema
InvestorEligibility payload: none revert, all return false), zero-SAID
rejection, staleness including the exact-boundary case, credType matching,
constructor guards.

### `script/ConfigureBridge.s.sol` (extended)
PR #98 added topics 15/16 but nothing wires them: without a
`setTopicSchemaMapping` + `setTopicPolicy` for those topics, the verifier
rejects every vLEI attestation. Added as env-gated optional wiring
(`VLEI_BRIDGE_SCHEMA_UID`, `VLEI_LE_POLICY`, `VLEI_ROLE_POLICY`); fully
skipped when unset, so nothing changes for non-vLEI deployments.

## PR #98 review notes (folded in or dispositioned)

| Finding | Disposition |
|---|---|
| `VLEIPolicy` untested | 10 unit tests added (this PR) |
| Topics 15/16 unwired: vLEI attestations unusable | Optional wiring in `ConfigureBridge` (this PR) |
| Revocation/expiry not checked in policy | Correct by design: verified the verifier core checks `revocationTime`/`expirationTime` before invoking any policy (`EASClaimVerifier.sol:239-240`) |
| `_tryDecode` external with underscore prefix; callable by anyone | Harmless (pure, no state); lint-level. Left as-is to keep this PR out of PR #98's diff: note for a cleanup pass |
| `deployments/sepolia.json#shibui.vlei` placeholders zero | Stays zero until VLEIPolicy instances deploy; `ConfigureBridge` env vars are the fill-in path |

## Test evidence

- Full regression: **11 suites, 113 tests, 0 failed** (integration suite
  excluded: requires pre-built ERC-3643 hardhat artifacts, unchanged by
  this PR).
- New coverage: `ClaimTopicsRegistry` 10/10, `VLEIPolicy` 10/10,
  `DemoFlow` 7/7.
- `forge build` clean (pre-existing style lints only).

## How to run the demo after merge

```bash
# 1. Repair/complete the live deployment (once) — see docs/deployment-runbook.md
REQUIRED_TOPICS=1,2,7,13 ... forge script script/ConfigureBridge.s.sol --broadcast

# 2. Smoke test
VERIFIER_ADDRESS=0xD096...2153 forge script script/VerifyDeployment.s.sol

# 3. Seed the demo investors
PRIVATE_KEY=... VERIFIER_ADDRESS=... ADAPTER_ADDRESS=... RESOLVER_ADDRESS=... \
ACCREDITATION_POLICY=0x29Bf...93Db \
INVESTOR_ELIGIBILITY_SCHEMA_UID=0x5019...414c \
ISSUER_AUTHORIZATION_SCHEMA_UID=0x8b49...d7c8 \
forge script script/SeedDemo.s.sol --rpc-url "$RPC_SEPOLIA" --broadcast

# 4. Demo token
EAS_CLAIM_VERIFIER=0xD096...2153 DEPLOYER_PRIVATE_KEY=... \
forge script script/deploy/DeployDemo.s.sol --rpc-url "$RPC_SEPOLIA" --broadcast

# 5. Carol's live revocation moment (UID printed by SeedDemo)
cast send $EAS "revoke((bytes32,(bytes32,uint256)))" "($SCHEMA_UID,($CAROL_UID,0))" \
  --private-key $PRIVATE_KEY --rpc-url "$RPC_SEPOLIA"
```

Note `REQUIRED_TOPICS=1,2,7,13`: topic 7 (ACCREDITATION) must be in the
required set or Bob's storyline has no teeth. Paste SeedDemo's printed
wallets/UIDs into `deployments/sepolia.json#demo` in the same PR that
records the seeding.
