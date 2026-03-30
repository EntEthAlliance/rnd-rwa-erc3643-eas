// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IEAS, AttestationRequest, AttestationRequestData, MultiAttestationRequest, DelegatedAttestationRequest, MultiDelegatedAttestationRequest, RevocationRequest, RevocationRequestData, MultiRevocationRequest, DelegatedRevocationRequest, MultiDelegatedRevocationRequest} from "@eas/IEAS.sol";
import {Attestation, EMPTY_UID} from "@eas/Common.sol";
import {ISchemaRegistry} from "@eas/ISchemaRegistry.sol";

/**
 * @title MockEAS
 * @author EEA Working Group
 * @notice Mock implementation of the Ethereum Attestation Service for testing
 * @dev Provides a simplified EAS implementation that stores attestations in memory
 *      and supports basic operations needed for testing the EAS-to-ERC-3643 bridge.
 */
contract MockEAS is IEAS {
    // ============ Storage ============

    /// @notice Counter for generating unique attestation UIDs
    uint256 private _uidCounter;

    /// @notice Mapping from UID to attestation
    mapping(bytes32 => Attestation) private _attestations;

    /// @notice Mock schema registry
    ISchemaRegistry private _schemaRegistry;

    // ============ Constructor ============

    constructor() {
        _uidCounter = 1;
    }

    // ============ Schema Registry ============

    /**
     * @notice Sets the mock schema registry
     * @param schemaRegistry The schema registry address
     */
    function setSchemaRegistry(address schemaRegistry) external {
        _schemaRegistry = ISchemaRegistry(schemaRegistry);
    }

    /**
     * @inheritdoc IEAS
     */
    function getSchemaRegistry() external view override returns (ISchemaRegistry) {
        return _schemaRegistry;
    }

    // ============ Attestation Functions ============

    /**
     * @inheritdoc IEAS
     */
    function attest(
        AttestationRequest calldata request
    ) external payable override returns (bytes32) {
        bytes32 uid = _generateUID();

        _attestations[uid] = Attestation({
            uid: uid,
            schema: request.schema,
            time: uint64(block.timestamp),
            expirationTime: request.data.expirationTime,
            revocationTime: 0,
            refUID: request.data.refUID,
            recipient: request.data.recipient,
            attester: msg.sender,
            revocable: request.data.revocable,
            data: request.data.data
        });

        emit Attested(request.data.recipient, msg.sender, uid, request.schema);

        return uid;
    }

    /**
     * @notice Creates an attestation from a specific attester (for testing)
     * @param request The attestation request
     * @param attester The attester address to use
     * @return The attestation UID
     */
    function attestFrom(
        AttestationRequest calldata request,
        address attester
    ) external returns (bytes32) {
        bytes32 uid = _generateUID();

        _attestations[uid] = Attestation({
            uid: uid,
            schema: request.schema,
            time: uint64(block.timestamp),
            expirationTime: request.data.expirationTime,
            revocationTime: 0,
            refUID: request.data.refUID,
            recipient: request.data.recipient,
            attester: attester,
            revocable: request.data.revocable,
            data: request.data.data
        });

        emit Attested(request.data.recipient, attester, uid, request.schema);

        return uid;
    }

    /**
     * @inheritdoc IEAS
     */
    function attestByDelegation(
        DelegatedAttestationRequest calldata delegatedRequest
    ) external payable override returns (bytes32) {
        bytes32 uid = _generateUID();

        _attestations[uid] = Attestation({
            uid: uid,
            schema: delegatedRequest.schema,
            time: uint64(block.timestamp),
            expirationTime: delegatedRequest.data.expirationTime,
            revocationTime: 0,
            refUID: delegatedRequest.data.refUID,
            recipient: delegatedRequest.data.recipient,
            attester: delegatedRequest.attester,
            revocable: delegatedRequest.data.revocable,
            data: delegatedRequest.data.data
        });

        emit Attested(delegatedRequest.data.recipient, delegatedRequest.attester, uid, delegatedRequest.schema);

        return uid;
    }

    /**
     * @inheritdoc IEAS
     */
    function multiAttest(
        MultiAttestationRequest[] calldata multiRequests
    ) external payable override returns (bytes32[] memory) {
        uint256 totalCount = 0;
        for (uint256 i = 0; i < multiRequests.length; i++) {
            totalCount += multiRequests[i].data.length;
        }

        bytes32[] memory uids = new bytes32[](totalCount);
        uint256 index = 0;

        for (uint256 i = 0; i < multiRequests.length; i++) {
            bytes32 schema = multiRequests[i].schema;
            for (uint256 j = 0; j < multiRequests[i].data.length; j++) {
                bytes32 uid = _generateUID();
                AttestationRequestData memory reqData = multiRequests[i].data[j];

                _attestations[uid] = Attestation({
                    uid: uid,
                    schema: schema,
                    time: uint64(block.timestamp),
                    expirationTime: reqData.expirationTime,
                    revocationTime: 0,
                    refUID: reqData.refUID,
                    recipient: reqData.recipient,
                    attester: msg.sender,
                    revocable: reqData.revocable,
                    data: reqData.data
                });

                emit Attested(reqData.recipient, msg.sender, uid, schema);
                uids[index++] = uid;
            }
        }

        return uids;
    }

    /**
     * @inheritdoc IEAS
     */
    function multiAttestByDelegation(
        MultiDelegatedAttestationRequest[] calldata multiDelegatedRequests
    ) external payable override returns (bytes32[] memory) {
        uint256 totalCount = 0;
        for (uint256 i = 0; i < multiDelegatedRequests.length; i++) {
            totalCount += multiDelegatedRequests[i].data.length;
        }

        bytes32[] memory uids = new bytes32[](totalCount);
        uint256 index = 0;

        for (uint256 i = 0; i < multiDelegatedRequests.length; i++) {
            bytes32 schema = multiDelegatedRequests[i].schema;
            address attester = multiDelegatedRequests[i].attester;
            for (uint256 j = 0; j < multiDelegatedRequests[i].data.length; j++) {
                bytes32 uid = _generateUID();
                AttestationRequestData memory reqData = multiDelegatedRequests[i].data[j];

                _attestations[uid] = Attestation({
                    uid: uid,
                    schema: schema,
                    time: uint64(block.timestamp),
                    expirationTime: reqData.expirationTime,
                    revocationTime: 0,
                    refUID: reqData.refUID,
                    recipient: reqData.recipient,
                    attester: attester,
                    revocable: reqData.revocable,
                    data: reqData.data
                });

                emit Attested(reqData.recipient, attester, uid, schema);
                uids[index++] = uid;
            }
        }

        return uids;
    }

    // ============ Revocation Functions ============

    /**
     * @inheritdoc IEAS
     */
    function revoke(RevocationRequest calldata request) external payable override {
        Attestation storage attestation = _attestations[request.data.uid];
        require(attestation.uid != EMPTY_UID, "Attestation not found");
        require(attestation.attester == msg.sender, "Only attester can revoke");
        require(attestation.revocable, "Attestation not revocable");
        require(attestation.revocationTime == 0, "Already revoked");

        attestation.revocationTime = uint64(block.timestamp);

        emit Revoked(attestation.recipient, msg.sender, request.data.uid, attestation.schema);
    }

    /**
     * @inheritdoc IEAS
     */
    function revokeByDelegation(
        DelegatedRevocationRequest calldata delegatedRequest
    ) external payable override {
        Attestation storage attestation = _attestations[delegatedRequest.data.uid];
        require(attestation.uid != EMPTY_UID, "Attestation not found");
        require(attestation.attester == delegatedRequest.revoker, "Only attester can revoke");
        require(attestation.revocable, "Attestation not revocable");
        require(attestation.revocationTime == 0, "Already revoked");

        attestation.revocationTime = uint64(block.timestamp);

        emit Revoked(attestation.recipient, delegatedRequest.revoker, delegatedRequest.data.uid, attestation.schema);
    }

    /**
     * @inheritdoc IEAS
     */
    function multiRevoke(
        MultiRevocationRequest[] calldata multiRequests
    ) external payable override {
        for (uint256 i = 0; i < multiRequests.length; i++) {
            for (uint256 j = 0; j < multiRequests[i].data.length; j++) {
                bytes32 uid = multiRequests[i].data[j].uid;
                Attestation storage attestation = _attestations[uid];

                if (
                    attestation.uid != EMPTY_UID &&
                    attestation.attester == msg.sender &&
                    attestation.revocable &&
                    attestation.revocationTime == 0
                ) {
                    attestation.revocationTime = uint64(block.timestamp);
                    emit Revoked(attestation.recipient, msg.sender, uid, attestation.schema);
                }
            }
        }
    }

    /**
     * @inheritdoc IEAS
     */
    function multiRevokeByDelegation(
        MultiDelegatedRevocationRequest[] calldata multiDelegatedRequests
    ) external payable override {
        for (uint256 i = 0; i < multiDelegatedRequests.length; i++) {
            address revoker = multiDelegatedRequests[i].revoker;
            for (uint256 j = 0; j < multiDelegatedRequests[i].data.length; j++) {
                bytes32 uid = multiDelegatedRequests[i].data[j].uid;
                Attestation storage attestation = _attestations[uid];

                if (
                    attestation.uid != EMPTY_UID &&
                    attestation.attester == revoker &&
                    attestation.revocable &&
                    attestation.revocationTime == 0
                ) {
                    attestation.revocationTime = uint64(block.timestamp);
                    emit Revoked(attestation.recipient, revoker, uid, attestation.schema);
                }
            }
        }
    }

    // ============ Query Functions ============

    /**
     * @inheritdoc IEAS
     */
    function getAttestation(bytes32 uid) external view override returns (Attestation memory) {
        return _attestations[uid];
    }

    /**
     * @inheritdoc IEAS
     */
    function isAttestationValid(bytes32 uid) external view override returns (bool) {
        Attestation memory attestation = _attestations[uid];
        return attestation.uid != EMPTY_UID && attestation.revocationTime == 0;
    }

    // ============ Timestamp Functions ============

    /**
     * @inheritdoc IEAS
     */
    function timestamp(bytes32) external view override returns (uint64) {
        return uint64(block.timestamp);
    }

    /**
     * @inheritdoc IEAS
     */
    function multiTimestamp(bytes32[] calldata) external view override returns (uint64) {
        return uint64(block.timestamp);
    }

    /**
     * @inheritdoc IEAS
     */
    function revokeOffchain(bytes32) external view override returns (uint64) {
        return uint64(block.timestamp);
    }

    /**
     * @inheritdoc IEAS
     */
    function multiRevokeOffchain(bytes32[] calldata) external view override returns (uint64) {
        return uint64(block.timestamp);
    }

    /**
     * @inheritdoc IEAS
     */
    function getTimestamp(bytes32) external view override returns (uint64) {
        return uint64(block.timestamp);
    }

    /**
     * @inheritdoc IEAS
     */
    function getRevokeOffchain(address, bytes32) external pure override returns (uint64) {
        return 0;
    }

    // ============ Semver ============

    /**
     * @notice Returns the version of the contract
     */
    function version() external pure returns (string memory) {
        return "1.0.0";
    }

    // ============ Internal Functions ============

    /**
     * @notice Generates a unique attestation UID
     * @return The generated UID
     */
    function _generateUID() internal returns (bytes32) {
        return keccak256(abi.encodePacked(block.timestamp, msg.sender, _uidCounter++));
    }

    // ============ Test Helpers ============

    /**
     * @notice Directly sets an attestation (for testing edge cases)
     * @param attestation The attestation to set
     */
    function setAttestation(Attestation memory attestation) external {
        _attestations[attestation.uid] = attestation;
    }

    /**
     * @notice Revokes an attestation directly (for testing)
     * @param uid The attestation UID to revoke
     */
    function forceRevoke(bytes32 uid) external {
        Attestation storage attestation = _attestations[uid];
        require(attestation.uid != EMPTY_UID, "Attestation not found");
        attestation.revocationTime = uint64(block.timestamp);
    }
}
