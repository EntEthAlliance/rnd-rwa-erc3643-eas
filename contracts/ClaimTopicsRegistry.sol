// SPDX-License-Identifier: Apache-2.0
// Copyright © 2026 Enterprise Ethereum Alliance Inc.
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IClaimTopicsRegistry} from "./interfaces/IClaimTopicsRegistry.sol";

/**
 * @title ClaimTopicsRegistry
 * @author EEA Working Group
 * @notice Production implementation of the ERC-3643 Claim Topics Registry.
 *         Holds the set of claim topics that `EASClaimVerifier.isVerified()`
 *         requires every investor to satisfy.
 *
 * @dev Prior to this contract the repository only shipped
 *      `mocks/MockClaimTopicsRegistry`, which left real networks with no
 *      registry to wire (`deployments/sepolia.json#shibui.ClaimTopicsRegistry`
 *      was `0x0`). This is the deployable counterpart:
 *        - Role-gated with the same AccessControl pattern as the verifier
 *          (DEFAULT_ADMIN_ROLE administers roles, OPERATOR_ROLE manages
 *          topics). Expected to be held by a multisig in production (R-6).
 *        - Bounded at MAX_TOPICS to keep `isVerified()` gas predictable —
 *          the verifier iterates this array on every transfer check.
 *        - `hasClaimTopic` view lets configuration scripts stay idempotent.
 */
contract ClaimTopicsRegistry is IClaimTopicsRegistry, AccessControl {
    // ============ Constants ============

    /// @notice Role allowed to add and remove claim topics.
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /// @notice Upper bound on required topics; matches the verifier's
    ///         iteration-cost assumptions (see gas-benchmarks.md).
    uint256 public constant MAX_TOPICS = 15;

    // ============ Storage ============

    /// @notice Ordered array of required claim topics.
    uint256[] private _claimTopics;

    /// @notice Existence index for O(1) duplicate checks.
    mapping(uint256 => bool) private _topicExists;

    // ============ Errors ============

    error ZeroAddressNotAllowed();
    error TopicAlreadyExists(uint256 claimTopic);
    error TopicDoesNotExist(uint256 claimTopic);
    error MaxTopicsReached();

    // ============ Constructor ============

    /**
     * @param initialAdmin Address granted DEFAULT_ADMIN_ROLE and
     *        OPERATOR_ROLE. Expected to be a multisig in production; the
     *        deployer should transfer admin and renounce, mirroring the
     *        verifier's role hand-off (audit finding R-6).
     */
    constructor(address initialAdmin) {
        if (initialAdmin == address(0)) revert ZeroAddressNotAllowed();
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
        _grantRole(OPERATOR_ROLE, initialAdmin);
    }

    // ============ External Functions ============

    /// @inheritdoc IClaimTopicsRegistry
    function addClaimTopic(uint256 _claimTopic) external override onlyRole(OPERATOR_ROLE) {
        if (_topicExists[_claimTopic]) revert TopicAlreadyExists(_claimTopic);
        if (_claimTopics.length >= MAX_TOPICS) revert MaxTopicsReached();

        _claimTopics.push(_claimTopic);
        _topicExists[_claimTopic] = true;

        emit ClaimTopicAdded(_claimTopic);
    }

    /// @inheritdoc IClaimTopicsRegistry
    function removeClaimTopic(uint256 _claimTopic) external override onlyRole(OPERATOR_ROLE) {
        if (!_topicExists[_claimTopic]) revert TopicDoesNotExist(_claimTopic);

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

    /// @inheritdoc IClaimTopicsRegistry
    function getClaimTopics() external view override returns (uint256[] memory) {
        return _claimTopics;
    }

    /// @notice True if `claimTopic` is currently required.
    /// @dev Used by configuration scripts to make topic setup idempotent.
    function hasClaimTopic(uint256 claimTopic) external view returns (bool) {
        return _topicExists[claimTopic];
    }
}
