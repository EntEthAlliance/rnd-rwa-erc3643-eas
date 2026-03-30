# EAS-ERC3643 Bridge Integration Guide

## Overview

This guide provides step-by-step instructions for integrating the EAS-to-ERC-3643 Identity Bridge into your security token infrastructure. The bridge enables using Ethereum Attestation Service (EAS) for investor verification while maintaining compatibility with ERC-3643 (T-REX) compliant tokens.

## Prerequisites

- Solidity ^0.8.24
- Foundry or Hardhat development environment
- Existing ERC-3643 token deployment (or new deployment)
- EAS deployed on your target network (or use MockEAS for testing)

## Integration Paths

The bridge supports two integration modes:

### Path A: Pluggable Verifier (Recommended for new deployments)

Requires a modified `IdentityRegistry` that calls `EASClaimVerifier.isVerified()`.

**Best for:**
- New token deployments
- Full control over the identity stack
- Maximum flexibility

### Path B: IIdentity Wrapper (Zero-modification integration)

Deploys `EASClaimVerifierIdentityWrapper` contracts that implement `IIdentity` interface.

**Best for:**
- Existing T-REX deployments
- No modification to existing contracts
- Per-identity deployment model

---

## Path A: Pluggable Verifier Integration

### Step 1: Deploy Core Contracts

```solidity
// Deploy in order
EASTrustedIssuersAdapter adapter = new EASTrustedIssuersAdapter(ownerAddress);
EASIdentityProxy identityProxy = new EASIdentityProxy(ownerAddress);
EASClaimVerifier verifier = new EASClaimVerifier(ownerAddress);
```

### Step 2: Configure the Verifier

```solidity
// Point to EAS contract (use real address on mainnet/testnet)
verifier.setEASAddress(0x4200000000000000000000000000000000000021); // Base Sepolia

// Connect components
verifier.setTrustedIssuersAdapter(address(adapter));
verifier.setIdentityProxy(address(identityProxy));
verifier.setClaimTopicsRegistry(address(claimTopicsRegistry)); // Your existing registry
```

### Step 3: Map Claim Topics to EAS Schemas

```solidity
// Define your attestation schemas
bytes32 schemaKYC = keccak256("InvestorEligibility");
bytes32 schemaAccreditation = keccak256("Accreditation");

// Map ERC-3643 claim topics to EAS schemas
verifier.setTopicSchemaMapping(1, schemaKYC);        // Topic 1 = KYC
verifier.setTopicSchemaMapping(7, schemaAccreditation); // Topic 7 = Accreditation
```

### Step 4: Add Trusted Attesters

```solidity
// Prepare topics array
uint256[] memory topics = new uint256[](2);
topics[0] = 1; // KYC
topics[1] = 7; // Accreditation

// Add KYC provider as trusted attester
adapter.addTrustedAttester(kycProviderAddress, topics);
```

### Step 5: Modify Identity Registry

Your `IdentityRegistry` contract needs to call the verifier:

```solidity
// In your IdentityRegistry.sol
import {IEASClaimVerifier} from "./interfaces/IEASClaimVerifier.sol";

contract IdentityRegistry is IIdentityRegistry {
    IEASClaimVerifier public easVerifier;

    function setEASVerifier(address _verifier) external onlyOwner {
        easVerifier = IEASClaimVerifier(_verifier);
    }

    function isVerified(address _userAddress) public view returns (bool) {
        // Delegate to EAS verifier
        if (address(easVerifier) != address(0)) {
            return easVerifier.isVerified(_userAddress);
        }
        // Fallback to original logic
        return _legacyIsVerified(_userAddress);
    }
}
```

### Step 6: Register Investor Wallets (Multi-Wallet Support)

```solidity
// Register wallet to identity
identityProxy.registerWallet(walletAddress, identityAddress);

// Or batch register multiple wallets
address[] memory wallets = new address[](3);
wallets[0] = wallet1;
wallets[1] = wallet2;
wallets[2] = wallet3;
identityProxy.batchRegisterWallets(wallets, identityAddress);
```

### Step 7: Register Attestations

After a KYC provider creates an EAS attestation:

```solidity
// Register the attestation UID in the verifier
verifier.registerAttestation(identityAddress, claimTopic, attestationUID);
```

---

## Path B: IIdentity Wrapper Integration

### Step 1: Deploy Infrastructure (Same as Path A)

```solidity
EASTrustedIssuersAdapter adapter = new EASTrustedIssuersAdapter(ownerAddress);
EASClaimVerifier verifier = new EASClaimVerifier(ownerAddress);

// Configure verifier (same as Path A steps 2-4)
```

### Step 2: Deploy Wrapper per Identity

For each investor identity:

```solidity
EASClaimVerifierIdentityWrapper wrapper = new EASClaimVerifierIdentityWrapper(
    investorAddress,      // The identity this wrapper represents
    easAddress,           // EAS contract
    address(verifier),    // Your EASClaimVerifier
    address(adapter)      // Your EASTrustedIssuersAdapter
);
```

### Step 3: Register Wrapper in Identity Registry

```solidity
// The wrapper implements IIdentity, so it can be used directly
identityRegistry.registerIdentity(investorAddress, wrapper, countryCode);
```

### Step 4: Verification Flow

The existing T-REX flow works unchanged:

1. `Token.transfer()` calls `IdentityRegistry.isVerified()`
2. Registry calls `wrapper.isClaimValid()` for each required topic
3. Wrapper delegates to `EASClaimVerifier` which checks EAS attestations

---

## KYC Provider Integration

### Creating Attestations

KYC providers create attestations using the EAS protocol:

```solidity
import {IEAS, AttestationRequest, AttestationRequestData} from "@eas/IEAS.sol";

// Encode attestation data according to schema
bytes memory data = abi.encode(
    identityAddress,     // address identity
    uint8(1),            // KYCStatus: VERIFIED
    uint8(2),            // AccreditationType: ACCREDITED
    uint16(840),         // Country code: USA
    uint64(expirationTimestamp)
);

// Create attestation request
AttestationRequest memory request = AttestationRequest({
    schema: schemaUID,
    data: AttestationRequestData({
        recipient: identityAddress,
        expirationTime: 0,          // Or set EAS-level expiration
        revocable: true,
        refUID: bytes32(0),
        data: data,
        value: 0
    })
});

// Submit attestation
bytes32 attestationUID = eas.attest(request);
```

### Registering Attestations

After creating the attestation, register it with the verifier:

```solidity
// Anyone can call this (permissionless registration)
verifier.registerAttestation(identityAddress, TOPIC_KYC, attestationUID);
```

### Revoking Attestations

To revoke an attestation (e.g., compliance violation):

```solidity
RevocationRequest memory request = RevocationRequest({
    schema: schemaUID,
    data: RevocationRequestData({
        uid: attestationUID,
        value: 0
    })
});

eas.revoke(request);
// Verification automatically fails after revocation
```

---

## Multi-Wallet Identity Management

### Concept

The EASIdentityProxy enables multiple wallets to share a single identity's attestations:

```
Wallet A ──┐
Wallet B ──┼── Identity Address ── Attestations
Wallet C ──┘
```

### Management Operations

```solidity
// Add wallet to identity
identityProxy.registerWallet(newWallet, identityAddress);

// Remove wallet (e.g., compromised)
identityProxy.removeWallet(compromisedWallet);

// Query wallet's identity
address identity = identityProxy.getIdentity(walletAddress);

// List all wallets for identity
address[] memory wallets = identityProxy.getWallets(identityAddress);
```

### Authorization

Operations require one of:
- Contract owner
- Registered agent
- The identity address itself

```solidity
// Add agent who can manage wallet registrations
identityProxy.addAgent(agentAddress);
```

---

## Network Deployment Addresses

### EAS Contract Addresses

| Network | EAS Address |
|---------|-------------|
| Ethereum Mainnet | `0xA1207F3BBa224E2c9c3c6D5aF63D0eb1582Ce587` |
| Base | `0x4200000000000000000000000000000000000021` |
| Base Sepolia | `0x4200000000000000000000000000000000000021` |
| Optimism | `0x4200000000000000000000000000000000000021` |
| Arbitrum | `0xbD75f629A22Dc1ceD33dDA0b68c546A1c035c458` |

### Schema Registry Addresses

| Network | Schema Registry |
|---------|-----------------|
| Ethereum Mainnet | `0xA7b39296258348C78294F95B872b282326A97BDF` |
| Base | `0x4200000000000000000000000000000000000020` |
| Base Sepolia | `0x4200000000000000000000000000000000000020` |

---

## Common Patterns

### Upgrading Attestations (KYC Renewal)

```solidity
// Create new attestation with extended expiration
bytes32 newAttestationUID = eas.attest(renewalRequest);

// Register new attestation (overwrites old one for same topic/attester)
verifier.registerAttestation(identityAddress, TOPIC_KYC, newAttestationUID);
```

### Adding New Compliance Requirements

```solidity
// 1. Add new topic to registry
claimTopicsRegistry.addClaimTopic(TOPIC_NEW_REQUIREMENT);

// 2. Map topic to schema
verifier.setTopicSchemaMapping(TOPIC_NEW_REQUIREMENT, newSchemaUID);

// 3. Add attesters for new topic
adapter.addTrustedAttester(newAttesterAddress, topicsArray);

// Existing investors must now obtain new attestation
```

### Handling Attester Compromise

```solidity
// Remove compromised attester immediately
adapter.removeTrustedAttester(compromisedAttester);

// All attestations from this attester become invalid instantly
// Investors must re-verify with different attester
```

---

## Security Considerations

### Access Control

1. **Verifier Owner**: Can configure EAS address, adapters, schema mappings
2. **Adapter Owner**: Can add/remove trusted attesters
3. **IdentityProxy Owner**: Can add/remove agents
4. **Agents**: Can register/remove wallets

### Attestation Validation

The verifier validates attestations by checking:
- Attestation exists in EAS
- Schema matches expected schema for topic
- Attester is trusted for the claim topic
- Attestation is not revoked
- Attestation is not expired (EAS-level and data-level)

### Best Practices

1. **Use timelock** for admin operations in production
2. **Emit events** for all state changes (built into contracts)
3. **Monitor attestation expirations** proactively
4. **Implement emergency pause** functionality if needed
5. **Regular security audits** before mainnet deployment

---

## Troubleshooting

### Verification Returns False

Check in order:
1. Is EAS address configured? `verifier.getEASAddress()`
2. Is adapter configured? `verifier.getTrustedIssuersAdapter()`
3. Are claim topics set? `claimTopicsRegistry.getClaimTopics()`
4. Is schema mapped for each topic? `verifier.getSchemaUID(topic)`
5. Are attesters trusted? `adapter.isAttesterTrusted(attester, topic)`
6. Is attestation registered? `verifier.getRegisteredAttestation(identity, topic, attester)`
7. Is attestation valid (not revoked/expired)? Check EAS directly

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `EASNotConfigured` | EAS address not set | Call `setEASAddress()` |
| `SchemaNotMappedForTopic` | Missing schema mapping | Call `setTopicSchemaMapping()` |
| `AttesterNotTrusted` | Attester not in adapter | Call `addTrustedAttester()` |
| `RecipientMismatch` | Attestation recipient != identity | Create attestation with correct recipient |

---

## Example: Complete Integration Script

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {EASClaimVerifier} from "../contracts/EASClaimVerifier.sol";
import {EASTrustedIssuersAdapter} from "../contracts/EASTrustedIssuersAdapter.sol";
import {EASIdentityProxy} from "../contracts/EASIdentityProxy.sol";

contract IntegrationScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy contracts
        EASTrustedIssuersAdapter adapter = new EASTrustedIssuersAdapter(deployer);
        EASIdentityProxy identityProxy = new EASIdentityProxy(deployer);
        EASClaimVerifier verifier = new EASClaimVerifier(deployer);

        // 2. Configure verifier
        address eas = 0x4200000000000000000000000000000000000021; // Base
        verifier.setEASAddress(eas);
        verifier.setTrustedIssuersAdapter(address(adapter));
        verifier.setIdentityProxy(address(identityProxy));

        // 3. Set up schemas and attesters
        bytes32 schemaKYC = keccak256("InvestorEligibility");
        verifier.setTopicSchemaMapping(1, schemaKYC);

        address kycProvider = vm.envAddress("KYC_PROVIDER");
        uint256[] memory topics = new uint256[](1);
        topics[0] = 1;
        adapter.addTrustedAttester(kycProvider, topics);

        vm.stopBroadcast();
    }
}
```

---

## Next Steps

1. Review the [Schema Definitions](../schemas/schema-definitions.md) for attestation data formats
2. Check the [Architecture Documentation](../architecture/system-architecture.md) for system design
3. Run the test suite to understand expected behaviors: `forge test -vv`
4. Deploy to testnet and verify with sample attestations
