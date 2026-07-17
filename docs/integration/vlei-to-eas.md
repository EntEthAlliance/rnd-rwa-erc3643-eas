# vlei-to-eas × Shibui Integration

## What is vlei-to-eas?

`vlei-to-eas` (repo: `AlexeyKrasnoperov/vlei-to-eas`) is a Next.js bridge application
that translates GLEIF vLEI credentials into EAS attestations on-chain.

**Input:** vLEI credentials — GLEIF organizational identity credentials based on the
KERI (Key Event Receipt Infrastructure) protocol. Three credential types are relevant:

| Type | Name | Meaning |
|------|------|---------|
| `LE` | Legal Entity | The entity holds a valid, GLEIF-registered LEI |
| `ECR` | Engagement Context Role | A person is authorized to act in a specific context |
| `OOR` | Official Organizational Role | A person holds an official role (officer, director) |

**Output:** EAS attestations under a dedicated vLEI schema (Schema-2, separate from the
`InvestorEligibility` schema used by Shibui's existing 8 policy modules).

**Background monitors** re-check vLEI validity every 4 h and GLEIF LEI renewal every 12 h.
They automatically revoke or renew EAS attestations as the source credential state changes.

---

## Trust Chain

```
GLEIF Root of Trust (GLEIF vLEI Root AID)
  └── Qualified vLEI Issuer (QVI) — GLEIF-authorized credential issuer
        └── Legal Entity vLEI (LE credential, SAID verified by vlei-to-eas)
              └── ECR / OOR vLEI (role credential, chained to LE)
                    └── EAS attestation (minted by bridge wallet, Schema-2)
                          └── VLEIPolicy.validate() → Shibui ERC-3643 enforcement
```

At each step:
1. **GLEIF root → QVI:** GLEIF manages the root AID; QVIs are accredited out-of-band.
2. **QVI → LE credential:** The LE credential's SAID is registered in the GLEIF API.
3. **LE/ECR/OOR → EAS attestation:** `vlei-to-eas` verifies the KERI key-event log via
   a `vlei-verifier` sidecar and confirms the LEI record in the GLEIF API, then writes an
   EAS attestation. `vleiSaid != bytes32(0)` signals successful GLEIF confirmation.
4. **EAS attestation → Shibui:** `VLEIPolicy.validate()` checks staleness and `credType`,
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

## vLEI Schema (Schema-2)

ABI-encoded fields (in order):

```
string  lei             — GLEIF 20-character LEI code
string  legalName       — Legal entity name from GLEIF registry
string  credType        — "LE" | "ECR" | "OOR"
string  keriAid         — KERI AID of the credential holder
bytes32 vleiSaid        — SAID of the vLEI credential (zero = not yet GLEIF-confirmed)
uint64  verifiedAt      — Unix timestamp of last successful bridge verification
```

The schema UID must be registered on Sepolia's `SchemaRegistry` before deploying
`VLEIPolicy` instances. The registered UID goes into `deployments/sepolia.json`
under `shibui.vlei.bridgeSchemaUID`.

---

## Adding the Bridge Wallet as a Trusted Attester

The bridge wallet is enforced as the sole authorized attester by `AttesterResolver.sol`
in the vlei-to-eas repo. On the Shibui side, the bridge wallet must also be trusted
via the `IssuerAuthorization` schema (Schema-2 in the existing Shibui deployment).

```bash
# Register the bridge wallet as trusted for topics 15 and 16.
# BRIDGE_WALLET = the vlei-to-eas hot wallet address.
# SCHEMA_UID    = vLEI schema UID registered in SchemaRegistry.

cast send $EAS_TRUSTED_ISSUERS_ADAPTER \
  "addTrustedIssuer(address,uint256,bytes32)" \
  $BRIDGE_WALLET 15 $SCHEMA_UID \
  --rpc-url $SEPOLIA_RPC --private-key $DEPLOYER_KEY

cast send $EAS_TRUSTED_ISSUERS_ADAPTER \
  "addTrustedIssuer(address,uint256,bytes32)" \
  $BRIDGE_WALLET 16 $SCHEMA_UID \
  --rpc-url $SEPOLIA_RPC --private-key $DEPLOYER_KEY
```

---

## Deployment Snippet

```bash
export FOUNDRY_BIN=/home/mg/.foundry/bin
export PATH="$FOUNDRY_BIN:$PATH"

# 1. Register the vLEI schema on-chain (run once).
SCHEMA="string lei,string legalName,string credType,string keriAid,bytes32 vleiSaid,uint64 verifiedAt"
SCHEMA_UID=$(cast send $SCHEMA_REGISTRY \
  "register(string,address,bool)" "$SCHEMA" $ATTESTER_RESOLVER true \
  --rpc-url $SEPOLIA_RPC --private-key $DEPLOYER_KEY \
  | grep "logs" -A5 | ...)   # parse UID from receipt

# 2. Deploy VLEILegalEntityPolicy (Topic 15, "LE", 6 h staleness).
forge create contracts/policies/VLEIPolicy.sol:VLEIPolicy \
  --constructor-args 15 "LE" 21600 \
  --rpc-url $SEPOLIA_RPC --private-key $DEPLOYER_KEY

# 3. Deploy VLEIAuthorizedRolePolicy (Topic 16, "ECR", 6 h staleness).
forge create contracts/policies/VLEIPolicy.sol:VLEIPolicy \
  --constructor-args 16 "ECR" 21600 \
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
  in `deployments/sepolia.json` are currently zero — they have not been deployed yet.
- **ConfigureBridge wiring:** The vlei-to-eas bridge has not been configured to target
  Sepolia's `EASClaimVerifier` and the registered schema UID. This comes in the next PR.
- **Topic 16 OOR support:** Only `"ECR"` is configured by default. A second `VLEIPolicy`
  with `expectedCredType_ = "OOR"` can be deployed and registered independently.
- **KERI/GLEIF logic:** All vLEI validation is in `vlei-to-eas`. Shibui reads only the
  resulting EAS attestation.
