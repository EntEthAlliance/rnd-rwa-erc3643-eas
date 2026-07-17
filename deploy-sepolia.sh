#!/usr/bin/env bash
# Shibui full Sepolia deployment — run after funding 0x94141fc8B83e318F071F41ddcadB99bBC90fD5e3
set -euo pipefail

export PATH="/home/mg/.foundry/bin:$PATH"
cd "$(dirname "$0")"

source .env

echo "============================================================"
echo "  Shibui Sepolia Deployment"
echo "  Deployer : $ADMIN_ADDRESS"
echo "  RPC      : $RPC_URL"
echo "============================================================"

# ── Check balance ─────────────────────────────────────────────────────────────
BALANCE=$(cast balance "$ADMIN_ADDRESS" --rpc-url "$RPC_URL" 2>/dev/null || echo "0")
echo "Deployer balance: $BALANCE wei"
if [ "$BALANCE" = "0" ] || [ "$BALANCE" = "" ]; then
  echo "ERROR: Deployer wallet has no Sepolia ETH. Fund it first."
  exit 1
fi

# ── Step 1: Deploy contracts ──────────────────────────────────────────────────
echo ""
echo ">>> Step 1/3 — Deploying contracts..."
DEPLOY_OUT=$(forge script script/DeployTestnet.s.sol:DeployTestnet \
  --rpc-url "$RPC_URL" \
  --broadcast \
  --private-key "$PRIVATE_KEY" \
  -vvv 2>&1)
echo "$DEPLOY_OUT"

# Parse deployed addresses from output
VERIFIER_ADDRESS=$(echo "$DEPLOY_OUT" | grep -oP "EASClaimVerifier deployed at: \K0x[0-9a-fA-F]{40}" || true)
ADAPTER_ADDRESS=$(echo "$DEPLOY_OUT" | grep -oP "EASTrustedIssuersAdapter deployed at: \K0x[0-9a-fA-F]{40}" || true)
PROXY_ADDRESS=$(echo "$DEPLOY_OUT" | grep -oP "EASIdentityProxy deployed at: \K0x[0-9a-fA-F]{40}" || true)
ISSUER_AUTH_RESOLVER=$(echo "$DEPLOY_OUT" | grep -oP "TrustedIssuerResolver deployed at: \K0x[0-9a-fA-F]{40}" || true)
CLAIM_TOPICS_REGISTRY=$(echo "$DEPLOY_OUT" | grep -oP "ClaimTopicsRegistry deployed at: \K0x[0-9a-fA-F]{40}" || true)

# Update .env with Step 1 results
sed -i "s|^VERIFIER_ADDRESS=.*|VERIFIER_ADDRESS=$VERIFIER_ADDRESS|" .env
sed -i "s|^ADAPTER_ADDRESS=.*|ADAPTER_ADDRESS=$ADAPTER_ADDRESS|" .env
sed -i "s|^PROXY_ADDRESS=.*|PROXY_ADDRESS=$PROXY_ADDRESS|" .env
sed -i "s|^CLAIM_TOPICS_REGISTRY=.*|CLAIM_TOPICS_REGISTRY=$CLAIM_TOPICS_REGISTRY|" .env
sed -i "s|^ISSUER_AUTH_RESOLVER=.*|ISSUER_AUTH_RESOLVER=$ISSUER_AUTH_RESOLVER|" .env

echo "  EASClaimVerifier:        $VERIFIER_ADDRESS"
echo "  EASTrustedIssuersAdapter: $ADAPTER_ADDRESS"
echo "  EASIdentityProxy:        $PROXY_ADDRESS"
echo "  TrustedIssuerResolver:   $ISSUER_AUTH_RESOLVER"
echo "  ClaimTopicsRegistry:     $CLAIM_TOPICS_REGISTRY"

# ── Step 2: Register EAS schemas ──────────────────────────────────────────────
echo ""
echo ">>> Step 2/3 — Registering EAS schemas..."
SCHEMA_OUT=$(forge script script/RegisterSchemas.s.sol:RegisterSchemas \
  --rpc-url "$RPC_URL" \
  --broadcast \
  --private-key "$PRIVATE_KEY" \
  -vvv 2>&1)
echo "$SCHEMA_OUT"

INVESTOR_ELIGIBILITY_SCHEMA_UID=$(echo "$SCHEMA_OUT" | grep -oP "INVESTOR_ELIGIBILITY_SCHEMA_UID= \K0x[0-9a-fA-F]{64}" || true)
ISSUER_AUTHORIZATION_SCHEMA_UID=$(echo "$SCHEMA_OUT" | grep -oP "ISSUER_AUTHORIZATION_SCHEMA_UID= \K0x[0-9a-fA-F]{64}" || true)

sed -i "s|^INVESTOR_ELIGIBILITY_SCHEMA_UID=.*|INVESTOR_ELIGIBILITY_SCHEMA_UID=$INVESTOR_ELIGIBILITY_SCHEMA_UID|" .env
sed -i "s|^ISSUER_AUTHORIZATION_SCHEMA_UID=.*|ISSUER_AUTHORIZATION_SCHEMA_UID=$ISSUER_AUTHORIZATION_SCHEMA_UID|" .env

echo "  InvestorEligibility UID: $INVESTOR_ELIGIBILITY_SCHEMA_UID"
echo "  IssuerAuthorization UID: $ISSUER_AUTHORIZATION_SCHEMA_UID"

# ── Step 3: Wire everything ───────────────────────────────────────────────────
echo ""
echo ">>> Step 3/3 — Wiring schema UIDs, topic-policy bindings..."
forge script script/ConfigureBridge.s.sol:ConfigureBridge \
  --rpc-url "$RPC_URL" \
  --broadcast \
  --private-key "$PRIVATE_KEY" \
  -vvv

# ── Update deployments/sepolia.json ──────────────────────────────────────────
echo ""
echo ">>> Updating deployments/sepolia.json..."
python3 -c "
import json, os
with open('deployments/sepolia.json') as f:
    d = json.load(f)
d['shibui']['EASClaimVerifier'] = os.environ.get('VERIFIER_ADDRESS','')
d['shibui']['EASTrustedIssuersAdapter'] = os.environ.get('ADAPTER_ADDRESS','')
d['shibui']['EASIdentityProxy'] = os.environ.get('PROXY_ADDRESS','')
d['shibui']['TrustedIssuerResolver'] = os.environ.get('ISSUER_AUTH_RESOLVER','')
d['shibui']['ClaimTopicsRegistry'] = os.environ.get('CLAIM_TOPICS_REGISTRY','')
d['schemas']['investorEligibility'] = os.environ.get('INVESTOR_ELIGIBILITY_SCHEMA_UID','')
d['schemas']['issuerAuthorization'] = os.environ.get('ISSUER_AUTHORIZATION_SCHEMA_UID','')
d['deployer'] = os.environ.get('ADMIN_ADDRESS','')
from datetime import datetime, timezone
d['lastUpdated'] = datetime.now(timezone.utc).isoformat()
with open('deployments/sepolia.json','w') as f:
    json.dump(d, f, indent=2)
print('deployments/sepolia.json updated')
"

echo ""
echo "============================================================"
echo "  DEPLOYMENT COMPLETE"
echo "  Verifier : $VERIFIER_ADDRESS"
echo "  EASScan  : https://sepolia.easscan.org"
echo "  Schemas  : https://sepolia.easscan.org/schema/view/$INVESTOR_ELIGIBILITY_SCHEMA_UID"
echo "============================================================"
