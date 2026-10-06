# Shibui and ERC-3643: integration status

Status checked October 6, 2026. Shibui is an EEA research model; its specification is not an adopted ERC-3643 standard.

## What has been implemented

Shibui's [integration PR #63](https://github.com/EntEthAlliance/rnd-rwa-erc3643-eas/pull/63) merged on April 20, 2026. The repository includes end-to-end token tests against the EEA-modified ERC-3643 stack. Its Identity Registry delegates `isVerified(wallet)` to Shibui through `setIdentityVerifier`, replacing the built-in verification path while configured.

That extension is proposed in [ERC-3643 PR #98](https://github.com/ERC-3643/ERC-3643/pull/98), which remains a draft and is not merged upstream. The dependency in `lib/ERC-3643` points to the EEA fork, not an upstream release containing this extension. Passing integration tests does not establish production deployment or complete ERC-3643 conformance: identity-dependent recovery and key-management flows require separate validation.

## ONCHAINID's separate EAS integration

[ERC-3643 issue #95](https://github.com/ERC-3643/ERC-3643/issues/95) closed on June 8 after the discussion moved to [ONCHAINID issue #10](https://github.com/T-REX-Network/ONCHAINID/issues/10), now also closed. ONCHAINID [PR #31](https://github.com/T-REX-Network/ONCHAINID/pull/31) merged an `EASClaimIssuer` on July 16, followed by implementation fixes.

This route retains the identity and claim model. The adapter reads EAS live to validate schema, per-topic trusted attesters, recipient binding, revocation, expiry and the mirrored claim data. It does not decode Shibui's ten-field Investor Eligibility schema or run Shibui's eight policy modules.

Wallet revocation intentionally does not revoke identity-level eligibility in this adapter, to avoid blocking recovery. Token-level restrictions and EAS claim revocation remain separate decisions. See the [ONCHAINID integration notes](https://github.com/T-REX-Network/ONCHAINID#eas-adapter-integration-notes). ONCHAINID v3 is not an in-place upgrade of v2 identities.

## Where to start

- [Shibui specification](schemas/shibui-specification-v0.1.md): payload semantics and policy interpretation.
- [Integration guide](integration-guide.md): experimental Path A and limited Path B prerequisites.
- [Enforcement boundary](architecture/enforcement-boundary.md): token controls and identity assumptions.
- [Integration tests](../test/integration/ERC3643Token.integration.t.sol) and [historical gas notes](integration-gas.md): evidence from the modified-registry path.

Merged ONCHAINID code is evidence of EAS support, not adoption of Shibui's complete policy model or proof of a production Shibui deployment.
