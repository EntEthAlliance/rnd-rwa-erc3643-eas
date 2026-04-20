// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IEASTrustedIssuersAdapter
 * @author EEA Working Group
 * @notice Interface for managing trusted EAS attesters for specific claim topics
 * @dev Mirrors the ERC-3643 TrustedIssuersRegistry pattern for EAS attesters
 */
interface IEASTrustedIssuersAdapter {
    // ============ Events ============

    /// @notice Emitted when a trusted attester is added
    /// @param attester The address of the trusted attester
    /// @param claimTopics The claim topics the attester is authorized for
    event TrustedAttesterAdded(address indexed attester, uint256[] claimTopics);

    /// @notice Emitted when a trusted attester is removed
    /// @param attester The address of the removed attester
    event TrustedAttesterRemoved(address indexed attester);

    /// @notice Emitted when an attester's authorized topics are updated
    /// @param attester The address of the attester
    /// @param claimTopics The new claim topics the attester is authorized for
    event AttesterTopicsUpdated(address indexed attester, uint256[] claimTopics);

    /// @notice Emitted when the Issuer Authorization (Schema 2) UID is set.
    /// @param schemaUID The EAS schema UID used to validate authUIDs on `addTrustedAttester`
    event IssuerAuthSchemaUIDSet(bytes32 indexed schemaUID);

    /// @notice Emitted when the EAS contract address used for authUID validation is set.
    /// @param easAddress The new EAS contract address
    event EASAddressSet(address indexed easAddress);

    // ============ Errors ============

    /// @notice Thrown when attempting to add zero address as attester
    error ZeroAddressNotAllowed();

    /// @notice Thrown when attempting to add an already trusted attester
    error AttesterAlreadyTrusted(address attester);

    /// @notice Thrown when attempting to remove a non-trusted attester
    error AttesterNotTrusted(address attester);

    /// @notice Thrown when claim topics array is empty
    error EmptyClaimTopics();

    /// @notice Thrown when `addTrustedAttester` is called before the Schema 2 UID is configured.
    error IssuerAuthSchemaUIDNotSet();

    /// @notice Thrown when the `authUID` does not resolve to a live Schema 2 attestation.
    error IssuerAuthAttestationMissing();

    /// @notice Thrown when the Schema-2 attestation's `issuerAddress` does not equal the attester being added.
    error IssuerAuthRecipientMismatch();

    /// @notice Thrown when the `claimTopics` argument is not a subset of the Schema-2 `authorizedTopics`.
    error IssuerAuthTopicsNotAuthorized();

    /// @notice Thrown when EAS has not been configured on the adapter (required for authUID lookup).
    error EASNotConfigured();

    // ============ View Functions ============

    /**
     * @notice Checks if an attester is trusted for a specific claim topic
     * @param attester The attester address to check
     * @param claimTopic The claim topic ID
     * @return bool True if the attester is trusted for the topic
     */
    function isAttesterTrusted(address attester, uint256 claimTopic) external view returns (bool);

    /**
     * @notice Returns all trusted attesters for a specific claim topic
     * @param claimTopic The claim topic ID
     * @return address[] Array of trusted attester addresses
     */
    function getTrustedAttestersForTopic(uint256 claimTopic) external view returns (address[] memory);

    /**
     * @notice Returns all claim topics an attester is trusted for
     * @param attester The attester address
     * @return uint256[] Array of claim topic IDs
     */
    function getAttesterTopics(address attester) external view returns (uint256[] memory);

    /**
     * @notice Returns all trusted attesters
     * @return address[] Array of all trusted attester addresses
     */
    function getTrustedAttesters() external view returns (address[] memory);

    /**
     * @notice Checks if an address is a trusted attester (for any topic)
     * @param attester The attester address to check
     * @return bool True if the address is a trusted attester
     */
    function isTrustedAttester(address attester) external view returns (bool);

    // ============ Mutative Functions ============

    /**
     * @notice Adds a trusted attester for specific claim topics.
     * @dev Only callable by an operator role. Audit finding C-5: every add MUST be
     *      backed by a live EAS Schema-2 (Issuer Authorization) attestation whose
     *      `recipient` equals `attester` and whose `authorizedTopics` contain
     *      every entry of `claimTopics`. The adapter verifies the attestation
     *      before updating trust state. The Schema-2 resolver gates who can
     *      create such attestations (see `TrustedIssuerResolver`).
     * @param attester The address to add as trusted attester
     * @param claimTopics The claim topics the attester is authorized for
     * @param authUID The EAS attestation UID evidencing this authorization
     */
    function addTrustedAttester(address attester, uint256[] calldata claimTopics, bytes32 authUID) external;

    /**
     * @notice Removes a trusted attester
     * @dev Only callable by an operator role.
     * @param attester The attester address to remove
     */
    function removeTrustedAttester(address attester) external;

    /**
     * @notice Updates the claim topics a trusted attester is authorized for.
     * @dev Only callable by an operator role. The same Schema-2 `authUID` check
     *      as `addTrustedAttester` is applied to the new topic set.
     * @param attester The attester address to update
     * @param claimTopics The new claim topics the attester is authorized for
     * @param authUID The EAS attestation UID evidencing this authorization
     */
    function updateAttesterTopics(address attester, uint256[] calldata claimTopics, bytes32 authUID) external;

    /**
     * @notice Sets the EAS schema UID used to validate `authUID` on trust changes.
     * @dev Only callable by an admin role. Must be set before `addTrustedAttester`.
     * @param schemaUID The Schema 2 (Issuer Authorization) UID
     */
    function setIssuerAuthSchemaUID(bytes32 schemaUID) external;

    /**
     * @notice Returns the configured Issuer Authorization schema UID.
     */
    function getIssuerAuthSchemaUID() external view returns (bytes32);

    /**
     * @notice Sets the EAS contract address used for authUID lookups.
     * @dev Only callable by an admin role.
     */
    function setEASAddress(address easAddress) external;

    /**
     * @notice Returns the configured EAS contract address (or zero if unset).
     */
    function getEASAddress() external view returns (address);
}
