# ERC-3643 + Shibui Integration Gas Notes

End-to-end gas numbers captured while proving the pluggable `IIdentityVerifier`
extension point on `EntEthAlliance/ERC-3643` branch
`feat/pluggable-identity-verifier` (commit pinned via `lib/ERC-3643` submodule).

All numbers come from `forge test`/`npx hardhat test` runs on a clean
compilation; no warm-cache or repeat-call optimisation assumed.

## `IdentityRegistry.isVerified` (ERC-3643 default ONCHAINID path)

`isVerified` is a view, so hardhat's gas reporter doesn't surface a direct
number. The effect shows up in the callers that read it:

| Scenario                                      | `ERC20.transfer` gas (avg) | Source |
| --------------------------------------------- | -------------------------: | ------ |
| Upstream baseline (before the extension)      |                    195,248 | hardhat test run on `main`, pre-branch |
| With extension, verifier unset (`address(0)`) |                    197,367 | hardhat test run on `feat/pluggable-identity-verifier` |

Delta per call: **~+2,119 gas** — one additional `SLOAD` to read the new
`_identityVerifier` slot at the top of `isVerified`, which is `0` in the
default case. No branch taken.

## `token.transfer` under Shibui delegation

Captured in `test/integration/ERC3643Token.integration.t.sol` via
`gasleft()` around the call (includes all Shibui verification logic):

| Scenario                                 | `token.transfer` gas |
| ---------------------------------------- | -------------------: |
| Shibui-delegated happy path (4 topics)   |              108,068 |

This is substantially *lower* than the upstream ERC20.transfer number
(~197k) because Shibui's integration test uses `ModularCompliance` with no
modules attached (`canTransfer` returns true without module iteration) and
no frozen-balance logic is exercised. The Shibui verification overhead
itself is bounded by the number of required topics and trusted attesters;
for the 4-topic configuration here it resolves in a single per-topic lookup
per attester.

The key comparison for the upstream PR is the *+~2k gas* introduced on the
default path when the extension is present but inactive (table above).

## `IdentityRegistry.setIdentityVerifier`

| Scenario                 | Gas    |
| ------------------------ | -----: |
| First set (zero → addr)  | 60,178 |
| Clear (addr → zero)      | 38,038 |

One SSTORE + one event emission.

## Methodology Notes

- Upstream hardhat gas-reporter numbers captured from
  `npx hardhat test` inside `ERC-3643-fork/` on branch
  `feat/pluggable-identity-verifier` (all 270 tests passing, 7 new).
- Shibui integration numbers captured from
  `forge test --match-path test/integration/ERC3643Token.integration.t.sol`
  on branch `feat/erc3643-integration` (all 111 tests passing: 107 baseline
  + 4 integration).
- `vm.deployCode` loads pre-built hardhat artifacts so forge doesn't need
  to re-compile the ERC-3643 sources (which pin `solc =0.8.17` / OZ 4.x
  and cannot share a compilation unit with Shibui's `0.8.24` / OZ 5.x).
