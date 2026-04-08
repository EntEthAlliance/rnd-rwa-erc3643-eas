// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract RegistryOrbital is Ownable {
    string public constant ORBITAL_ID = "registry";
    string public constant ORBITAL_VERSION = "0.2.0-phase1";
    bytes32 public constant STORAGE_SLOT = keccak256("eea.valence.orbital.registry.storage.v1");

    struct ModuleMetadata {
        string id;
        string version;
        bytes32 storageSlot;
    }

    mapping(uint256 => bytes32) private _topicToSchema;
    mapping(address => mapping(uint256 => mapping(address => bytes32))) private _registeredAttestations;

    event TopicSchemaMapped(uint256 indexed topic, bytes32 indexed schemaUID);
    event AttestationRegistered(
        address indexed identity, uint256 indexed claimTopic, address indexed attester, bytes32 attestationUID
    );

    constructor(address initialOwner) Ownable(initialOwner) {}

    function moduleMetadata() external pure returns (ModuleMetadata memory) {
        return ModuleMetadata({id: ORBITAL_ID, version: ORBITAL_VERSION, storageSlot: STORAGE_SLOT});
    }

    function exportedSelectors() external pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](4);
        selectors[0] = this.setTopicSchemaMapping.selector;
        selectors[1] = this.getSchemaUID.selector;
        selectors[2] = this.registerAttestation.selector;
        selectors[3] = this.getRegisteredAttestation.selector;
    }

    function setTopicSchemaMapping(uint256 topic, bytes32 schemaUID) external onlyOwner {
        _topicToSchema[topic] = schemaUID;
        emit TopicSchemaMapped(topic, schemaUID);
    }

    function getSchemaUID(uint256 topic) external view returns (bytes32) {
        return _topicToSchema[topic];
    }

    function registerAttestation(address identity, uint256 claimTopic, address attester, bytes32 attestationUID)
        external
        onlyOwner
    {
        require(identity != address(0), "identity=0");
        require(attester != address(0), "attester=0");
        require(attestationUID != bytes32(0), "uid=0");

        _registeredAttestations[identity][claimTopic][attester] = attestationUID;
        emit AttestationRegistered(identity, claimTopic, attester, attestationUID);
    }

    function getRegisteredAttestation(address identity, uint256 claimTopic, address attester)
        external
        view
        returns (bytes32)
    {
        return _registeredAttestations[identity][claimTopic][attester];
    }
}
