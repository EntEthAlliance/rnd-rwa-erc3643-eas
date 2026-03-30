// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IClaimTopicsRegistry
 * @notice Interface for the ERC-3643 Claim Topics Registry
 * @dev Compatible re-declaration for Solidity 0.8.24
 */
interface IClaimTopicsRegistry {
    /**
     * @notice Emitted when a claim topic has been added
     * @param claimTopic The required claim added
     */
    event ClaimTopicAdded(uint256 indexed claimTopic);

    /**
     * @notice Emitted when a claim topic has been removed
     * @param claimTopic The required claim removed
     */
    event ClaimTopicRemoved(uint256 indexed claimTopic);

    /**
     * @notice Add a trusted claim topic
     * @param _claimTopic The claim topic index
     */
    function addClaimTopic(uint256 _claimTopic) external;

    /**
     * @notice Remove a trusted claim topic
     * @param _claimTopic The claim topic index
     */
    function removeClaimTopic(uint256 _claimTopic) external;

    /**
     * @notice Get the trusted claim topics for the security token
     * @return Array of trusted claim topics
     */
    function getClaimTopics() external view returns (uint256[] memory);
}
