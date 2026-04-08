// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IEAS, Attestation} from "@eas/IEAS.sol";
import {RegistryOrbital} from "./RegistryOrbital.sol";
import {TrustedAttestersOrbital} from "./TrustedAttestersOrbital.sol";
import {IdentityMappingOrbital} from "./IdentityMappingOrbital.sol";

contract VerificationOrbital is Ownable {
    string public constant ORBITAL_ID = "verification";
    string public constant ORBITAL_VERSION = "0.2.0-phase1";
    bytes32 public constant STORAGE_SLOT = keccak256("eea.valence.orbital.verification.storage.v1");

    struct ModuleMetadata {
        string id;
        string version;
        bytes32 storageSlot;
    }

    IEAS private _eas;
    RegistryOrbital private _registry;
    TrustedAttestersOrbital private _trustedAttesters;
    IdentityMappingOrbital private _identityMapping;
    uint256[] private _requiredTopics;

    event VerificationDependenciesSet(address eas, address registry, address trustedAttesters, address identityMapping);
    event RequiredClaimTopicsSet(uint256[] topics);

    constructor(address initialOwner, address eas, address registry, address trustedAttesters, address identityMapping)
        Ownable(initialOwner)
    {
        _eas = IEAS(eas);
        _registry = RegistryOrbital(registry);
        _trustedAttesters = TrustedAttestersOrbital(trustedAttesters);
        _identityMapping = IdentityMappingOrbital(identityMapping);
    }

    function moduleMetadata() external pure returns (ModuleMetadata memory) {
        return ModuleMetadata({id: ORBITAL_ID, version: ORBITAL_VERSION, storageSlot: STORAGE_SLOT});
    }

    function exportedSelectors() external pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](6);
        selectors[0] = this.setDependencies.selector;
        selectors[1] = this.setRequiredClaimTopics.selector;
        selectors[2] = this.getRequiredClaimTopics.selector;
        selectors[3] = this.isVerified.selector;
        selectors[4] = this.verifyTopic.selector;
        selectors[5] = this.isAttestationValid.selector;
    }

    function setDependencies(address eas, address registry, address trustedAttesters, address identityMapping)
        external
        onlyOwner
    {
        _eas = IEAS(eas);
        _registry = RegistryOrbital(registry);
        _trustedAttesters = TrustedAttestersOrbital(trustedAttesters);
        _identityMapping = IdentityMappingOrbital(identityMapping);

        emit VerificationDependenciesSet(eas, registry, trustedAttesters, identityMapping);
    }

    function setRequiredClaimTopics(uint256[] calldata claimTopics) external onlyOwner {
        delete _requiredTopics;
        for (uint256 i = 0; i < claimTopics.length; i++) {
            _requiredTopics.push(claimTopics[i]);
        }
        emit RequiredClaimTopicsSet(claimTopics);
    }

    function getRequiredClaimTopics() external view returns (uint256[] memory) {
        return _requiredTopics;
    }

    function isVerified(address wallet) external view returns (bool) {
        require(address(_eas) != address(0), "eas=0");
        require(address(_registry) != address(0), "registry=0");
        require(address(_trustedAttesters) != address(0), "trusted=0");

        address identity = address(_identityMapping) == address(0) ? wallet : _identityMapping.getIdentity(wallet);

        if (_requiredTopics.length == 0) return true;

        for (uint256 i = 0; i < _requiredTopics.length; i++) {
            if (!verifyTopic(identity, _requiredTopics[i])) {
                return false;
            }
        }

        return true;
    }

    function verifyTopic(address identity, uint256 claimTopic) public view returns (bool) {
        bytes32 schemaUID = _registry.getSchemaUID(claimTopic);
        if (schemaUID == bytes32(0)) return false;

        address[] memory trusted = _trustedAttesters.getTrustedAttestersForTopic(claimTopic);
        if (trusted.length == 0) return false;

        for (uint256 i = 0; i < trusted.length; i++) {
            bytes32 uid = _registry.getRegisteredAttestation(identity, claimTopic, trusted[i]);
            if (uid != bytes32(0) && isAttestationValid(uid, schemaUID)) {
                return true;
            }
        }

        return false;
    }

    function isAttestationValid(bytes32 attestationUID, bytes32 expectedSchemaUID) public view returns (bool) {
        Attestation memory attestation = _eas.getAttestation(attestationUID);

        if (attestation.uid == bytes32(0)) return false;
        if (attestation.schema != expectedSchemaUID) return false;
        if (attestation.revocationTime != 0) return false;
        if (attestation.expirationTime != 0 && attestation.expirationTime <= block.timestamp) return false;

        if (attestation.data.length >= 160) {
            (,,,, uint64 expirationTimestamp) = abi.decode(attestation.data, (address, uint8, uint8, uint16, uint64));
            if (expirationTimestamp != 0 && expirationTimestamp <= block.timestamp) {
                return false;
            }
        }

        return true;
    }
}
