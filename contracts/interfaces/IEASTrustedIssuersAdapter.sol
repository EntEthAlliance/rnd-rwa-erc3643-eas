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

    // ============ Errors ============

    /// @notice Thrown when attempting to add zero address as attester
    error ZeroAddressNotAllowed();

    /// @notice Thrown when attempting to add an already trusted attester
    error AttesterAlreadyTrusted(address attester);

    /// @notice Thrown when attempting to remove a non-trusted attester
    error AttesterNotTrusted(address attester);

    /// @notice Thrown when claim topics array is empty
    error EmptyClaimTopics();

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
     * @notice Adds a trusted attester for specific claim topics
     * @dev Only callable by owner or agent
     * @param attester The address to add as trusted attester
     * @param claimTopics The claim topics the attester is authorized for
     */
    function addTrustedAttester(address attester, uint256[] calldata claimTopics) external;

    /**
     * @notice Removes a trusted attester
     * @dev Only callable by owner or agent
     * @param attester The attester address to remove
     */
    function removeTrustedAttester(address attester) external;

    /**
     * @notice Updates the claim topics a trusted attester is authorized for
     * @dev Only callable by owner or agent
     * @param attester The attester address to update
     * @param claimTopics The new claim topics the attester is authorized for
     */
    function updateAttesterTopics(address attester, uint256[] calldata claimTopics) external;
}
