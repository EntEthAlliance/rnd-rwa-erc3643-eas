# vlei-to-eas × Shibui Integration

## What is vlei-to-eas?

`vlei-to-eas` (repo: `AlexeyKrasnoperov/vlei-to-eas`) is a Next.js bridge application
that translates GLEIF vLEI credentials into EAS attestations on-chain.

**Input:** vLEI credentials: GLEIF organizational identity credentials based on the
KERI (Key Event Receipt Infrastructure) protocol. Three credential types are relevant:

| Type | Name | Meaning |
|------|------|---------|
| `LE` | Legal Entity | The entity holds a valid, GLEIF-registered LEI |
| `ECR` | Engagement Context Role | A person is authorized to act in a specific context |
| `OOR` | Official Organizational Role | A person holds an official role (officer, director) |

**Output:** EAS attestations under the bridge's own schema (separate from both Shibui
schemas: `InvestorEligibility`, Schema-1, and `IssuerAuthorization`, Schema-2). It is
registered on Sepolia as UID `0x0b5f333cdb7e06e0d9f7c5fbd7a151bb0d8afbcde17017390ef73b673f841aa7`
with an `AttesterResolver` (`0xbCD6D24861d467703fbF3221f526c28A1adF9D4F`) that admits a
single bridge wallet (`0x8EF2312aB6A316a0CA9Ad90661B6bccE8A7eCdc6`); see
`contracts/deployments/sepolia.json` in the bridge repo.

**Background monitors** re-check vLEI validity every 4 h and the GLEIF LEI record every 12 h.
Liveness is expressed through native EAS fields, not by re-attesting: every attestation is
revocable and carries an `expirationTime` equal to the LEI's next renewal date. A revoked
credential or a terminal LEI status triggers an on-chain revocation; a lapsed LEI simply lets
the attestation expire; a renewed LEI yields a fresh attestation with the extended expiry.
`verifiedAt` is written once, at issuance, and is not refreshed afterwards, so consumers
should read `expirationTime` / `revocationTime` for liveness rather than `verifiedAt`.

**What this relies on.** With the staleness bound disabled (see the deployment snippet), an
attestation is accepted until it expires or is revoked. A revocation is a transaction the
bridge has to get mined: if its RPC endpoint is down or the attester wallet is out of gas,
the bridge retries, but until the transaction lands the attestation still passes
`VLEIPolicy`, and its expiry can be months away. Operators should monitor the bridge for
overdue revocations. A deployment that needs a hard upper bound on that delay can deploy
`VLEIPolicy` with a non-zero `maxStaleness_`; because the bridge never refreshes
`verifiedAt`, that bound then acts as a fixed lifetime after which the holder must obtain
and register a new attestation.

---

## Trust Chain

```
GLEIF Root of Trust (GLEIF vLEI Root AID)
  └── Qualified vLEI Issuer (QVI) — GLEIF-authorized credential issuer
        └── Legal Entity vLEI (LE credential, SAID verified by vlei-to-eas)
              └── ECR / OOR vLEI (role credential, chained to LE)
                    └── EAS attestation (minted by bridge wallet, bridge schema)
                          └── VLEIPolicy.validate() → Shibui ERC-3643 enforcement
```

At each step:
1. **GLEIF root → QVI:** GLEIF manages the root AID; QVIs are accredited out-of-band.
2. **QVI → LE credential:** The LE credential's SAID is registered in the GLEIF API.
3. **LE/ECR/OOR → EAS attestation:** `vlei-to-eas` verifies the KERI key-event log via
   a `vlei-verifier` sidecar and confirms the LEI record in the GLEIF API, then writes an
   EAS attestation. An attestation exists only after both checks pass; `vleiSaid` always
   carries the credential's SAID.
4. **EAS attestation → Shibui:** `VLEIPolicy.validate()` checks `credType` and the optional staleness bound,
   then returns `true`, allowing the ERC-3643 token transfer to proceed.

**Integration boundary:** `vlei-to-eas` owns all KERI/GLEIF verification logic.
Shibui only reads the resulting EAS attestation; it has no KERI dependency.

---

## New Topics

Two ERC-3643 claim topics are introduced for vLEI credentials:

| Topic ID | Name | Accepted credType | Purpose |
|----------|------|-------------------|---------|
| 15 | `VLEI_LEGAL_ENTITY` | `"LE"` | Proves the wallet/entity holds a valid GLEIF LEI |
| 16 | `VLEI_AUTHORIZED_ROLE` | `"ECR"` or `"OOR"` (one of them) | Proves a person has an authorized organizational role |

Each topic gets its own `VLEIPolicy` instance deployed with the matching `expectedCredType_`.

`EASClaimVerifier` holds exactly one policy per topic, and a `VLEIPolicy` accepts exactly
one `credType`. Topic 16 therefore accepts ECR or OOR, whichever its policy was deployed
with, not both. Accepting both on one topic needs a policy that matches either value, which
does not exist yet.

### Making the topics required

Deploying a policy, mapping the schema and trusting the attester does not make a topic
mandatory. `isVerified(user)` checks only the topics listed in `ClaimTopicsRegistry`; if 15
and 16 are not in it, they are never evaluated and an investor passes without a vLEI
attestation. Use one of:

- `ClaimTopicsRegistry.addClaimTopic(15)` (and `16`), so every `isVerified` call requires
  them. `ConfigureBridge.s.sol` does this for the topics in `REQUIRED_TOPICS`.
- `isVerifiedForTopics(user, topics)`, where the token passes the topics it requires. This
  lets different tokens on one verifier require different claim sets.

---

## vLEI Schema (bridge schema)

ABI-encoded fields (in order):

```
string  lei             — GLEIF 20-character LEI code
string  legalName       — Legal entity name from GLEIF registry
string  credType        — "LE" | "ECR" | "OOR"
string  keriAid         — KERI AID of the credential holder
bytes32 vleiSaid        — SAID of the vLEI credential (32-byte digest of the CESR SAID)
uint64  verifiedAt      — Unix timestamp of the verification at issuance (not refreshed)
```

The schema is already registered on Sepolia by the bridge (UID above). Do not register a
second copy: `EASClaimVerifier.setTopicSchemaMapping` must map topics 15 and 16 to the
live UID, which goes into `deployments/sepolia.json` under `shibui.vlei.bridgeSchemaUID`.
`VLEIPolicy` itself never sees a schema UID; only the verifier is bound to the schema.

---

## Adding the Bridge Wallet as a Trusted Attester

The bridge wallet is enforced as the sole authorized attester by `AttesterResolver.sol`
in the vlei-to-eas repo. On the Shibui side, the bridge wallet must also be trusted
via the `IssuerAuthorization` schema (Schema-2 in the existing Shibui deployment).

```bash
# 1. An authorizer attests an IssuerAuthorization (Schema-2) record naming the
#    bridge wallet as attester for topics 15 and 16 (same flow as for any other
#    attester; see docs/schemas/schema-definitions.md). Keep its UID as AUTH_UID.
BRIDGE_WALLET=0x8EF2312aB6A316a0CA9Ad90661B6bccE8A7eCdc6   # vlei-to-eas attester

# 2. Register the bridge wallet as a trusted attester for both topics in one call.
cast send $EAS_TRUSTED_ISSUERS_ADAPTER \
  "addTrustedAttester(address,uint256[],bytes32)" \
  $BRIDGE_WALLET "[15,16]" $AUTH_UID \
  --rpc-url $SEPOLIA_RPC --private-key $OPERATOR_KEY
```

Each attestation must then be registered with
`EASClaimVerifier.registerAttestation(identity, 15 or 16, attestationUID)`, where
`identity` is the attestation's `recipient`. The verifier checks schema, recipient and
attester trust at registration time, and accepts the call only from the attester (the
bridge wallet) or an agent of `EASIdentityProxy`. Several attestations for one identity can
be registered in a single transaction with
`registerAttestations(identity, topics[], uids[])`.

**Wallet-as-identity only.** The bridge issues every attestation with `recipient` set to
the wallet that signed the registration. This works when that wallet is its own identity,
which is what `EASIdentityProxy.getIdentity` returns for a wallet with no link. It does not
work for a wallet linked to a separate identity: registering under the identity reverts
with `Recipient mismatch`, and registering under the wallet succeeds but `isVerified`
resolves the wallet to the identity, where nothing is registered. Until the bridge can
issue to a chosen recipient, use this integration only with unlinked wallets.

---

## Deployment Snippet

```bash
# 1. Use the schema the bridge already registered on Sepolia.
SCHEMA_UID=0x0b5f333cdb7e06e0d9f7c5fbd7a151bb0d8afbcde17017390ef73b673f841aa7

# 2. Deploy VLEILegalEntityPolicy (Topic 15, "LE"). The third argument is the optional
#    staleness bound in seconds; 0 disables it. Use 0 for the vlei-to-eas bridge: it sets
#    verifiedAt once at issuance, and liveness comes from EAS expiration and revocation.
#    Without --broadcast, forge create only simulates the deployment.
forge create contracts/policies/VLEIPolicy.sol:VLEIPolicy \
  --constructor-args 15 "LE" 0 \
  --rpc-url $SEPOLIA_RPC --private-key $DEPLOYER_KEY --broadcast
VLEI_LEGAL_ENTITY_POLICY=<"Deployed to" address printed above>

# 3. Deploy VLEIAuthorizedRolePolicy (Topic 16, "ECR"), same staleness argument.
forge create contracts/policies/VLEIPolicy.sol:VLEIPolicy \
  --constructor-args 16 "ECR" 0 \
  --rpc-url $SEPOLIA_RPC --private-key $DEPLOYER_KEY --broadcast
VLEI_AUTHORIZED_ROLE_POLICY=<"Deployed to" address printed above>

# 4. Map both topics to the bridge schema. Without this, registerAttestation reverts
#    with SchemaNotMappedForTopic. These setters need OPERATOR_ROLE on the verifier.
cast send $EAS_CLAIM_VERIFIER \
  "setTopicSchemaMapping(uint256,bytes32)" 15 $SCHEMA_UID \
  --rpc-url $SEPOLIA_RPC --private-key $OPERATOR_KEY

cast send $EAS_CLAIM_VERIFIER \
  "setTopicSchemaMapping(uint256,bytes32)" 16 $SCHEMA_UID \
  --rpc-url $SEPOLIA_RPC --private-key $OPERATOR_KEY

# 5. Register both policies in EASClaimVerifier.
cast send $EAS_CLAIM_VERIFIER \
  "setTopicPolicy(uint256,address)" 15 $VLEI_LEGAL_ENTITY_POLICY \
  --rpc-url $SEPOLIA_RPC --private-key $OPERATOR_KEY

cast send $EAS_CLAIM_VERIFIER \
  "setTopicPolicy(uint256,address)" 16 $VLEI_AUTHORIZED_ROLE_POLICY \
  --rpc-url $SEPOLIA_RPC --private-key $OPERATOR_KEY

# 6. Make the topics required, unless the token passes them to isVerifiedForTopics
#    (see "Making the topics required"). Needs OPERATOR_ROLE on the registry.
cast send $CLAIM_TOPICS_REGISTRY "addClaimTopic(uint256)" 15 \
  --rpc-url $SEPOLIA_RPC --private-key $OPERATOR_KEY

cast send $CLAIM_TOPICS_REGISTRY "addClaimTopic(uint256)" 16 \
  --rpc-url $SEPOLIA_RPC --private-key $OPERATOR_KEY
```

Steps 4 to 6 can instead be done by `script/ConfigureBridge.s.sol`, which is idempotent:
set `VLEI_BRIDGE_SCHEMA_UID`, `VLEI_LE_POLICY` and `VLEI_ROLE_POLICY`, and include `15,16`
in `REQUIRED_TOPICS`. The trusted-attester step above is separate in either case.

---

## What Is NOT Handled by This Integration

- **Actual deployment:** `VLEILegalEntityPolicy` and `VLEIAuthorizedRolePolicy` addresses
  in `deployments/sepolia.json` are currently zero: they have not been deployed yet.
- **Wiring on Sepolia:** with no policies deployed, the remaining steps of this guide
  (schema mapping, policy binding, required topics, trusted attester) are not recorded as
  done for the Sepolia deployment either.
- **Registration by the bridge:** the bridge issues attestations but does not call
  `registerAttestation`. Until it does, an `EASIdentityProxy` agent has to register each
  attestation, and again after every re-issue (a renewed LEI yields a new UID).
- **Separate identities:** wallets linked to a separate identity are not supported (see
  "Wallet-as-identity only").
- **ECR and OOR on one topic:** Topic 16 accepts one `credType`. The snippet configures
  `"ECR"`; accepting `"OOR"` as well needs a policy that does not exist yet.
- **KERI/GLEIF logic:** All vLEI validation is in `vlei-to-eas`. Shibui reads only the
  resulting EAS attestation.
