# Deployment runbook

How to deploy, repair, and verify a Shibui stack on a testnet. The canonical
record of what is deployed lives in `deployments/`: if it is not reflected
there, it is not deployed.

## Principles

1. **One command deploys, one command verifies.** No address or schema UID is
   ever hand-copied between terminal sessions. The deploy script writes the
   manifest itself.
2. **A deployment is not done until the smoke test passes.**
   `script/VerifyDeployment.s.sol` is part of the deployment, not an optional
   extra. The 2026-07-17 Sepolia deployment shipped with every `isVerified()`
   call reverting because the verifier's dependencies were never wired; the
   smoke test exists so that class of failure cannot ship silently again.

## Fresh testnet deployment

Deploys the full stack, registers both EAS schemas, wires every dependency,
configures topic-schema and topic-policy mappings, sets the required topics,
and writes `deployments/<chainid>.autogen.json` (including the deployment
block).

```bash
PRIVATE_KEY=0x... \
forge script script/DeploySepolia.s.sol \
  --rpc-url "$RPC_SEPOLIA" --broadcast
```

Optional env: `ADMIN_ADDRESS` (defaults to deployer), `EAS_ADDRESS` and
`SCHEMA_REGISTRY` (auto-detected on Sepolia and Base Sepolia),
`REQUIRED_TOPICS` (defaults to `1,2,13`: KYC, AML, Sanctions).

Then verify (read-only, no broadcast):

```bash
VERIFIER_ADDRESS=<from manifest> \
forge script script/VerifyDeployment.s.sol --rpc-url "$RPC_SEPOLIA"
```

The smoke test asserts, in order: all four verifier dependencies are wired;
the claim topics registry is non-empty (an empty registry makes
`isVerified()` fail open); every required topic has a schema mapping and a
policy bound; and `isVerified()` on a probe address traverses the full read
path without reverting and returns `false`.

Finally, review the generated manifest and fold it into the canonical
`deployments/<network>.json` in the same PR that records the deployment.

## Repairing a deployed-but-unwired stack

For a network where contracts exist but the verifier dependencies are unset
(the state Sepolia was in as of 2026-07-17), a single run of
`ConfigureBridge` completes the configuration surface. When
`CLAIM_TOPICS_REGISTRY` is unset it deploys a fresh `ClaimTopicsRegistry`
and logs the address.

```bash
PRIVATE_KEY=0x... \
VERIFIER_ADDRESS=0xD096e49B67E20BFF6FA25A235F79E4Cc64342153 \
ADAPTER_ADDRESS=0x8011cc16757da380b23E24f5191A4FD5f43cE860 \
IDENTITY_PROXY_ADDRESS=0xc30647819F63131d2c1a8e1dd167D951806a30fE \
INVESTOR_ELIGIBILITY_SCHEMA_UID=0x5019b2b649bf839cdd038826df5476a2390c90144384dae5174c2851ae1d414c \
ISSUER_AUTHORIZATION_SCHEMA_UID=0x8b49c224cbec63563e7dcc0d6da7789b721cfe12212e615a658c13d931d9d7c8 \
REQUIRED_TOPICS=1,2,13 \
KYC_POLICY=0xddD2Bf48bb5808316e19C30633BeAB24a649Fd38 \
AML_POLICY=0xbE8553F116AC86EfE1B97B956B7244ad3a9F672c \
SANCTIONS_POLICY=0x005DDaEFCA205B9228B21FF24fF4852a6029a395 \
forge script script/ConfigureBridge.s.sol \
  --rpc-url "$RPC_SEPOLIA" --broadcast
```

Every setter in `ConfigureBridge` is safe to re-run. After it completes,
record the new `ClaimTopicsRegistry` address in
`deployments/sepolia.json#shibui.ClaimTopicsRegistry` and run the smoke test.

## Role requirements

| Action | Contract | Role |
|---|---|---|
| Wire dependencies, set mappings | `EASClaimVerifier` | `OPERATOR_ROLE` |
| Set EAS address, Schema-2 UID | `EASTrustedIssuersAdapter` | `DEFAULT_ADMIN_ROLE` |
| Add / remove required topics | `ClaimTopicsRegistry` | `OPERATOR_ROLE` |

On testnets the deploy admin holds all roles (`DeployTestnet` /
`DeploySepolia` semantics). On mainnet the multisig holds them
(`DeployMainnet`); run `ConfigureBridge` from an operator key.

## CI

Run the smoke test on a schedule and on every change to `deployments/`:

```bash
VERIFIER_ADDRESS=$(jq -r .shibui.EASClaimVerifier deployments/sepolia.json) \
forge script script/VerifyDeployment.s.sol --rpc-url "$RPC_SEPOLIA"
```

A red run means the published manifest points at a stack that cannot verify
anyone: treat it as a broken build of the product, because for any
integrator, it is.

## Known gaps (tracked as follow-ups)

- **Demo seeding on real EAS.** `SetupPilot` targets a local `MockEAS` only.
  Seeding Alice/Bob/Carol with real Sepolia attestations (including the
  Schema-2 authorizer flow) needs its own script before
  `deployments/sepolia.json#demo` can be populated.
- **Fail-closed on empty topics.** `isVerified()` currently returns `true`
  when the topics registry is empty. The smoke test guards this
  operationally; making the contract itself fail closed is a core-contract
  change that should go through the audit-ack gate.
