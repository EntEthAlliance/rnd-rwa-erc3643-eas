# Draft PR / Issue for ERC-3643 Community

**Target:** `TokenySolutions/EIP3643` (or share directly with Ori)

---

## Title

**EAS Identity Bridge: Enabling ERC-3643 Compliance with Ethereum Attestation Service**

## Body

### Summary

We've built a working bridge that allows ERC-3643 security tokens to accept [EAS (Ethereum Attestation Service)](https://attest.sh) attestations as proof of investor eligibility — alongside or instead of traditional ONCHAINID claims.

Full implementation: **[github.com/claudyfaucant/eas-erc3643-bridge](https://github.com/claudyfaucant/eas-erc3643-bridge)**

This is shared as a conversation starter, not a formal EIP amendment. We'd love feedback from the ERC-3643 community.

---

### The Problem

ERC-3643 relies on ONCHAINID (ERC-734/735) for identity verification. While this works, it creates practical challenges for adoption:

- **Per-user contract deployment** — Every investor needs an ONCHAINID smart contract, adding gas costs and onboarding friction
- **Limited provider ecosystem** — Only KYC providers supporting the ONCHAINID claim format can participate
- **No cross-chain portability** — An ONCHAINID on Ethereum doesn't carry over to Base, Arbitrum, or Optimism
- **Closed identity layer** — Credentials issued through EAS (now used by Coinbase, Optimism, Gitcoin Passport, Base) can't be used for ERC-3643 compliance

As tokenized real-world assets scale across L2s, these constraints become real bottlenecks.

---

### What the Bridge Does

The bridge introduces an `EASClaimVerifier` that maps ERC-3643 claim topics to EAS schemas, allowing the existing `isVerified()` flow to check EAS attestations instead of (or in addition to) ONCHAINID claims.

**Two integration paths:**

| | Path A: Native | Path B: Wrapper |
|---|---|---|
| **For** | New deployments | Existing deployed tokens |
| **How** | Deploy with `EASIdentityRegistry` | Wrap existing registry with `EASVerificationWrapper` |
| **Contract changes** | Uses EAS-native registry | Zero modifications to token contracts |
| **Verification** | EAS-first, ONCHAINID fallback | Check EAS, then delegate to original registry |

**Key features:**
- Dual verification (EAS + ONCHAINID) — migration path, not a hard switch
- Multi-wallet identity support — one KYC attestation covers multiple wallets
- Trusted attester management — token issuers control which KYC providers are accepted
- Schema-based flexibility — new compliance requirements = new schemas, no protocol upgrade
- Cross-chain by design — same attestation schema works on every EAS-supported chain

---

### Gas Benchmarks

All numbers from Foundry test suite (Solidity 0.8.24, optimizer 200 runs):

| Operation | Gas |
|-----------|-----|
| `isVerified()` — 1 topic | ~27,878 |
| `isVerified()` — 3 topics | ~57,309 |
| Create EAS attestation | ~217,853 |
| Register wallet to identity | ~76,019 |

For comparison, deploying an ONCHAINID contract costs ~1.5M gas. An EAS attestation costs ~218K gas — **~85% cheaper** for initial investor onboarding. On L2s (Base, Arbitrum), these costs drop by 97-99%.

---

### What's Implemented

- ✅ `EASClaimVerifier` — Core verification logic (schema mapping, attester checks, expiration)
- ✅ `EASIdentityRegistry` — Drop-in EAS-native identity registry
- ✅ `EASVerificationWrapper` — Zero-modification wrapper for existing deployments
- ✅ `EASIdentityProxy` — Multi-wallet identity management
- ✅ Full test suite (200/200 passing)
- ✅ Deployment scripts (Foundry)
- ✅ Documentation: architecture, integration guide, gas benchmarks, schema specs

---

### What We're Looking For

1. **Feedback on the approach** — Is the dual-verification (EAS + ONCHAINID) migration path the right abstraction? Are there compliance scenarios we're missing?

2. **Schema standardization** — We've defined schemas for Investor Eligibility, Issuer Authorization, and Wallet-Identity Link. Should these be formalized as recommended schemas for the ERC-3643 ecosystem?

3. **Integration interest** — Any token issuers or identity providers interested in piloting this? The wrapper (Path B) works with any existing ERC-3643 deployment without contract changes.

4. **EIP extension** — Would it make sense to propose this as a formal extension to ERC-3643? We see this as complementary to the standard, not a replacement.

---

### Context

This was built by the [Enterprise Ethereum Alliance](https://entethalliance.org) as part of our work on enterprise-grade identity infrastructure for tokenized assets. EEA members include organizations actively deploying ERC-3643 tokens and building on EAS.

We believe the next wave of tokenized securities needs an open, multi-chain identity layer — and ERC-3643 + EAS is the right combination.

Happy to discuss, answer questions, or jump on a call.

**Redwan Meslem**
Executive Director, Enterprise Ethereum Alliance
