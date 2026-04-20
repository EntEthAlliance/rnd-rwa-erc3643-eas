// SPDX-License-Identifier: Apache-2.0
// Copyright © 2026 Enterprise Ethereum Alliance Inc.
pragma solidity ^0.8.24;

/**
 * @title IERC734
 * @author EEA Working Group
 * @notice ERC-734 Key Holder interface for on-chain identity key management
 * @dev Compatible re-declaration for Solidity 0.8.24. This interface defines
 *      the standard for managing cryptographic keys associated with an identity.
 */
interface IERC734 {
    /// @notice Emitted when a key is added to the identity
    event KeyAdded(bytes32 indexed key, uint256 indexed purpose, uint256 indexed keyType);

    /// @notice Emitted when a key is removed from the identity
    event KeyRemoved(bytes32 indexed key, uint256 indexed purpose, uint256 indexed keyType);

    /// @notice Emitted when an execution is requested
    event ExecutionRequested(uint256 indexed executionId, address indexed to, uint256 indexed value, bytes data);

    /// @notice Emitted when an execution is completed
    event Executed(uint256 indexed executionId, address indexed to, uint256 indexed value, bytes data);

    /// @notice Emitted when an execution is approved
    event Approved(uint256 indexed executionId, bool approved);

    /**
     * @notice Adds a key to the identity
     * @param _key The key to add
     * @param _purpose The purpose of the key (1=MANAGEMENT, 2=ACTION, 3=CLAIM, 4=ENCRYPTION)
     * @param _keyType The type of key (1=ECDSA, 2=RSA)
     * @return success True if the key was added successfully
     */
    function addKey(bytes32 _key, uint256 _purpose, uint256 _keyType) external returns (bool success);

    /**
     * @notice Removes a key from the identity
     * @param _key The key to remove
     * @param _purpose The purpose to remove the key from
     * @return success True if the key was removed successfully
     */
    function removeKey(bytes32 _key, uint256 _purpose) external returns (bool success);

    /**
     * @notice Executes a transaction from the identity
     * @param _to The target address
     * @param _value The ETH value to send
     * @param _data The call data
     * @return executionId The ID of the execution request
     */
    function execute(address _to, uint256 _value, bytes calldata _data) external returns (uint256 executionId);

    /**
     * @notice Approves an execution request
     * @param _id The execution ID to approve
     * @param _approve True to approve, false to reject
     * @return success True if the approval was successful
     */
    function approve(uint256 _id, bool _approve) external returns (bool success);

    /**
     * @notice Gets a key by its identifier
     * @param _key The key identifier
     * @return purposes Array of purposes this key has
     * @return keyType The type of key
     * @return key The key identifier
     */
    function getKey(bytes32 _key) external view returns (uint256[] memory purposes, uint256 keyType, bytes32 key);

    /**
     * @notice Checks if a key has a specific purpose
     * @param _key The key to check
     * @param _purpose The purpose to check for
     * @return exists True if the key has the specified purpose
     */
    function keyHasPurpose(bytes32 _key, uint256 _purpose) external view returns (bool exists);

    /**
     * @notice Gets all keys with a specific purpose
     * @param _purpose The purpose to query
     * @return keys Array of key identifiers with the specified purpose
     */
    function getKeysByPurpose(uint256 _purpose) external view returns (bytes32[] memory keys);
}

/**
 * @title IERC735
 * @author EEA Working Group
 * @notice ERC-735 Claim Holder interface for on-chain identity claims
 * @dev Compatible re-declaration for Solidity 0.8.24. This interface defines
 *      the standard for managing claims (attestations) associated with an identity.
 */
interface IERC735 {
    /// @notice Emitted when a claim is added to the identity
    event ClaimAdded(
        bytes32 indexed claimId,
        uint256 indexed topic,
        uint256 scheme,
        address indexed issuer,
        bytes signature,
        bytes data,
        string uri
    );

    /// @notice Emitted when a claim is removed from the identity
    event ClaimRemoved(
        bytes32 indexed claimId,
        uint256 indexed topic,
        uint256 scheme,
        address indexed issuer,
        bytes signature,
        bytes data,
        string uri
    );

    /// @notice Emitted when a claim is changed
    event ClaimChanged(
        bytes32 indexed claimId,
        uint256 indexed topic,
        uint256 scheme,
        address indexed issuer,
        bytes signature,
        bytes data,
        string uri
    );

    /**
     * @notice Adds a claim to the identity
     * @param _topic The claim topic (e.g., 1=KYC, 7=ACCREDITATION)
     * @param _scheme The signature scheme used
     * @param issuer The address of the claim issuer
     * @param _signature The signature proving the claim
     * @param _data The claim data
     * @param _uri Optional URI for additional claim information
     * @return claimRequestId The ID of the claim
     */
    function addClaim(
        uint256 _topic,
        uint256 _scheme,
        address issuer,
        bytes calldata _signature,
        bytes calldata _data,
        string calldata _uri
    ) external returns (bytes32 claimRequestId);

    /**
     * @notice Removes a claim from the identity
     * @param _claimId The ID of the claim to remove
     * @return success True if the claim was removed successfully
     */
    function removeClaim(bytes32 _claimId) external returns (bool success);

    /**
     * @notice Gets a claim by its ID
     * @param _claimId The claim ID to look up
     * @return topic The claim topic
     * @return scheme The signature scheme
     * @return issuer The claim issuer address
     * @return signature The claim signature
     * @return data The claim data
     * @return uri The claim URI
     */
    function getClaim(bytes32 _claimId)
        external
        view
        returns (
            uint256 topic,
            uint256 scheme,
            address issuer,
            bytes memory signature,
            bytes memory data,
            string memory uri
        );

    /**
     * @notice Gets all claim IDs for a specific topic
     * @param _topic The topic to query
     * @return claimIds Array of claim IDs for the topic
     */
    function getClaimIdsByTopic(uint256 _topic) external view returns (bytes32[] memory claimIds);
}

/**
 * @title IIdentity
 * @author EEA Working Group
 * @notice Combined ERC-734 + ERC-735 identity interface for ONCHAINID compatibility
 * @dev Compatible re-declaration for Solidity 0.8.24. This interface combines
 *      key management (ERC-734) and claim management (ERC-735) into a single
 *      identity interface as used by the ERC-3643 security token standard.
 */
interface IIdentity is IERC734, IERC735 {
    /**
     * @notice Validates a claim against this identity
     * @param _identity The identity to validate the claim for
     * @param claimTopic The topic of the claim to validate
     * @param sig The signature to validate
     * @param data The claim data to validate
     * @return True if the claim is valid
     */
    function isClaimValid(IIdentity _identity, uint256 claimTopic, bytes calldata sig, bytes calldata data)
        external
        view
        returns (bool);
}
