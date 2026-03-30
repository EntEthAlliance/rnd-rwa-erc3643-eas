# Identity Architecture Explained

This document explains the full identity architecture story for the EAS-to-ERC-3643 bridge: how ERC-3643 identity works today, what EAS brings, and how the bridge connects them.

**Audience:** Technical readers familiar with Ethereum but who may not know ERC-3643 or EAS in detail.

---

## Section 1: How ERC-3643 Identity Works Today

ERC-3643 (also known as T-REX) is the leading standard for regulated security tokens on Ethereum. At its core, it requires that every token transfer be validated against a compliance framework — and that compliance framework relies on identity verification.

### The ONCHAINID Model

ERC-3643 uses [ONCHAINID](https://github.com/onchain-id/solidity) for identity, which implements two Ethereum standards:

- **ERC-734 (Key Management):** Each identity is a smart contract that manages cryptographic keys with different purposes (management, action, claim signing, encryption)
- **ERC-735 (Claims):** The identity contract stores "claims" — signed statements about the identity holder, issued by trusted third parties

```
┌─────────────────────────────────────────────────────────────┐
│                    ONCHAINID Contract                       │
│  ┌─────────────────┐    ┌────────────────────────────────┐ │
│  │  ERC-734 Keys   │    │        ERC-735 Claims          │ │
│  │  - Management   │    │  - KYC claim from Provider A   │ │
│  │  - Action       │    │  - Accreditation from Firm B   │ │
│  │  - Claim signer │    │  - Country from Provider A     │ │
│  └─────────────────┘    └────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### The Verification Flow

When someone tries to transfer a security token, the following happens:

![Current ERC-3643 Identity Flow](../../diagrams/current-erc3643-identity.mmd)

1. **Token transfer initiated** — User calls `transfer()` on the ERC-3643 token
2. **Compliance check triggered** — Token calls the Compliance Module
3. **Identity lookup** — Compliance Module calls Identity Registry's `isVerified(wallet)`
4. **Identity resolution** — Identity Registry looks up the ONCHAINID contract for that wallet
5. **Claim retrieval** — For each required claim topic (KYC, accreditation, etc.), fetch claims from the ONCHAINID contract
6. **Issuer validation** — For each claim, verify the issuer is in the Trusted Issuers Registry and call `isClaimValid()` on the issuer
7. **Result** — If all required claims are valid and from trusted issuers, transfer proceeds

### The Pain Points

While ONCHAINID works, it creates several challenges:

| Pain Point | Impact |
|------------|--------|
| **Per-user contract deployment** | Every investor needs their own ONCHAINID smart contract deployed — gas costs and complexity |
| **Vendor lock-in** | Only KYC providers that support the ONCHAINID claim format can participate |
| **Limited provider ecosystem** | Smaller market of compatible identity providers means less competition and higher costs |
| **No cross-chain portability** | An ONCHAINID on Ethereum doesn't help on Base or Arbitrum — investors must re-verify |
| **Proprietary claim format** | ERC-735 claims are specific to ONCHAINID; credentials from other systems don't work |

---

## Section 2: What EAS Brings to the Table

[Ethereum Attestation Service (EAS)](https://attest.sh) is a general-purpose attestation layer that's become the standard for on-chain credentials across the Ethereum ecosystem.

### What is an Attestation?

An attestation is simply a signed statement on-chain: "I (the attester) attest that this (the data) is true about this address (the recipient)."

```
┌─────────────────────────────────────────────────────────┐
│                    EAS Attestation                      │
│                                                         │
│  Attester: 0xKYCProvider...                            │
│  Recipient: 0xInvestor...                              │
│  Schema: "address identity, uint8 kycStatus, ..."      │
│  Data: { kycStatus: VERIFIED, country: 840, ... }      │
│  Created: 2024-01-15                                   │
│  Revoked: No                                           │
│  Expires: 2025-01-15                                   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Why EAS is Gaining Adoption

EAS has become the attestation standard for major protocols and platforms:

- **Coinbase** — Uses EAS for Coinbase Verifications (onchain KYC)
- **Optimism** — Uses EAS for governance attestations and identity
- **Gitcoin Passport** — Issues EAS attestations for sybil resistance
- **Base** — Native EAS integration for identity and reputation

The ecosystem has converged on EAS because it's:

- **Multi-chain** — Deployed on Ethereum, Base, Arbitrum, Optimism, and more
- **Open** — Anyone can create attestations; anyone can verify them
- **Composable** — Attestations can reference each other; schemas are reusable
- **Schema-based** — Flexible data structures without protocol upgrades

### EAS vs ONCHAINID Claims: Key Differences

| Aspect | ONCHAINID (ERC-735) | EAS |
|--------|---------------------|-----|
| **Storage** | Per-user identity contract | Central EAS contract |
| **Data format** | Fixed claim structure | Flexible schemas |
| **Deployment** | Deploy contract per user | No deployment needed |
| **Revocation** | Issuer calls `revokeClaim()` | Attester calls `revoke()` |
| **Expiration** | Encoded in claim data | Native + data-level |
| **Cross-chain** | Separate contracts per chain | Same schema, attestation per chain |
| **Ecosystem** | ONCHAINID-specific providers | Growing EAS ecosystem |

---

## Section 3: How the Bridge Works

The EAS-to-ERC-3643 bridge lets security tokens accept EAS attestations as proof of investor eligibility — without changing the ERC-3643 standard or requiring token contract modifications.

### Architecture Overview

![Architecture Overview](../../diagrams/architecture-overview.mmd)

The bridge consists of four contracts that sit between the ERC-3643 Identity Registry and EAS:

| Contract | Role |
|----------|------|
| **EASClaimVerifier** | Core verification logic — checks if a wallet has valid EAS attestations for all required claim topics |
| **EASTrustedIssuersAdapter** | Manages which EAS attester addresses are trusted for which claim topics |
| **EASIdentityProxy** | Maps wallet addresses to identity addresses for multi-wallet support |
| **EASClaimVerifierIdentityWrapper** | (Path B only) IIdentity-compatible wrapper for zero-modification integration |

### Before and After

![Before and After](../../diagrams/bridge-before-after.mmd)

**Before (closed system):**
- Token issuer must use ONCHAINID-compatible KYC providers
- Each investor deploys an ONCHAINID identity contract
- Claims are locked in a proprietary format

**After (open attestation layer):**
- Token issuer can accept attestations from any EAS-compatible KYC provider
- Investors reuse existing EAS attestations — no new contracts
- Standard attestation format works across the ecosystem

### The Verification Flow Step by Step

![Transfer Verification Flow](../../diagrams/transfer-verification-flow.mmd)

When `isVerified(wallet)` is called on the EASClaimVerifier:

1. **Resolve identity** — Query `EASIdentityProxy` to map wallet → identity address. If no mapping exists, use the wallet address directly.

2. **Get required topics** — Query the ERC-3643 Claim Topics Registry to get the list of required claim topics (e.g., KYC, accreditation).

3. **For each required topic:**
   - Get the EAS schema UID mapped to this topic
   - Get the list of trusted attesters for this topic from `EASTrustedIssuersAdapter`
   - Look up registered attestations for this identity/topic combination
   - Query EAS to fetch the attestation data

4. **Validate each attestation:**
   - Attestation exists (UID is not zero)
   - Schema matches the expected schema for this topic
   - Attester is in the trusted attesters list
   - Not revoked (`revocationTime == 0`)
   - Not expired (both EAS-level and data-level expiration)

5. **Return result** — `true` only if every required topic has at least one valid attestation from a trusted attester.

### Multi-Wallet Identity

![Wallet Identity Mapping](../../diagrams/wallet-identity-mapping.mmd)

The `EASIdentityProxy` enables multi-wallet support:

- An investor can link multiple wallets to a single identity address
- Attestations are made to the identity address
- Verification checks any linked wallet against the identity's attestations

```
Wallet A ──┐
           │
Wallet B ──┼──► Identity 0x123 ◄── EAS Attestations
           │
Wallet C ──┘
```

This mirrors ONCHAINID's multi-wallet capability but without per-user contract deployment.

---

## Section 4: Integration Paths

The bridge supports two integration paths depending on whether you can modify the Identity Registry.

### Path A: Pluggable Verifier (Recommended)

![Dual Mode Verification](../../diagrams/dual-mode-verification.mmd)

**When to use:** New ERC-3643 deployments or when you can modify the Identity Registry.

The Identity Registry is modified to call `EASClaimVerifier.isVerified()` as an alternative verification path:

```solidity
function isVerified(address userAddress) external view returns (bool) {
    // Try ONCHAINID first (optional)
    if (_verifyOnchainId(userAddress)) return true;

    // Try EAS path
    if (address(easClaimVerifier) != address(0)) {
        return easClaimVerifier.isVerified(userAddress);
    }

    return false;
}
```

**Advantages:**
- Clean separation of concerns
- Can support both ONCHAINID and EAS simultaneously
- Native integration with full control

### Path B: Identity Wrapper (Zero-Modification)

**When to use:** Existing ERC-3643 tokens already in production where you cannot modify the Identity Registry.

Deploy `EASClaimVerifierIdentityWrapper` for each identity. The wrapper implements the `IIdentity` interface, so the existing Identity Registry sees it as a standard ONCHAINID contract:

```solidity
// Wrapper translates EAS attestations to IIdentity interface
contract EASClaimVerifierIdentityWrapper is IIdentity {
    function getClaim(bytes32 claimId) external view returns (...) {
        // Translate to EAS attestation lookup
    }
}
```

**Advantages:**
- Works with deployed ERC-3643 tokens without any contract changes
- Drop-in replacement — register wrapper address in IdentityRegistryStorage
- Backwards compatible

**Trade-offs:**
- More complex implementation
- Per-identity deployment overhead
- Emulates ONCHAINID interface rather than native integration

---

## Section 5: Compliance & Revocation

### Real-Time Revocation

![Revocation Flow](../../diagrams/revocation-flow.mmd)

EAS provides immediate, on-chain revocation. When a KYC provider needs to revoke access:

1. **AML alert triggered** — Investor fails ongoing compliance check
2. **Attestation revoked** — KYC provider calls `EAS.revoke(attestationUID)`
3. **Revocation recorded** — EAS sets `revocationTime = block.timestamp`
4. **Transfer blocked** — Next `isVerified()` check sees revocation, returns `false`
5. **Immediate effect** — Investor cannot buy, sell, or receive the token

This happens automatically and on-chain — no manual intervention, no delays.

### Provider Trust Management

Token issuers control which KYC providers they trust:

```solidity
// Add a KYC provider as trusted for KYC and accreditation topics
uint256[] memory topics = new uint256[](2);
topics[0] = 1; // KYC
topics[1] = 7; // Accreditation
adapter.addTrustedAttester(kycProviderAddress, topics);

// Remove trust (invalidates ALL attestations from this provider)
adapter.removeTrustedAttester(kycProviderAddress);
```

Removing a trusted attester immediately invalidates all attestations from that provider — useful if a provider is compromised or loses their license.

### Attestation Lifecycle

![Attestation Lifecycle](../../diagrams/attestation-lifecycle.mmd)

An attestation goes through these states:

1. **Created** — KYC provider issues attestation via EAS
2. **Registered** — Attestation UID registered in EASClaimVerifier for efficient lookup
3. **Active** — Investor can hold and transfer tokens
4. **Verified** — Each transfer triggers re-verification (checks revocation and expiration)
5. **Revoked** — Provider revokes; investor immediately blocked
6. **Expired** — Attestation passes expiration timestamp; investor blocked until re-verification

### Why This Matters for Regulated Securities

Security tokens have strict compliance requirements:

- **Real-time enforcement** — Regulators expect immediate action when an investor fails compliance
- **Audit trail** — Every attestation and revocation is recorded on-chain
- **Provider accountability** — Clear record of which provider issued which attestation
- **Cross-token coordination** — Revoke once, affect all tokens using that attestation

The bridge maintains these guarantees while opening up the identity layer.

---

## Section 6: Multi-Chain Vision

### One KYC, Many Chains

![Multi-Chain Reuse](../../diagrams/multi-chain-reuse.mmd)

EAS is deployed on multiple chains with the same interface. An investor verified once can have attestations on every chain where they hold security tokens:

```
┌─────────────────────────────────────────────────────────────┐
│                     KYC Provider                            │
│                          │                                  │
│        ┌─────────────────┼─────────────────┐               │
│        ▼                 ▼                 ▼               │
│   ┌─────────┐      ┌─────────┐      ┌─────────┐           │
│   │Ethereum │      │  Base   │      │Arbitrum │           │
│   │   EAS   │      │   EAS   │      │   EAS   │           │
│   └────┬────┘      └────┬────┘      └────┬────┘           │
│        │                │                │                 │
│        ▼                ▼                ▼                 │
│   Token A          Token B          Token C                │
│   (Real estate)    (Treasury)       (Private equity)       │
└─────────────────────────────────────────────────────────────┘
```

### EAS Network Support

EAS is live on:

| Network | EAS Contract |
|---------|--------------|
| Ethereum Mainnet | `0xA1207F3BBa224E2c9c3c6D5aF63D0eb1582Ce587` |
| Base | `0x4200000000000000000000000000000000000021` |
| Arbitrum | `0xbD75f629A22Dc1ceD33dDA0b68c546A1c035c458` |
| Optimism | `0x4200000000000000000000000000000000000021` |
| Sepolia (testnet) | `0xC2679fBD37d54388Ce493F1DB75320D236e1815e` |

### Cross-Chain Attestation Strategy

For V1, attestations are created per-chain. This is simple and matches how token deployments work:

1. Investor verifies with KYC provider (off-chain process)
2. KYC provider issues attestation on each chain where investor holds tokens
3. Each token's bridge verifies against its local EAS

**V2 roadmap** includes cross-chain attestation bridging via LayerZero or similar, enabling true "verify once, valid everywhere."

---

## Section 7: Stakeholder Guide

![Stakeholder Interactions](../../diagrams/stakeholder-interactions.mmd)

### Token Issuer

**What you do:**
- Deploy bridge contracts alongside your ERC-3643 token
- Configure required claim topics (KYC, accreditation, country, etc.)
- Add trusted attesters (KYC providers you accept)
- Monitor compliance via on-chain events

**What you see:**
- Which KYC providers have issued attestations for your investors
- Real-time verification status of any wallet
- Audit trail of all attestations and revocations

**What you care about:**
- Regulatory compliance — every investor properly verified
- Provider flexibility — not locked into one KYC vendor
- Operational efficiency — automated verification, no manual review

### KYC / Identity Provider

**What you do:**
- Complete off-chain KYC/AML verification of investors
- Issue EAS attestations with verified information
- Revoke attestations when investors fail ongoing checks
- Maintain your attester address security

**What you see:**
- List of tokens that trust your attestations
- Investors you've verified
- Revocation requests and compliance alerts

**What you care about:**
- Market access — your attestations accepted by many tokens
- Reputation — accurate verifications, timely revocations
- Efficiency — verify once, attestation works everywhere

### Investor

**What you do:**
- Complete KYC with an EAS-compatible provider
- Link your wallets to your identity (optional, for multi-wallet)
- Hold and trade security tokens

**What you see:**
- Your EAS attestations and their status
- Which tokens accept your attestations
- Expiration dates for re-verification

**What you care about:**
- Convenience — KYC once, access many tokens
- Privacy — only necessary information shared
- Portability — attestations work across chains and tokens

### Compliance Officer

**What you do:**
- Configure trusted attesters for your token
- Monitor investor verification status
- Respond to compliance alerts (coordinate with KYC providers for revocations)
- Generate audit reports from on-chain data

**What you see:**
- Real-time dashboard of investor compliance status
- Attestation details for any investor
- Historical audit trail

**What you care about:**
- Regulatory compliance — meet all requirements
- Audit readiness — complete on-chain records
- Rapid response — immediate effect when revoking access

---

## Further Reading

- [System Architecture](system-architecture.md) — Technical component reference and dependencies
- [Data Flow](data-flow.md) — Operation-by-operation data flows
- [Integration Guide](../integration-guide.md) — Step-by-step integration instructions
- [Schema Definitions](../schemas/schema-definitions.md) — EAS schema specifications
- [Gap Analysis](../research/gap-analysis.md) — Detailed ONCHAINID vs EAS comparison
