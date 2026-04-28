# Gap Analysis: ONCHAINID vs EAS

## Overview

This document compares legacy ONCHAINID capabilities with the current Shibui architecture built on Ethereum Attestation Service (EAS). It focuses on the remaining functional gaps and how Shibui addresses them in its current runtime model. Historical designs that are no longer part of Shibui have been removed to avoid reader confusion.

## Comparison summary

| Dimension | ONCHAINID | Shibui / EAS | Gap status |
|-----------|-----------|--------------|------------|
| Key management | ERC-734 keys | Not part of Shibui verifier scope | Out of scope |
| Multi-wallet identity | Native identity contract model | `EASIdentityProxy` wallet-to-identity binding | Solved |
| Claim / attestation structure | ERC-735 claims | EAS attestations + topic/schema mapping | Solved |
| Revocation | Issuer-controlled claim validity | Attester-controlled EAS revocation | Compatible |
| Cross-chain | CREATE2 identity portability | Chain-specific attestations | Deferred |
| Off-chain attestations | Not native | Not used in current runtime flow | Deferred |
| Trusted party registry | Trusted issuers registry | Trusted-attester registry | Solved |
| Claim topic semantics | ONCHAINID conventions | Same topic IDs mapped to Shibui policies | Solved |

## Dimension 1: Key management

ONCHAINID includes ERC-734 key management. Shibui does not attempt to reproduce that feature because it is outside the verifier's scope. Shibui answers the compliance question — whether a given investor identity satisfies the required claim topics — rather than the wallet-recovery or key-governance question.

**Status:** Out of scope.

## Dimension 2: Multi-wallet identity

ONCHAINID supports multi-wallet identity through the identity contract model. Shibui supports the same operational outcome through `EASIdentityProxy`, which stores wallet-to-identity mappings and lets multiple wallets resolve to the same investor identity for attestation lookup.

Canonical Shibui posture:
- wallet binding is handled by `EASIdentityProxy`
- wallet registration is agent-mediated
- reader-facing docs should not describe wallet-as-identity fallback or self-registration as current behavior

**Status:** Solved by `EASIdentityProxy`.

## Dimension 3: Cross-chain portability

EAS attestations are chain-specific. Shibui therefore requires separate attestations per chain in the current implementation. Multi-chain portability remains a future enhancement rather than a current feature.

**Status:** Deferred.

## Dimension 4: Off-chain attestations

EAS supports off-chain attestations, but Shibui's current runtime flow is based on on-chain attestations that can be validated directly during transfer checks. Off-chain verification remains a future extension rather than part of the current contract semantics.

**Status:** Deferred.

## Dimension 5: Claim / attestation structure

ONCHAINID uses ERC-735 claims. Shibui uses EAS attestations plus two explicit mappings:
- claim topic → schema UID
- claim topic → policy module

The current canonical Investor Eligibility schema is the 10-field EAS payload registered by `RegisterSchemas.s.sol`.

**Status:** Solved by `EASClaimVerifier` plus the schema and policy binding model.

## Dimension 6: Revocation

ONCHAINID revocation is issuer-controlled through claim-validity logic. Shibui relies on EAS revocation, which is immediate and directly observable on-chain. This is compatible with regulated-token compliance checks because a revoked attestation simply stops satisfying the topic on the next `isVerified()` read.

**Status:** Compatible.

## Dimension 7: Trusted party registry

ONCHAINID uses a trusted issuers registry. Shibui uses `EASTrustedIssuersAdapter`, which functions as a trusted-attester registry keyed by claim topic. The trust-change flow is additionally constrained by Schema-2 Issuer Authorization attestations.

Canonical Shibui terminology:
- use **trusted issuer** when describing ONCHAINID / legacy ERC-3643 components
- use **trusted attester** when describing Shibui runtime behavior

**Status:** Solved.

## Summary

| Gap | Resolution | Implementation |
|-----|------------|----------------|
| Key management | Out of scope | Not part of verifier semantics |
| Multi-wallet identity | Wallet-to-identity proxy | `EASIdentityProxy` |
| Claim structure | Topic/schema + topic/policy mapping | `EASClaimVerifier` |
| Trusted party registry | Trusted-attester registry | `EASTrustedIssuersAdapter` |
| Cross-chain | Future enhancement | Deferred |
| Off-chain attestations | Future enhancement | Deferred |
| Revocation | Native EAS revocation | Current runtime behavior |
