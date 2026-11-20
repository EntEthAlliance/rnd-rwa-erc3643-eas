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
| 16 | `VLEI_AUTHORIZED_ROLE` | `"ECR"` or `"OOR"` | Proves a person has an authorized organizational role |

Each topic gets its own `VLEIPolicy` instance deployed with the matching `expectedCredType_`.

For Topic 16, if both ECR and OOR credentials should be accepted, deploy two `VLEIPolicy`
instances (one per `credType`) and register both as trusted attesters for Topic 16 in
`EASTrustedIssuersAdapter`.

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
# BRIDGE_WALLET = 0x8EF2312aB6A316a0CA9Ad90661B6bccE8A7eCdc6 (vlei-to-eas attester)

# 2. Register the bridge wallet as a trusted attester for both topics in one call.
cast send $EAS_TRUSTED_ISSUERS_ADAPTER \
  "addTrustedAttester(address,uint256[],bytes32)" \
  $BRIDGE_WALLET "[15,16]" $AUTH_UID \
  --rpc-url $SEPOLIA_RPC --private-key $OPERATOR_KEY
```

Per attestation, the bridge (or an identity-proxy agent) then calls
`EASClaimVerifier.registerAttestation(identity, 15 or 16, attestationUID)`, where
`identity` is the attestation's `recipient`. That is the holder's wallet unless the wallet
is linked to a separate identity in `EASIdentityProxy`. The verifier checks schema,
recipient and attester trust at registration time. Several attestations for one identity
can be registered in a single transaction with
`registerAttestations(identity, topics[], uids[])`.

---

## Deployment Snippet

```bash
export FOUNDRY_BIN=/home/mg/.foundry/bin
export PATH="$FOUNDRY_BIN:$PATH"

# 1. Use the schema the bridge already registered on Sepolia.
SCHEMA_UID=0x0b5f333cdb7e06e0d9f7c5fbd7a151bb0d8afbcde17017390ef73b673f841aa7

# 2. Deploy VLEILegalEntityPolicy (Topic 15, "LE"). The third argument is the optional
#    staleness bound in seconds; 0 disables it. Use 0 for the vlei-to-eas bridge: it sets
#    verifiedAt once at issuance, and liveness comes from EAS expiration and revocation.
forge create contracts/policies/VLEIPolicy.sol:VLEIPolicy \
  --constructor-args 15 "LE" 0 \
  --rpc-url $SEPOLIA_RPC --private-key $DEPLOYER_KEY

# 3. Deploy VLEIAuthorizedRolePolicy (Topic 16, "ECR"), same staleness argument.
forge create contracts/policies/VLEIPolicy.sol:VLEIPolicy \
  --constructor-args 16 "ECR" 0 \
  --rpc-url $SEPOLIA_RPC --private-key $DEPLOYER_KEY

# 4. Register both policies in EASClaimVerifier.
cast send $EAS_CLAIM_VERIFIER \
  "setTopicPolicy(uint256,address)" 15 $VLEI_LEGAL_ENTITY_POLICY \
  --rpc-url $SEPOLIA_RPC --private-key $DEPLOYER_KEY

cast send $EAS_CLAIM_VERIFIER \
  "setTopicPolicy(uint256,address)" 16 $VLEI_AUTHORIZED_ROLE_POLICY \
  --rpc-url $SEPOLIA_RPC --private-key $DEPLOYER_KEY
```

---

## What Is NOT Handled by This Integration

- **Actual deployment:** `VLEILegalEntityPolicy` and `VLEIAuthorizedRolePolicy` addresses
  in `deployments/sepolia.json` are currently zero: they have not been deployed yet.
- **ConfigureBridge wiring:** The vlei-to-eas bridge has not been configured to target
  Sepolia's `EASClaimVerifier` and the registered schema UID. This comes in the next PR.
- **Topic 16 OOR support:** Only `"ECR"` is configured by default. A second `VLEIPolicy`
  with `expectedCredType_ = "OOR"` can be deployed and registered independently.
- **KERI/GLEIF logic:** All vLEI validation is in `vlei-to-eas`. Shibui reads only the
  resulting EAS attestation.
