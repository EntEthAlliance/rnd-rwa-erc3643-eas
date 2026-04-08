# Phase 0 Artifact — Valence Storage Map

Status: **Frozen for Phase 1 scaffold**

## Adapter
- Slot namespace: `keccak256("eea.valence.adapter.storage.v1")`
- Responsibility: orbital composition metadata only.

## VerificationOrbital
- Slot namespace: `keccak256("eea.valence.orbital.verification.storage.v1")`
- State:
  - `IEAS _eas`
  - `RegistryOrbital _registry`
  - `TrustedAttestersOrbital _trustedAttesters`
  - `IdentityMappingOrbital _identityMapping`
  - `uint256[] _requiredTopics`

## RegistryOrbital
- Slot namespace: `keccak256("eea.valence.orbital.registry.storage.v1")`
- State:
  - `mapping(uint256 => bytes32) _topicToSchema`
  - `mapping(address => mapping(uint256 => mapping(address => bytes32))) _registeredAttestations`

## TrustedAttestersOrbital
- Slot namespace: `keccak256("eea.valence.orbital.trusted-attesters.storage.v1")`
- State:
  - `mapping(uint256 => mapping(address => bool)) _trustedByTopic`
  - `mapping(uint256 => address[]) _topicAttesters`

## IdentityMappingOrbital
- Slot namespace: `keccak256("eea.valence.orbital.identity-mapping.storage.v1")`
- State:
  - `mapping(address => address) _walletToIdentity`

## Storage Policy
- No cross-orbital direct mutation.
- Orbitals expose read/write APIs only through explicit selectors.
- New state in Phase 2+ requires version suffix bump (`*.storage.v2`) when layout is non-additive.
