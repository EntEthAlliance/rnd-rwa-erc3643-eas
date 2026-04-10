// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IEASTrustedIssuersAdapter} from "./interfaces/IEASTrustedIssuersAdapter.sol";

/**
 * @title EASTrustedIssuersAdapter
 * @author EEA Working Group
 * @notice Manages trusted EAS attesters for ERC-3643 compliance verification
 * @dev Mirrors the ERC-3643 TrustedIssuersRegistry pattern but for EAS attesters.
 *      This contract maintains which attester addresses are authorized to create
 *      compliance attestations for specific claim topics.
 */
contract EASTrustedIssuersAdapter is IEASTrustedIssuersAdapter, Ownable {
    // ============ Constants ============

    /// @notice Maximum number of trusted attesters (matching ERC-3643's limit of 50)
    uint256 public constant MAX_ATTESTERS = 50;

    /// @notice Maximum number of topics per attester (matching ERC-3643's limit of 15)
    uint256 public constant MAX_TOPICS_PER_ATTESTER = 15;

    /// @notice Maximum number of trusted attesters allowed per topic
    uint256 public constant MAX_ATTESTERS_PER_TOPIC = 5;

    // ============ Storage ============

    /// @notice Array of all trusted attester addresses
    address[] private _trustedAttesters;

    /// @notice Mapping from attester to their authorized claim topics
    mapping(address => uint256[]) private _attesterClaimTopics;

    /// @notice Mapping from claim topic to array of trusted attesters
    mapping(uint256 => address[]) private _claimTopicToAttesters;

    /// @notice Mapping to check if an address is a trusted attester
    mapping(address => bool) private _isTrusted;

    /// @notice Mapping to check if attester is trusted for a specific topic
    mapping(address => mapping(uint256 => bool)) private _attesterTrustedForTopic;

    // ============ Constructor ============

    /**
     * @notice Initializes the adapter with an owner
     * @param initialOwner The initial owner address
     */
    constructor(address initialOwner) Ownable(initialOwner) {}

    // ============ External Functions ============

    /**
     * @inheritdoc IEASTrustedIssuersAdapter
     */
    function addTrustedAttester(address attester, uint256[] calldata claimTopics) external override onlyOwner {
        if (attester == address(0)) revert ZeroAddressNotAllowed();
        if (_isTrusted[attester]) revert AttesterAlreadyTrusted(attester);
        if (claimTopics.length == 0) revert EmptyClaimTopics();
        if (_trustedAttesters.length >= MAX_ATTESTERS) {
            revert("MaxAttestersReached");
        }
        if (claimTopics.length > MAX_TOPICS_PER_ATTESTER) {
            revert("MaxTopicsPerAttesterReached");
        }

        _isTrusted[attester] = true;
        _trustedAttesters.push(attester);
        _attesterClaimTopics[attester] = claimTopics;

        for (uint256 i = 0; i < claimTopics.length; i++) {
            uint256 topic = claimTopics[i];
            if (_claimTopicToAttesters[topic].length >= MAX_ATTESTERS_PER_TOPIC) {
                revert("MaxAttestersPerTopicReached");
            }
            _claimTopicToAttesters[topic].push(attester);
            _attesterTrustedForTopic[attester][topic] = true;
        }

        emit TrustedAttesterAdded(attester, claimTopics);
    }

    /**
     * @inheritdoc IEASTrustedIssuersAdapter
     */
    function removeTrustedAttester(address attester) external override onlyOwner {
        if (!_isTrusted[attester]) revert AttesterNotTrusted(attester);

        // Remove from topic mappings
        uint256[] memory topics = _attesterClaimTopics[attester];
        for (uint256 i = 0; i < topics.length; i++) {
            uint256 topic = topics[i];
            _removeAttesterFromTopic(attester, topic);
            _attesterTrustedForTopic[attester][topic] = false;
        }

        // Remove from attesters array
        _removeFromAttestersArray(attester);

        // Clear mappings
        delete _attesterClaimTopics[attester];
        _isTrusted[attester] = false;

        emit TrustedAttesterRemoved(attester);
    }

    /**
     * @inheritdoc IEASTrustedIssuersAdapter
     */
    function updateAttesterTopics(address attester, uint256[] calldata claimTopics) external override onlyOwner {
        if (!_isTrusted[attester]) revert AttesterNotTrusted(attester);
        if (claimTopics.length == 0) revert EmptyClaimTopics();
        if (claimTopics.length > MAX_TOPICS_PER_ATTESTER) {
            revert("MaxTopicsPerAttesterReached");
        }

        // Remove old topic associations
        uint256[] memory oldTopics = _attesterClaimTopics[attester];
        for (uint256 i = 0; i < oldTopics.length; i++) {
            uint256 topic = oldTopics[i];
            _removeAttesterFromTopic(attester, topic);
            _attesterTrustedForTopic[attester][topic] = false;
        }

        // Add new topic associations
        _attesterClaimTopics[attester] = claimTopics;
        for (uint256 i = 0; i < claimTopics.length; i++) {
            uint256 topic = claimTopics[i];
            if (_claimTopicToAttesters[topic].length >= MAX_ATTESTERS_PER_TOPIC) {
                revert("MaxAttestersPerTopicReached");
            }
            _claimTopicToAttesters[topic].push(attester);
            _attesterTrustedForTopic[attester][topic] = true;
        }

        emit AttesterTopicsUpdated(attester, claimTopics);
    }

    // ============ View Functions ============

    /**
     * @inheritdoc IEASTrustedIssuersAdapter
     */
    function isAttesterTrusted(address attester, uint256 claimTopic) external view override returns (bool) {
        return _attesterTrustedForTopic[attester][claimTopic];
    }

    /**
     * @inheritdoc IEASTrustedIssuersAdapter
     */
    function getTrustedAttestersForTopic(uint256 claimTopic) external view override returns (address[] memory) {
        return _claimTopicToAttesters[claimTopic];
    }

    /**
     * @inheritdoc IEASTrustedIssuersAdapter
     */
    function getAttesterTopics(address attester) external view override returns (uint256[] memory) {
        return _attesterClaimTopics[attester];
    }

    /**
     * @inheritdoc IEASTrustedIssuersAdapter
     */
    function getTrustedAttesters() external view override returns (address[] memory) {
        return _trustedAttesters;
    }

    /**
     * @inheritdoc IEASTrustedIssuersAdapter
     */
    function isTrustedAttester(address attester) external view override returns (bool) {
        return _isTrusted[attester];
    }

    // ============ Internal Functions ============

    /**
     * @notice Removes an attester from a topic's attester array
     * @param attester The attester address to remove
     * @param topic The topic to remove the attester from
     */
    function _removeAttesterFromTopic(address attester, uint256 topic) internal {
        address[] storage attesters = _claimTopicToAttesters[topic];
        uint256 length = attesters.length;

        for (uint256 i = 0; i < length; i++) {
            if (attesters[i] == attester) {
                attesters[i] = attesters[length - 1];
                attesters.pop();
                break;
            }
        }
    }

    /**
     * @notice Removes an attester from the trusted attesters array
     * @param attester The attester address to remove
     */
    function _removeFromAttestersArray(address attester) internal {
        uint256 length = _trustedAttesters.length;

        for (uint256 i = 0; i < length; i++) {
            if (_trustedAttesters[i] == attester) {
                _trustedAttesters[i] = _trustedAttesters[length - 1];
                _trustedAttesters.pop();
                break;
            }
        }
    }
}
