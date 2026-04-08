# Modular Identity Layer for ERC-3643: Beyond Vendor-Locked Claims

## The Question

Should ERC-3643 mandate a specific identity implementation, or should the standard define **what** compliance checks are needed while remaining agnostic about **how** they're implemented?

Today, ERC-3643 is tightly coupled to ONCHAINID (ERC-734/735). While ONCHAINID works, this coupling creates practical constraints:

- **Tooling dependency** — deploying and managing ERC-3643 tokens in practice requires vendor-specific infrastructure around ONCHAINID
- **Per-investor contract deployment** — every investor needs a dedicated identity contract (~1.5M gas per chain)
- **Claim issuance friction** — only providers integrated with the ONCHAINID claim format can participate

Meanwhile, the broader Ethereum ecosystem has converged on open attestation infrastructure — notably [EAS](https://attest.sh) (used by Coinbase, Optimism, Gitcoin Passport, Base) — that can express the same compliance facts but can't plug into ERC-3643 today.

## Proposed Direction

A **modular claim interface** for ERC-3643 that separates the compliance verification logic from the identity implementation:

- `isVerified()` should be able to check claims from **any** attestation source — not just ONCHAINID
- Token issuers choose their identity backend: ONCHAINID, EAS, or future systems
- The standard defines the **compliance interface**, not the plumbing underneath

This is the same philosophy ERC-7943 got right — defining `canSend`/`canReceive`/`canTransfer` without prescribing identity infrastructure.

## Proof of Concept

We've built a working implementation: **[eas-erc3643-bridge](https://github.com/claudyfaucant/eas-erc3643-bridge)**

- Maps ERC-3643 claim topics to EAS schemas
- Dual verification (EAS + ONCHAINID coexist) — migration path, not a hard switch
- Zero-modification wrapper for existing deployed tokens
- Full test suite (200/200), gas benchmarks, docs

**Key numbers:** EAS attestation costs ~218K gas vs ~1.5M for ONCHAINID identity deployment. On L2s, 97-99% cheaper.

## Valence Migration Spike Checklist (Implementation Tracking)

- [x] Add Valence scaffold contracts (`contracts/valence/*`)
- [x] Add compile/deploy + selector metadata tests
- [x] Add architecture comparison: raw EIP-2535 vs Valence kernel approach
- [x] Document coexistence with existing production path
- [ ] Complete selector routing integration with real kernel API
- [ ] Complete storage migration plan + replay tooling
- [ ] Port trusted attester and identity mapping responsibilities into dedicated orbitals
- [ ] Validate parity + upgrade safety before any cutover decision

## Questions for Discussion

1. Should ERC-3643 evolve toward a **pluggable identity interface** rather than mandating ONCHAINID?
2. What's the right abstraction layer — should the standard define a claim verification interface that multiple backends can implement?
3. Are other teams building ERC-3643 tokens and running into identity infrastructure constraints?

Built by the [Enterprise Ethereum Alliance](https://entethalliance.org). We believe the compliance layer for regulated tokens should be **open infrastructure** — not a proprietary middleware.
