// SPDX-License-Identifier: Apache-2.0
// Copyright © 2026 Enterprise Ethereum Alliance Inc.
pragma solidity ^0.8.24;

import {IClaimTopicsRegistry} from "../interfaces/IClaimTopicsRegistry.sol";

/**
 * @title MockClaimTopicsRegistry
 * @author EEA Working Group
 * @notice Mock implementation of the ERC-3643 ClaimTopicsRegistry for testing
 * @dev Provides a simple implementation that allows adding/removing claim topics
 */
contract MockClaimTopicsRegistry is IClaimTopicsRegistry {
    // ============ Storage ============

    /// @notice Array of claim topics
    uint256[] private _claimTopics;

    /// @notice Mapping to check if a topic exists
    mapping(uint256 => bool) private _topicExists;

    /// @notice Owner address
    address public owner;

    // ============ Constructor ============

    constructor() {
        owner = msg.sender;
    }

    // ============ Modifiers ============

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    // ============ External Functions ============

    /**
     * @inheritdoc IClaimTopicsRegistry
     */
    function addClaimTopic(uint256 _claimTopic) external override onlyOwner {
        require(!_topicExists[_claimTopic], "Topic already exists");
        require(_claimTopics.length < 15, "Max 15 topics");

        _claimTopics.push(_claimTopic);
        _topicExists[_claimTopic] = true;

        emit ClaimTopicAdded(_claimTopic);
    }

    /**
     * @inheritdoc IClaimTopicsRegistry
     */
    function removeClaimTopic(uint256 _claimTopic) external override onlyOwner {
        require(_topicExists[_claimTopic], "Topic does not exist");

        uint256 length = _claimTopics.length;
        for (uint256 i = 0; i < length; i++) {
            if (_claimTopics[i] == _claimTopic) {
                _claimTopics[i] = _claimTopics[length - 1];
                _claimTopics.pop();
                break;
            }
        }

        _topicExists[_claimTopic] = false;

        emit ClaimTopicRemoved(_claimTopic);
    }

    /**
     * @inheritdoc IClaimTopicsRegistry
     */
    function getClaimTopics() external view override returns (uint256[] memory) {
        return _claimTopics;
    }

    // ============ Test Helpers ============

    /**
     * @notice Sets multiple claim topics at once
     * @param topics Array of topics to set
     */
    function setClaimTopics(uint256[] calldata topics) external onlyOwner {
        // Clear existing
        for (uint256 i = 0; i < _claimTopics.length; i++) {
            _topicExists[_claimTopics[i]] = false;
        }
        delete _claimTopics;

        // Add new
        for (uint256 i = 0; i < topics.length; i++) {
            require(!_topicExists[topics[i]], "Duplicate topic");
            _claimTopics.push(topics[i]);
            _topicExists[topics[i]] = true;
        }
    }

    /**
     * @notice Transfers ownership
     * @param newOwner The new owner address
     */
    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }
}
