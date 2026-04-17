# Shibui Scope and Enforcement Boundary

> Shibui is an **attestation retrieval adapter** for ERC-3643 identity verification. It decides whether an investor's attestations satisfy an issuer's stated eligibility policy at a point in time. It does **not** implement token-side enforcement.

This document exists to address audit findings R-1 and R-3, which noted that earlier documentation described Shibui as a "full identity layer for regulated securities," creating a risk that integrators would assume primitives that live elsewhere are provided here.

## What Shibui provides

- A payload-aware `isVerified(wallet) → bool` query answerable by the ERC-3643 compliance layer or any downstream consumer.
- Per-topic policy modules (`ITopicPolicy`) that enforce decoded attestation semantics (KYC status, accreditation type, country allow-list, sanctions status, source-of-funds, professional/institutional classification).
- A cryptographic audit trail for who authorizes whom, via EAS Schema 2 (Issuer Authorization) and the `TrustedIssuerResolver` contract.
- Role-separated administration via `AccessControl` (`DEFAULT_ADMIN_ROLE`, `OPERATOR_ROLE`, `AGENT_ROLE`).

## What Shibui does NOT provide

The following primitives are the responsibility of the **token contract** (the ERC-3643 implementation) or of off-chain operational tooling. Integrators must implement or select these separately. Revoking a Shibui attestation or removing a trusted attester does **not** substitute for any of them.

| Primitive | Why it matters | Where it lives |
|---|---|---|
| `forcedTransfer` | Court-ordered movement of tokens without the holder's signature. Without it, a regulator cannot enforce an order. | ERC-3643 `Token.forcedTransfer()` — agent-gated. |
| Account freeze / partial freeze | OFAC or sanctions compliance often requires freezing specific balances immediately, not just blocking future transfers. | ERC-3643 `Token.freezePartialTokens()` — agent-gated. |
| Recovery address | Lost-key recovery binds a replacement wallet to the same investor identity. | ERC-3643 `Token.recoveryAddress()` flow — uses the token's Identity Registry directly. |
| Lock-up schedules, per-investor caps, ownership limits | Reg D 506(b) 35-investor rule, holding-period restrictions, concentration limits. | ERC-3643 compliance modules; outside Shibui's scope. |
| Cross-chain attestation canonicity | One KYC on chain A does **not** automatically satisfy verification on chain B. EAS attestations are per-chain. | Deferred to Shibui V2 roadmap (attestation mirroring). |
| Off-chain attestation verification (privacy-preserving) | Keeps sensitive KYC data out of the public ledger. | Deferred to Shibui V2 roadmap. |
| Custom revocation logic (e.g. "revoke after N transfers") | EAS supports only binary revoke/not-revoke. Complex rules must be computed off-chain and materialised via `eas.revoke()`. | Off-chain compliance tooling. |
| Evidence storage (KYC files, accreditation letters) | Auditors and examiners need the underlying documents, not just an on-chain hash. | Schema v2 carries `evidenceHash` + `verificationMethod`; the bytes themselves live with the KYC provider. |
| Tax withholding / FATCA-CRS reporting | Reporting flows to tax authorities. | Outside Shibui's scope. |

## How to use Shibui correctly

1. Your ERC-3643 token contract calls `EASClaimVerifier.isVerified(wallet)` from its `canTransfer` / `_beforeTokenTransfer` compliance hook.
2. If `isVerified` returns `true`, the transfer is permitted by the identity layer. Other ERC-3643 compliance modules (lock-ups, concentration limits, etc.) still apply independently.
3. If `isVerified` returns `false`, the transfer is blocked. The reasons (missing attestation, revoked, expired, policy failed) are surfaced via events and via `getRegisteredAttestation` for debugging.
4. Enforcement actions (freeze, forced transfer, recovery) are dispatched on the token contract, not on Shibui.

## Operational boundary in practice

A concrete example of the separation:

> An investor fails an AML re-check. The compliance operator revokes the investor's KYC attestation via `eas.revoke(...)`. Within the next block, `isVerified(investorWallet)` returns `false`, so the token contract blocks all future transfers involving that wallet.
>
> This does **not**:
> - return the investor's existing balance to the issuer,
> - prevent the investor from receiving airdrops or dividends that are distributed by external contracts not gated by `isVerified`,
> - satisfy any regulator order to freeze or seize tokens already held.
>
> For those, the token's agent executes `freezePartialTokens` or `forcedTransfer` on the token contract itself.
