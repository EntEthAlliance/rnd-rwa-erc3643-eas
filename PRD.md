# EAS-to-ERC-3643 Identity Bridge — Product Requirements Document

## Project Summary

Build an **Identity Verifier module** (in OpenZeppelin’s vocabulary) for ERC-3643 security tokens that accepts **Ethereum Attestation Service (EAS)** attestations as an alternative identity backend to **ONCHAINID**.

Architecturally, this is a clean separation of concerns:
- **Token + Compliance stay standard ERC-3643 / T-REX** (no reinvention of compliance logic).
- **Identity verification becomes a pluggable module**: issuers can choose **ONCHAINID, EAS, or both** at deployment time.

The key product goal is interoperability and reduced lock-in:
- A single EAS-based Identity Verifier can be **reused across many ERC-3643 deployments** (or deployed once per issuer), instead of bundling identity logic into each token.
- EAS becomes the “identity proof format” layer, enabling issuers and KYC/AML providers to integrate without relying on Tokeny-specific tooling.

This ships as an open-source reference implementation on GitHub under the EEA organization.

### Architecture Evolution Note (Updated)

The current verifier implementation is production-oriented but monolithic. The target productization path is now:

- **Valence (kernel-orchestrated Diamond architecture)** as the preferred evolution model
- with EIP-2535 compatibility through Valence’s kernel/module lifecycle pattern
- while preserving ERC-3643 integration semantics and dual-mode identity support

A migration spike has been added in-repo (`contracts/valence/*`) and tracked as a phased implementation stream.

---

## Demo + Validation (How to prove this works)

This project is designed to be verifiable at three levels:

### A) Local validation (developer machine)

**Prereqs:** Foundry (`forge`, `cast`), an RPC URL, and a funded deployer key for the target network.

**Run (keep it short):**
- `forge test`
- `forge test --match-path test/integration/*`
- `forge test --gas-report`
- (optional) `forge coverage`

### B) Testnet pilot (Sepolia) — end-to-end

Run scripts in order:
- `script/DeployTestnet.s.sol`
- `script/RegisterSchemas.s.sol`
- `script/SetupPilot.s.sol`

**Expected outcome:** transfers to verified identities succeed; transfers to unverified identities revert at identity verification.

### C) Demo UI

A separate demo front-end lives here:
- https://github.com/claudyfaucant/eas-erc3643-bridge-demo

It connects to deployed contracts (addresses + chain config) and demonstrates schema registration + attestation-driven eligibility checks for ERC-3643 flows.

---

## Valence Migration Track (Preferred Productization Path)

To align upgradeability and modularity goals, this PRD now treats **Valence** as the primary architecture evolution path over a hand-rolled Diamond implementation.

Target mapping:
- Current `EASClaimVerifier` logic → `VerificationOrbital`
- Current attestation registration + topic/schema functions → `RegistryOrbital`
- Current config/control surface → `ValenceEASKernelAdapter` + kernel-managed module lifecycle
- Future trusted-attester and identity-mapping functionality → dedicated orbitals

Delivery policy:
1. Keep current path operational (no breaking cutover)
2. Build Valence modules in parallel
3. Prove parity via tests + pilot scripts
4. Only then execute production migration

Reference docs:
- `docs/architecture/eip2535-migration-design.md`
- `docs/architecture/valence-migration-spike-checklist.md`

## Repository Structure

Fork the ERC-3643 T-REX contracts from https://github.com/TokenySolutions/T-REX as a dependency. Fork or reference the EAS contracts from https://github.com/ethereum-attestation-service/eas-contracts as a dependency.

Create a new repository: `eas-erc3643-bridge`

```
eas-erc3643-bridge/
├── contracts/
│   ├── EASClaimVerifier.sol
│   ├── EASTrustedIssuersAdapter.sol
│   ├── EASIdentityProxy.sol
│   ├── interfaces/
│   │   ├── IEASClaimVerifier.sol
│   │   ├── IEASTrustedIssuersAdapter.sol
│   │   └── IEASIdentityProxy.sol
│   └── mocks/
│       ├── MockEAS.sol
│       └── MockAttester.sol
├── docs/
│   ├── research/
│   │   ├── minimal-identity-structure.md
│   │   ├── claim-topic-analysis.md
│   │   └── gap-analysis.md
│   ├── architecture/
│   │   ├── system-architecture.md
│   │   ├── contract-interaction-diagrams.md
│   │   └── data-flow.md
│   ├── schemas/
│   │   ├── schema-definitions.md
│   │   └── schema-governance.md
│   ├── integration-guide.md
│   └── gas-benchmarks.md
├── diagrams/
│   ├── architecture-overview.mmd
│   ├── transfer-verification-flow.mmd
│   ├── attestation-lifecycle.mmd
│   ├── dual-mode-verification.mmd
│   └── wallet-identity-mapping.mmd
├── test/
│   ├── unit/
│   │   ├── EASClaimVerifier.t.sol
│   │   ├── EASTrustedIssuersAdapter.t.sol
│   │   └── EASIdentityProxy.t.sol
│   ├── integration/
│   │   ├── FullTransferLifecycle.t.sol
│   │   ├── DualModeVerification.t.sol
│   │   ├── AttestationRevocation.t.sol
│   │   └── GasBenchmark.t.sol
│   └── scenarios/
│       ├── UseCase_STO.t.sol
│       ├── UseCase_PrivateFund.t.sol
│       └── UseCase_CrossBorderTransfer.t.sol
├── script/
│   ├── DeployTestnet.s.sol
│   ├── DeployMainnet.s.sol
│   ├── RegisterSchemas.s.sol
│   └── SetupPilot.s.sol
├── foundry.toml
└── README.md
```

---

## Phase 1: Research

### Deliverable 1.1 — Minimal Identity Structure Analysis

File: `docs/research/minimal-identity-structure.md`

Content requirements:

Trace the isVerified() call in the ERC-3643 Identity Registry contract line by line. Document every external call it makes, every storage read, every condition that must pass for a transfer to succeed. The output is a precise specification of what the identity layer must provide.

The call path is: Identity Registry receives wallet address → fetches ONCHAINID address from Identity Registry Storage → fetches required claim topics from Claim Topics Registry → fetches trusted issuers from Trusted Issuers Registry → for each required topic, checks if the ONCHAINID holds a claim on that topic signed by a trusted issuer → validates cryptographic signature on the claim → returns bool.

For each step, define what the EAS equivalent is:
- ONCHAINID address lookup → EAS attestation recipient address (or identity proxy mapping)
- Claim topic → EAS schema UID
- Trusted issuer → EAS attester address
- Claim signature validation → EAS native attestation verification (handled by EAS.sol)
- Claim revocation check → EAS native revocation check

### Deliverable 1.2 — Production Claim Topic Analysis

File: `docs/research/claim-topic-analysis.md`

Content requirements:

Query deployed Claim Topics Registries on Ethereum mainnet and Polygon. For each ERC-3643 token deployment found, record which claim topics are registered. Build a frequency table showing which topics are actually used in production.

Expected common topics: KYC validation, AML status, accredited investor status, country of residence, qualified purchaser status.

For each topic found, document: the uint256 topic ID, what compliance requirement it maps to, what jurisdictions require it, and what data the claim typically carries in its data field.

### Deliverable 1.3 — Gap Analysis

File: `docs/research/gap-analysis.md`

Content requirements:

Compare ONCHAINID capabilities vs EAS capabilities across these dimensions:

Key management: ONCHAINID inherits ERC-734 key management (management keys, execution keys, claim signer keys). EAS has no key management. Document whether the bridge needs key management or whether it is orthogonal to the compliance verification function. Conclusion expected: key management is about wallet control, not compliance verification. The bridge does not need it.

Multi-wallet identity: ONCHAINID links multiple wallets to one identity contract via the Identity Registry Storage. EAS attestations are made to a single address. Document how the EASIdentityProxy solves this.

Cross-chain portability: ONCHAINID uses CREATE2 via IdFactory for deterministic addresses across chains, so claims signed on one chain work on another. EAS attestations are chain-specific. Document whether this is a V1 requirement or deferred. Expected conclusion: defer to V2, require separate attestations per chain for V1.

Offchain attestations: EAS supports offchain attestations natively. ONCHAINID claims are onchain. Document the privacy and cost tradeoffs. Flag that offchain attestations need a mechanism to be verified onchain at transfer time — likely via an onchain proof or a trusted relayer.

For each gap, categorize as: solved by the bridge contracts, deferred to V2, or out of scope with justification.

---

## Phase 2: Schema Design

### Deliverable 2.1 — EAS Schema Definitions

File: `docs/schemas/schema-definitions.md`

Define each schema with: name, schema string (Solidity ABI types), resolver contract address (if any), revocability setting, and usage description.

Required schemas:

Schema 1 — Investor Eligibility
```
address identity, uint8 kycStatus, uint8 accreditationType, uint16 countryCode, uint64 expirationTimestamp
```
- kycStatus: 0 = not verified, 1 = verified, 2 = expired, 3 = revoked
- accreditationType: 0 = none, 1 = retail qualified, 2 = accredited, 3 = qualified purchaser, 4 = institutional
- countryCode: ISO 3166-1 numeric (same format ERC-3643 Identity Registry uses)
- expirationTimestamp: unix timestamp after which the attestation is invalid
- Revocable: yes
- Resolver: EASTrustedIssuersAdapter (validates attester is authorized for this schema)

Schema 2 — Issuer Authorization
```
address issuerAddress, uint256[] authorizedTopics, string issuerName
```
- Used to attest that a given address is authorized to issue claims on specific topics
- Made by the token issuer or their agent
- Revocable: yes
- Resolver: none (administered by token issuer directly)

Schema 3 — Wallet-Identity Link
```
address walletAddress, address identityAddress, uint64 linkedTimestamp
```
- Attests that a wallet belongs to a specific identity
- Made by the identity owner or an authorized agent
- Revocable: yes
- Resolver: validates that attester is the identityAddress or holds a management key

These schemas are the minimum viable set. Additional schemas (transfer restrictions, lock-up periods, investor caps) can be added later without changing the core contracts.

Register all schemas on Sepolia first using the RegisterSchemas.s.sol deployment script. Record the schema UIDs in a constants file used by the contracts.

### Deliverable 2.2 — Schema Governance Process

File: `docs/schemas/schema-governance.md`

Document the process for proposing, reviewing, and approving new schemas or changes to existing schemas. This is the EEA working group's domain. The document should specify: who can propose a schema change, what review process applies, how schema UIDs are managed across deployments, and how backward compatibility is maintained when schemas evolve.

---

## Phase 3: Contract Development

All contracts in Solidity 0.8.x. Use Foundry for build, test, deploy. Target 100% branch coverage on unit tests.

### Contract 1 — EASClaimVerifier.sol

Purpose: The core adapter. Implements verification logic that the Identity Registry calls to check if a wallet holder has valid EAS attestations matching required claim topics.

Interface:
```solidity
interface IEASClaimVerifier {
    // Returns true if the address has valid EAS attestations for all required claim topics
    function isVerified(address _userAddress) external view returns (bool);

    // Maps an ERC-3643 claim topic (uint256) to an EAS schema UID (bytes32)
    function setTopicSchemaMapping(uint256 claimTopic, bytes32 schemaUID) external;

    // Returns the EAS schema UID for a given claim topic
    function getSchemaUID(uint256 claimTopic) external view returns (bytes32);

    // Sets the EAS contract address
    function setEASAddress(address easAddress) external;

    // Sets the trusted issuers adapter address
    function setTrustedIssuersAdapter(address adapterAddress) external;

    // Sets the identity proxy address for wallet-to-identity resolution
    function setIdentityProxy(address proxyAddress) external;
}
```

Internal logic for isVerified():
1. Resolve wallet address to identity address via EASIdentityProxy. If no mapping exists, use wallet address directly.
2. Fetch required claim topics from the linked Claim Topics Registry (same registry the standard ERC-3643 setup uses).
3. For each required topic, get the mapped EAS schema UID.
4. Query EAS for attestations on that schema where recipient = identity address.
5. For each attestation found: check not revoked, check not expired (both EAS-level expiration and the expirationTimestamp in the attestation data), check that the attester is authorized for this topic via the EASTrustedIssuersAdapter.
6. If all topics have at least one valid attestation from a trusted attester, return true.

Access control: onlyOwner for configuration functions. Verification function is public view.

Critical design constraint: This contract must be callable from the existing Identity Registry. Two integration paths to implement and document:

Path A (recommended): Deploy EASClaimVerifier as a module called by a modified Identity Registry that supports pluggable verifiers. The Identity Registry checks ONCHAINID first, then falls back to EAS, or checks EAS only — configurable per deployment.

Path B (zero-modification): Wrap the EASClaimVerifier behind a contract that implements the IIdentity interface (ERC-735) so the Identity Registry sees it as a standard ONCHAINID. The wrapper translates EAS attestations into the claim structure the Identity Registry expects. More complex, but requires zero changes to existing ERC-3643 contracts.

Implement both paths. Document tradeoffs in architecture docs.

### Contract 2 — EASTrustedIssuersAdapter.sol

Purpose: Manages which EAS attester addresses are trusted for which claim topics. Mirrors the Trusted Issuers Registry pattern.

Interface:
```solidity
interface IEASTrustedIssuersAdapter {
    // Add a trusted attester for specific claim topics
    function addTrustedAttester(address attester, uint256[] calldata claimTopics) external;

    // Remove a trusted attester
    function removeTrustedAttester(address attester) external;

    // Update the topics a trusted attester is authorized for
    function updateAttesterTopics(address attester, uint256[] calldata claimTopics) external;

    // Check if an attester is trusted for a specific topic
    function isAttesterTrusted(address attester, uint256 claimTopic) external view returns (bool);

    // Get all trusted attesters for a specific topic
    function getTrustedAttestersForTopic(uint256 claimTopic) external view returns (address[] memory);

    // Get all topics an attester is trusted for
    function getAttesterTopics(address attester) external view returns (uint256[] memory);
}
```

Access control: onlyOwner or onlyAgent (matching ERC-3643's agent role pattern) for add/remove/update. Query functions are public view.

Optional: Can be implemented as a resolver contract attached to the EAS schemas directly. If implemented as a resolver, it validates at attestation creation time that the attester is authorized — rejecting unauthorized attestations before they exist. Document both approaches (external check vs resolver enforcement) with tradeoffs.

### Contract 3 — EASIdentityProxy.sol

Purpose: Maps wallet addresses to identity addresses so multiple wallets can share one identity's attestations.

Interface:
```solidity
interface IEASIdentityProxy {
    // Register a wallet under an identity address
    function registerWallet(address wallet, address identity) external;

    // Remove a wallet mapping
    function removeWallet(address wallet) external;

    // Get the identity address for a wallet (returns wallet itself if no mapping)
    function getIdentity(address wallet) external view returns (address);

    // Get all wallets registered under an identity
    function getWallets(address identity) external view returns (address[] memory);

    // Check if a wallet is registered
    function isRegistered(address wallet) external view returns (bool);
}
```

Access control: Wallet registration by token agent (onlyAgent) or by the identity address itself. Removal by agent or identity address.

V2 consideration (document but do not implement): Use EAS attestations (Schema 3 — Wallet-Identity Link) for the mapping itself, making wallet registration permissionless and attestation-based rather than agent-managed.

---

## Phase 4: Architecture Documentation

### Deliverable 4.1 — System Architecture

File: `docs/architecture/system-architecture.md`

Document the full system showing how the bridge contracts sit between the ERC-3643 token suite and EAS. Include:

- Component inventory: every contract, its role, its dependencies
- Trust boundaries: who controls what, who can modify what
- Upgrade paths: how contracts can be upgraded without breaking existing tokens

### Deliverable 4.2 — Contract Interaction Diagrams

File: `docs/architecture/contract-interaction-diagrams.md`
Diagram source files in `diagrams/` as Mermaid (.mmd) files.

Required diagrams:

Diagram 1 — Architecture Overview
Show all contracts and their relationships: Token → Identity Registry → EASClaimVerifier → EAS.sol, with EASTrustedIssuersAdapter and EASIdentityProxy as supporting modules. Show the parallel ONCHAINID path for dual-mode context.

Diagram 2 — Transfer Verification Flow (EAS path)
Sequence diagram: User initiates transfer → Token calls canTransfer → Identity Registry calls isVerified → EASClaimVerifier resolves identity → queries EAS for attestations → checks trusted issuers → returns result → transfer approved or rejected.

Diagram 3 — Transfer Verification Flow (Dual mode)
Same as above but showing the Identity Registry checking both ONCHAINID and EAS paths, with configurable priority/fallback.

Diagram 4 — Attestation Lifecycle
Flow from: KYC provider verifies investor offchain → KYC provider creates EAS attestation → attestation is live → investor can hold/transfer tokens → KYC expires → attestation expires or is revoked → investor can no longer transfer → re-verification → new attestation → investor is eligible again.

Diagram 5 — Wallet-Identity Mapping
Show how multiple wallets map to one identity address, how the EASClaimVerifier resolves the mapping, and how attestations made to the identity address are recognized for any linked wallet.

### Deliverable 4.3 — Data Flow Documentation

File: `docs/architecture/data-flow.md`

For each operation (register identity, issue attestation, verify transfer, revoke attestation, link wallet), document: which contracts are called, in what order, what data is passed, what storage is read/written, what events are emitted.

---

## Phase 5: Test Suite

### Unit Tests

File: `test/unit/EASClaimVerifier.t.sol`

Test cases:
- Valid attestation for all required topics → isVerified returns true
- Missing attestation for one required topic → returns false
- Attestation exists but is revoked → returns false
- Attestation exists but is expired (EAS-level expiration) → returns false
- Attestation exists but expirationTimestamp in data has passed → returns false
- Attestation exists but attester is not trusted for that topic → returns false
- Attester is trusted for topic A but attestation is for topic B → returns false
- Multiple attestations for same topic, one valid one revoked → returns true (valid one counts)
- No claim topics required (empty Claim Topics Registry) → returns true
- Wallet has no identity mapping, attestation is on wallet address directly → works
- Wallet has identity mapping, attestation is on identity address → works
- Wallet has identity mapping, attestation is on wallet address (not identity) → returns false
- Topic-to-schema mapping not set → reverts with descriptive error
- EAS contract address not set → reverts
- Zero address inputs → reverts

File: `test/unit/EASTrustedIssuersAdapter.t.sol`

Test cases:
- Add trusted attester → isAttesterTrusted returns true
- Remove trusted attester → isAttesterTrusted returns false
- Update attester topics → old topics return false, new topics return true
- Non-owner cannot add/remove/update → reverts
- Add same attester twice → idempotent, no revert
- Remove non-existent attester → reverts or no-op (document decision)
- Attester trusted for multiple topics → all return true
- Get all attesters for a topic → returns correct list
- Get all topics for an attester → returns correct list

File: `test/unit/EASIdentityProxy.t.sol`

Test cases:
- Register wallet → getIdentity returns identity address
- Unregistered wallet → getIdentity returns wallet itself
- Remove wallet → getIdentity returns wallet itself
- Register multiple wallets under same identity → all resolve correctly
- Re-register wallet under different identity → updates mapping
- Non-authorized caller cannot register → reverts
- Get all wallets for identity → returns correct list

### Integration Tests

File: `test/integration/FullTransferLifecycle.t.sol`

Deploy full ERC-3643 suite (token, identity registry, compliance, claim topics registry) plus bridge contracts plus mock EAS. Walk through:
1. Deploy token with EAS bridge configured
2. Register investor identity in EASIdentityProxy
3. Register KYC provider as trusted attester
4. KYC provider creates EAS attestation for investor
5. Mint tokens to issuer
6. Transfer tokens from issuer to investor → succeeds
7. Transfer tokens from investor to non-attested wallet → fails
8. Revoke investor attestation → transfer from investor fails
9. Re-attest investor → transfer succeeds again

File: `test/integration/DualModeVerification.t.sol`

Deploy the same token with both ONCHAINID and EAS configured. Test:
1. Investor A has ONCHAINID claims only → transfer succeeds
2. Investor B has EAS attestations only → transfer succeeds
3. Investor C has both → transfer succeeds
4. Investor D has neither → transfer fails
5. Revoke ONCHAINID for investor A, add EAS attestation → still succeeds
6. Revoke EAS for investor B, add ONCHAINID claim → still succeeds

File: `test/integration/AttestationRevocation.t.sol`

Test all revocation scenarios:
1. Attester revokes attestation → immediate effect on transfer eligibility
2. Attestation expires by timestamp → effect on transfer eligibility
3. Trusted attester is removed from adapter → all their attestations become invalid for compliance
4. Attester is re-added → attestations become valid again

File: `test/integration/GasBenchmark.t.sol`

Measure and record gas costs for:
- isVerified() via ONCHAINID path (baseline)
- isVerified() via EAS path (1 required topic)
- isVerified() via EAS path (3 required topics)
- isVerified() via EAS path (5 required topics)
- isVerified() via dual mode (both paths checked)
- Creating an EAS attestation (investor onboarding cost)
- Revoking an EAS attestation
- Registering a wallet in EASIdentityProxy
- Adding a trusted attester

Output results to `docs/gas-benchmarks.md` with a comparison table.

### Scenario Tests (Use Cases)

File: `test/scenarios/UseCase_STO.t.sol`

Security Token Offering scenario:
- Issuer creates token with max 500 holders
- KYC provider attests 10 test investors via EAS
- Investors are in 3 different countries
- Compliance module restricts country distribution
- Test that transfers respect both EAS identity verification AND compliance module restrictions
- Test that compliance and identity are independently enforced

File: `test/scenarios/UseCase_PrivateFund.t.sol`

Private fund scenario:
- Token requires accreditationType >= 2 (accredited investor)
- Attest some investors as retail (type 1), some as accredited (type 2), some as institutional (type 4)
- Retail investors cannot receive tokens
- Accredited and institutional can
- Test upgrade path: retail investor becomes accredited (new attestation), can now receive

File: `test/scenarios/UseCase_CrossBorderTransfer.t.sol`

Cross-border transfer scenario:
- Token is compliant in US and EU jurisdictions
- US investors need accredited investor attestation
- EU investors need MiFID II compliant attestation
- Different trusted attesters for each jurisdiction
- Test that the correct attester is required based on investor country code

---

## Phase 6: Integration Guide

File: `docs/integration-guide.md`

Step-by-step guide for a developer who has an existing ERC-3643 deployment and wants to add EAS support. Cover:

1. Prerequisites: what contracts are already deployed, what EAS deployment to point to
2. Deploy bridge contracts: EASClaimVerifier, EASTrustedIssuersAdapter, EASIdentityProxy
3. Configure topic-to-schema mappings
4. Register trusted attesters
5. Connect to Identity Registry (both Path A and Path B)
6. Register first investor identity
7. Issue first attestation via EAS SDK
8. Verify transfer works
9. Troubleshooting common issues

Include code snippets for every step. Include EAS SDK (TypeScript) examples for creating attestations programmatically — this is what KYC providers would integrate.

---

## Phase 7: Deployment Scripts

File: `script/DeployTestnet.s.sol`

Deploys all bridge contracts to Sepolia. Points to the existing EAS deployment on Sepolia. Registers schemas. Sets up a test token with the bridge configured. Seeds with test data (mock investors, attestations).

File: `script/DeployMainnet.s.sol`

Same as testnet but with production parameters. Requires multisig ownership. No test data.

File: `script/RegisterSchemas.s.sol`

Registers all EAS schemas defined in Phase 2. Records schema UIDs. Idempotent — skips if schema already exists.

File: `script/SetupPilot.s.sol`

Sets up a complete pilot environment: deploys token, bridge, registers a test KYC provider, attests 5 test investors, demonstrates a successful transfer. Used for demos and validation.

---

## Non-Functional Requirements

Gas efficiency: EAS verification path must not exceed 2x the gas cost of the ONCHAINID path. If it does, document optimization opportunities.

Backward compatibility: No changes to the ERC-3643 token contract (Token.sol). No changes to the compliance module interface. The Identity Registry may need a minor modification for Path A (pluggable verifiers) — document this change precisely and minimize its footprint.

Upgradability: Bridge contracts should be upgradeable via proxy pattern (UUPS or transparent proxy). Token issuers must be able to upgrade the bridge without redeploying the token.

Access control: Follow ERC-3643's existing owner/agent role pattern. Bridge contract administration uses the same roles.

Events: Every state change in bridge contracts must emit an event. Events must be sufficient to reconstruct the full state of the bridge from event logs alone.

Documentation: Every public and external function must have NatSpec comments. Every contract must have a top-level NatSpec description explaining its role in the system.

---

## Definition of Done

### Functional completion
- All contracts compile with zero warnings
- All unit, integration, and scenario tests pass
- Gas benchmarks documented
- All Mermaid diagrams render correctly
- All NatSpec comments complete

### Verifiable evidence (reviewer checklist)
- CI must be green on PRs (Build/Lint/Test/Coverage/Gas Report)
- Docs must include exact commands to reproduce CI locally (see **Demo + Validation**)
- Testnet pilot must be reproducible via the documented script sequence on Sepolia
- Demo UI must be reproducible via a minimal config (contract addresses + chain)

### Usability / handoff
- Integration guide validated by someone who did not write it
- README.md explains the project, links to all documentation, and includes quickstart + validation steps

### Security
- External audit completed with all critical/high findings resolved
