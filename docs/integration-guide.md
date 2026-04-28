# Shibui Integration Guide

> **Scope reminder.** Shibui is an **attestation retrieval adapter**, not a full identity layer. Token-side primitives (forced transfer, freeze, recovery) live in the ERC-3643 token contract. See [`architecture/enforcement-boundary.md`](architecture/enforcement-boundary.md).
>
> **Cross-chain.** EAS attestations are **per-chain**. An investor verified on chain A must be re-attested on chain B. Multi-chain attestation portability is on the V2 roadmap and is **not** a property of the current implementation.
>
> **Path B limitations.** `EASClaimVerifierIdentityWrapper` is a **read-compat shim** for legacy ERC-3643 deployments whose Identity Registry cannot be modified. It does not run topic policies in `isClaimValid`, returns empty signatures from `getClaim`, and has a higher gas profile than Path A. New deployments should use Path A. See the wrapper's NatSpec under `contracts/compat/` for the full list of limitations.


## What you'll achieve

By the end of this guide your ERC-3643 security token will verify investor eligibility from EAS attestations, with payload semantics enforced on-chain:

- **Token issuers** accept KYC/accreditation credentials from any EAS-compatible provider rather than being tied to a single identity ecosystem.
- **Investors** complete KYC once per chain with a trusted provider; no per-investor identity contract is deployed.
- **KYC providers** issue attestations on EAS; revoke or re-issue them without touching the token.
- **Compliance officers** revoke access in real-time by revoking the attestation on EAS; the next `isVerified` returns false and the token blocks further transfers.

### Example scenario

A fund manager launches a tokenised US Treasury product on Base using ERC-3643. Regulation requires investors to be KYC-verified and accredited. A sanctions screener also attests per-investor.

**Without Shibui:** each investor needs an ONCHAINID contract deployed on Base. Only ONCHAINID-compatible KYC providers can participate. Claim existence is checked on-chain, but the payload (did KYC actually complete? is the investor on a sanctions list?) is not.

**With Shibui:** the KYC provider and sanctions screener each attest the investor under the Investor Eligibility schema on EAS (on Base). The Identity Registry delegates `isVerified` to Shibui. When `token.transfer` calls `isVerified`, Shibui checks payload semantics on-chain: KYC verified, country in allow-list, sanctions clear. Deploying the same token on Arbitrum requires re-attesting on Arbitrum (per-chain).

## Prerequisites

Before integration, ensure you have:

1. **Deployed EAS infrastructure** on the target chain — EAS is live on [Ethereum, Base, Arbitrum, Optimism, and common testnets](https://docs.attest.org/docs/quick--start/contracts).
2. **Registered schemas** — Run [`script/RegisterSchemas.s.sol`](../script/RegisterSchemas.s.sol); schemas documented in [`schemas/schema-definitions.md`](schemas/schema-definitions.md).
3. **Deployed Shibui contracts** — see below.
4. **At least one trusted KYC / compliance provider** attesting under the Investor Eligibility schema.

## Integration Paths

### Path A: Pluggable Verifier (recommended)

> **"We're building a new token (or we can upgrade our Identity Registry) and want EAS attestations as our identity layer."**

Integrate `EASClaimVerifier` as the backend the ERC-3643 Identity Registry delegates to. The cleanest way is via the `IIdentityVerifier` extension point proposed upstream in [`ERC-3643/ERC-3643#98`](https://github.com/ERC-3643/ERC-3643/pull/98): the Identity Registry gains one admin call, `setIdentityVerifier(shibuiAddress)`, and after that every `isVerified` delegates to Shibui.

**When to use:**
- New ERC-3643 deployments.
- Existing deployments whose Identity Registry you can upgrade to the version carrying the extension point.

**Steps:**

1. Deploy the Shibui contracts (see [`script/DeployBridge.s.sol`](../script/DeployBridge.s.sol) or the testnet/mainnet scripts).
2. Register the two EAS schemas (`script/RegisterSchemas.s.sol`).
3. Wire the verifier: adapter, identity proxy, Claim Topics Registry, topic-schema mappings, topic-policy mappings.
4. Add trusted attesters — each with an EAS Schema-2 `authUID` (see Step 3 below).
5. Call `identityRegistry.setIdentityVerifier(address(verifier))` on the Identity Registry.

### Path B: Identity Wrapper (read-compat shim for existing deployments)

> **"We have an ERC-3643 token already in production. We cannot modify the Identity Registry, but we want to start accepting EAS attestations."**

Use `EASClaimVerifierIdentityWrapper` (under `contracts/compat/`) as an `IIdentity`-compatible wrapper — one wrapper per investor identity. The wrapper presents an ONCHAINID-shaped surface whose `isClaimValid` delegates to `EASClaimVerifier` for the attestation existence check.

**Path B limitations:**
- No ERC-734 keys. `addKey` / `removeKey` revert. Lost-key recovery uses the ERC-3643 token's `recoveryAddress` flow, not this wrapper.
- No claim signatures. `getClaim` returns an empty `signature` — the attestation is authenticated by EAS at read time, not by a signature stored on the wrapper.
- No topic policies inside `isClaimValid`. The wrapper only checks attestation existence + non-revocation + non-expiry; full payload-aware enforcement (Investor Eligibility policy modules) only runs through Path A.
- O(N × M) gas profile on `getClaim` — scales with trusted-attester count × registered attestations. Fine for low-topic, low-attester deployments; avoid for deep required-topic stacks.
- Targets EthTrust Security Level 1, not Level 2. New deployments should use Path A.

**When to use:** only when the Identity Registry cannot be modified *and* you accept the caveats above.

**Steps:**

1. Deploy a Shibui core stack (verifier + adapter + identity proxy + policies + resolver) as in Path A steps 1–3.
2. Deploy one `EASClaimVerifierIdentityWrapper` per investor identity (constructor binds the wrapper to an investor address).
3. Register the wrapper address in `IdentityRegistryStorage` in place of an ONCHAINID contract.
4. KYC provider attests the investor on EAS (Investor Eligibility). Call `verifier.registerAttestation(identity, topic, uid)` from an `AGENT_ROLE` holder or from the attester itself.
5. Token uses the existing verification flow — no token-side code change.

## Step-by-Step Integration (Path A)

All setter calls below require the caller to hold `OPERATOR_ROLE` on the target contract; wallet registrations require `AGENT_ROLE` on the identity proxy. Roles are managed by `DEFAULT_ADMIN_ROLE` (the issuer multisig) via OpenZeppelin `AccessControl`. The deploy scripts grant the deployer `OPERATOR_ROLE` for bring-up, then the issuer transfers `DEFAULT_ADMIN_ROLE` to the multisig and revokes the deployer's grant.

### 1. Deploy Shibui contracts

```solidity
// Deploy the core stack
EASTrustedIssuersAdapter adapter = new EASTrustedIssuersAdapter(admin);
EASIdentityProxy identityProxy = new EASIdentityProxy(admin);
EASClaimVerifier verifier = new EASClaimVerifier(admin);

// Configure verifier (caller must hold OPERATOR_ROLE)
verifier.setEASAddress(EAS_CONTRACT_ADDRESS);
verifier.setTrustedIssuersAdapter(address(adapter));
verifier.setIdentityProxy(address(identityProxy));      // required; reverts if address(0) after setting
verifier.setClaimTopicsRegistry(address(claimTopicsRegistry));

// Point the adapter at the Issuer Authorization schema (caller must hold DEFAULT_ADMIN_ROLE)
adapter.setIssuerAuthSchemaUID(ISSUER_AUTHORIZATION_SCHEMA_UID);
```

You can use [`script/DeployBridge.s.sol`](../script/DeployBridge.s.sol) (or the testnet / mainnet / UUPS variants) to do this end-to-end.

### 2. Deploy topic policies + configure topic→schema + topic→policy mappings

Shibui ships eight `ITopicPolicy` modules under `contracts/policies/` — one per production claim topic (KYC, AML, Country, Accreditation, Professional Investor, Institutional Investor, Sanctions, Source-of-Funds). Each policy decodes the Investor Eligibility payload and enforces one rule. The deploy scripts (`DeployBridge`, `DeployTestnet`, `DeployMainnet`, `DeployUpgradeable`) instantiate all eight and call `setTopicPolicy` for each topic; wire them manually like this if you are scripting your own deploy:

```solidity
// All eight policies decode the same Investor Eligibility schema.
verifier.setTopicSchemaMapping(1, INVESTOR_ELIGIBILITY_SCHEMA_UID); // KYC
verifier.setTopicSchemaMapping(7, INVESTOR_ELIGIBILITY_SCHEMA_UID); // Accreditation

// Bind the policy that enforces the payload semantics for each topic.
verifier.setTopicPolicy(1, address(kycStatusPolicy));
verifier.setTopicPolicy(7, address(accreditationPolicy));
```

`isVerified` reverts with `PolicyNotConfiguredForTopic(topic)` if a required topic has no policy bound — there is no implicit accept path.

### 3. Add trusted attesters (Schema-2 gated)

Every attester add / topic update must be authorised by a live Schema 2 (Issuer Authorization) attestation whose `recipient == attester` and whose `authorizedTopics` is a superset of the topics being bound. The `TrustedIssuerResolver` gates Schema-2 writes so only admin-curated "authorizers" can produce them.

```solidity
uint256[] memory topics = new uint256[](2);
topics[0] = 1; // KYC
topics[1] = 7; // Accreditation

// authUID points at a Schema 2 attestation issued by an authorized authorizer.
// Without it, addTrustedAttester reverts (IssuerAuthAttestationMissing /
// IssuerAuthRecipientMismatch / IssuerAuthTopicsNotAuthorized).
adapter.addTrustedAttester(KYC_PROVIDER_ADDRESS, topics, authUID);
```

Up to `MAX_ATTESTERS_PER_TOPIC = 5` attesters per topic are supported. Adding a provider never invalidates investors covered by a different provider — `isVerified` short-circuits on the first trusted attester whose attestation clears the structural and policy checks.

### 4. Configure required topics

```solidity
claimTopicsRegistry.addClaimTopic(1); // KYC required
claimTopicsRegistry.addClaimTopic(7); // Accreditation required
```

### 5. Bind investor wallets to identities (AGENT_ROLE)

```solidity
// Single wallet
identityProxy.registerWallet(investorWallet, identityAddress);

// Batch
address[] memory wallets = new address[](3);
wallets[0] = wallet1;
wallets[1] = wallet2;
wallets[2] = wallet3;
identityProxy.batchRegisterWallets(wallets, identityAddress);
```

Self-registration (an investor calling `registerWallet` for their own wallet) is not supported — the caller must hold `AGENT_ROLE`.

### 6. KYC provider creates the attestation (Investor Eligibility)

Ten fields, in this order:

```solidity
// Investor Eligibility — the canonical Shibui payload.
// Decoded identically by every topic policy; each policy enforces one rule.
bytes memory data = abi.encode(
    identityAddress,                 // address identity
    uint8(1),                        // kycStatus         — 1 = VERIFIED
    uint8(0),                        // amlStatus         — 0 = CLEAR
    uint8(0),                        // sanctionsStatus   — 0 = CLEAR
    uint8(1),                        // sourceOfFundsStatus — 1 = VERIFIED
    uint8(2),                        // accreditationType — e.g. US-accredited
    uint16(840),                     // countryCode       — ISO-3166-1 numeric (USA)
    uint64(block.timestamp + 365 days), // expirationTimestamp (data-level)
    evidenceHash,                    // bytes32 evidenceHash — off-chain KYC file commitment
    uint8(1)                         // verificationMethod  — provider-defined enum
);

AttestationRequest memory request = AttestationRequest({
    schema: INVESTOR_ELIGIBILITY_SCHEMA_UID,
    data: AttestationRequestData({
        recipient: identityAddress,
        expirationTime: 0,         // use data-level expirationTimestamp
        revocable: true,
        refUID: bytes32(0),
        data: data,
        value: 0
    })
});

bytes32 attestationUID = eas.attest(request);
```

See [`schemas/schema-definitions.md`](schemas/schema-definitions.md) for the canonical field list and semantics.

### 7. Register the attestation in the verifier

```solidity
// Caller must be the attester, or hold AGENT_ROLE on the verifier.
verifier.registerAttestation(identityAddress, 1, attestationUID); // Topic 1 (KYC)
```

### 8. Verify token transfer eligibility

Verification happens automatically via the Identity Registry when the token calls its compliance hook:

```solidity
// Inside the Identity Registry (with the upstream IIdentityVerifier extension point,
// ERC-3643/ERC-3643#98), isVerified delegates to Shibui:
function isVerified(address to) external view returns (bool) {
    if (_identityVerifier != address(0)) {
        return IIdentityVerifier(_identityVerifier).isVerified(to);
    }
    // default ONCHAINID path preserved when the extension point is unset
}
```

## Configuration Options

### Multiple KYC providers

You can have multiple attesters per topic (cap: 5):

```solidity
adapter.addTrustedAttester(PROVIDER_1, topics, authUID_1);
adapter.addTrustedAttester(PROVIDER_2, topics, authUID_2);
// isVerified short-circuits on the first trusted attester whose attestation passes.
```

### Schema per topic

Shibui v0.4 uses a single consolidated Investor Eligibility schema for all eight production topics. Per-topic schemas remain supported by the contract API (`setTopicSchemaMapping`) for integrators whose providers prefer to split payloads — but the shipped policy modules assume the Investor Eligibility schema and will need replacement policies if you diverge.

## Verification Flow

When `isVerified(address)` is called:

1. **Resolve Identity**: If `identityProxy` is set, resolve wallet to identity
2. **Get Required Topics**: Query `claimTopicsRegistry` for required topics
3. **For Each Topic**:
   - Get the mapped schema UID
   - Get trusted attesters for the topic
   - Check for valid registered attestation from any trusted attester
   - Validate: not revoked, not expired (EAS + data level)
4. **Return Result**: True only if all topics are satisfied

## Revocation — Real-Time Compliance Enforcement

> An investor fails an AML check. A sanctions list is updated. A KYC provider is compromised. In all these cases, you need to **immediately** block the investor from trading — not wait for a manual review cycle.

### By Attester: Revoke a Specific Investor

> **Scenario:** "Bob failed his annual AML re-check. His KYC attestation must be revoked immediately."

```solidity
eas.revoke(RevocationRequest({
    schema: schemaUID,
    data: RevocationRequestData({
        uid: attestationUID,
        value: 0
    })
}));
// Effect: Bob's attestation is instantly invalid.
// Next time anyone calls isVerified(bob), it returns false.
// Bob cannot buy, sell, or receive the token until re-verified.
```

### By Token Issuer: Remove Trust in a Provider

> **Scenario:** "We discovered KYC Provider X was issuing attestations without proper verification. We need to invalidate ALL their attestations."

```solidity
adapter.removeTrustedAttester(attesterAddress);
// Effect: EVERY attestation from this provider becomes invalid.
// All investors verified only by this provider are immediately blocked.
// Investors verified by other trusted providers are unaffected.
```

## Expiration Handling

Attestations expire in two ways:

1. **EAS-level expiration**: Set `expirationTime` in attestation request
2. **Data-level expiration**: Include `expirationTimestamp` in attestation data

The verifier checks both. Data-level expiration is recommended for flexibility.

## Error Handling

`EASClaimVerifier` reverts on misconfiguration; `isVerified` itself never reverts on attestation state and simply returns `false`.

| Error | Raised when |
|---|---|
| `EASNotConfigured` | `setEASAddress` never called |
| `TrustedIssuersAdapterNotConfigured` | `setTrustedIssuersAdapter` never called |
| `ClaimTopicsRegistryNotConfigured` | `setClaimTopicsRegistry` never called |
| `IdentityProxyNotConfigured` | `setIdentityProxy` never called, or set to `address(0)` |
| `SchemaNotMappedForTopic(topic)` | Required topic has no `setTopicSchemaMapping` entry |
| `PolicyNotConfiguredForTopic(topic)` | Required topic has no `setTopicPolicy` entry |
| `ZeroAddressNotAllowed` | Any setter passed `address(0)` where not allowed |

On the adapter:

| Error | Raised when |
|---|---|
| `IssuerAuthSchemaUIDNotSet` | `setIssuerAuthSchemaUID` never called before `addTrustedAttester` |
| `IssuerAuthAttestationMissing` | `authUID` unknown, wrong schema, revoked, or expired |
| `IssuerAuthRecipientMismatch` | Schema-2 attestation `issuerAddress != attester` |
| `IssuerAuthTopicsNotAuthorized` | Passed topics not a subset of Schema-2 `authorizedTopics` |

`isVerified()` returns `false` (rather than reverting) when any required topic's attestation is missing, revoked, expired, schema-mismatched, from an untrusted attester, or fails the topic policy.

## Events

Monitor these for integration and compliance trails:

```solidity
// EASClaimVerifier
event EASAddressSet(address indexed easAddress);
event TrustedIssuersAdapterSet(address indexed adapterAddress);
event IdentityProxySet(address indexed proxyAddress);
event ClaimTopicsRegistrySet(address indexed registryAddress);
event TopicSchemaMappingSet(uint256 indexed claimTopic, bytes32 indexed schemaUID);
event TopicPolicySet(uint256 indexed claimTopic, address indexed policy);
event AttestationRegistered(address indexed identity, uint256 indexed claimTopic, address indexed attester, bytes32 attestationUID);

// EASTrustedIssuersAdapter
event EASAddressSet(address indexed easAddress);
event IssuerAuthSchemaUIDSet(bytes32 indexed schemaUID);
event TrustedAttesterAdded(address indexed attester, uint256[] claimTopics);
event TrustedAttesterRemoved(address indexed attester);
event AttesterTopicsUpdated(address indexed attester, uint256[] claimTopics);

// EASIdentityProxy
event WalletRegistered(address indexed wallet, address indexed identity);
event WalletRemoved(address indexed wallet, address indexed identity);

// AccessControl (from OpenZeppelin) — emitted by all three contracts
event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
```

## Testing Your Integration

Unit and integration harnesses are under `test/`. For lightweight bring-up in your own repo, the mocks under `contracts/mocks/` cover EAS, a KYC attester, and a Claim Topics Registry:

```solidity
import {MockEAS} from "../contracts/mocks/MockEAS.sol";
import {MockAttester} from "../contracts/mocks/MockAttester.sol";
import {MockClaimTopicsRegistry} from "../contracts/mocks/MockClaimTopicsRegistry.sol";

MockEAS mockEAS = new MockEAS();
MockAttester kycProvider = new MockAttester(address(mockEAS), "Test KYC");

// Investor Eligibility attestation (10 fields).
bytes32 uid = kycProvider.attestInvestorEligibility(
    schemaUID,
    /* recipient */         identityAddress,
    /* identity */          identityAddress,
    /* kycStatus */         1,
    /* amlStatus */         0,
    /* sanctionsStatus */   0,
    /* sourceOfFundsStatus*/1,
    /* accreditationType */ 2,
    /* countryCode */       840,
    /* expiration */        uint64(block.timestamp + 365 days),
    /* evidenceHash */      bytes32(0),
    /* verificationMethod*/ 1
);
```

Check [`test/integration/ERC3643Token.integration.t.sol`](../test/integration/ERC3643Token.integration.t.sol) for the full end-to-end path against a real ERC-3643 / T-REX stack.

## Security considerations

1. **Role hygiene.** `DEFAULT_ADMIN_ROLE` must sit on the issuer multisig. The production deploy scripts grant it, then revoke the deployer's grant atomically. Monitor `RoleGranted` / `RoleRevoked` events.
2. **Policy discipline.** Binding the wrong `ITopicPolicy` to a topic causes mass false-accepts or false-rejects. Each policy contract exposes `topicId()` — verify that it matches before calling `setTopicPolicy`. `TopicPolicySet` is indexed and should be diff-watched in CI.
3. **Authorizer curation.** The `TrustedIssuerResolver` gates Schema-2 writes to admin-curated authorizers. Changes to the authorizer set emit `AuthorizerAdded` / `AuthorizerRemoved` — surface these to compliance.
4. **Attester lifecycle.** Rotate `authUID`s when attester topics change. Removing trust in a provider (`removeTrustedAttester`) instantly invalidates every investor verified only by that provider, but does not invalidate investors covered by a second trusted attester.
5. **Expiration.** Prefer the data-level `expirationTimestamp` (on-chain enforcement by policies + verifier). The EAS `expirationTime` field is honoured as a secondary check.
6. **Audit trail.** The Investor Eligibility schema carries `evidenceHash` + `verificationMethod`; persist the off-chain KYC file hashes so examiners can trace an on-chain decision back to the file the provider holds.

## Upgradeability

Shibui ships both non-upgradeable and UUPS variants:

- `contracts/` — immutable deployments, lowest surface. Recommended where contract rotation is acceptable.
- `contracts/upgradeable/` — `EASClaimVerifierUpgradeable`, `EASTrustedIssuersAdapterUpgradeable`, `EASIdentityProxyUpgradeable`. All `UUPSUpgradeable`, gated by `DEFAULT_ADMIN_ROLE`. Storage layouts are audited; see [`test/unit/UpgradeableContracts.t.sol`](../test/unit/UpgradeableContracts.t.sol) for the `__gap` invariant check.

Pick one per deployment — do not mix upgradeable and non-upgradeable variants behind the same Identity Registry.

## Support

- Architecture + scope boundary: [`architecture/enforcement-boundary.md`](architecture/enforcement-boundary.md)
- Schema details: [`schemas/schema-definitions.md`](schemas/schema-definitions.md)
- Gas numbers: [`integration-gas.md`](integration-gas.md)
- Issues: https://github.com/EntEthAlliance/rnd-rwa-erc3643-eas/issues
