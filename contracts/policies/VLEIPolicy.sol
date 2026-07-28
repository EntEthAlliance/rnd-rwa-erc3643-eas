// SPDX-License-Identifier: Apache-2.0
// Copyright © 2026 Enterprise Ethereum Alliance Inc.
pragma solidity =0.8.24;

import {Attestation} from "@eas/Common.sol";
import {ITopicPolicy} from "./ITopicPolicy.sol";

/**
 * @title VLEIPolicy
 * @author EEA Working Group
 * @notice ERC-3643 topic policy for vLEI (verifiable Legal Entity Identifier) credentials.
 * @dev Reads the vlei-to-eas schema, NOT the InvestorEligibility schema, so this contract
 *      intentionally does NOT extend TopicPolicyBase. It implements ITopicPolicy directly.
 *
 *      vlei-to-eas schema (ABI-encoded):
 *        string  lei             — GLEIF 20-char LEI code
 *        string  legalName       — legal entity name from GLEIF registry
 *        string  credType        — "LE" | "ECR" | "OOR"
 *        string  keriAid         — KERI AID of the credential holder
 *        bytes32 vleiSaid        — SAID of the vLEI credential (zero = not yet GLEIF-verified)
 *        uint64  verifiedAt      — unix timestamp when the bridge last confirmed validity
 *
 *      A policy instance is bound to one credential type (e.g. "LE") and one topic ID.
 *      Topic 15 (VLEI_LEGAL_ENTITY) accepts "LE" credentials.
 *      Topic 16 (VLEI_AUTHORIZED_ROLE) accepts "ECR" or "OOR" credentials.
 *
 *      Staleness check: `block.timestamp > verifiedAt + maxStaleness` → false.
 *      The vlei-to-eas background monitor refreshes attestations every 4 h (LE) / 4 h (ECR/OOR)
 *      so a maxStaleness of 6 h (21600 s) provides comfortable headroom.
 */
contract VLEIPolicy is ITopicPolicy {
    // ============ Immutable configuration ============

    uint256 private immutable _topicId;
    string private _expectedCredType;
    uint64 private immutable _maxStaleness;

    // ============ Constructor ============

    /**
     * @param topicId_          ERC-3643 claim topic this policy enforces (15 or 16).
     * @param expectedCredType_ The credential type string this policy accepts ("LE", "ECR", "OOR").
     * @param maxStaleness_     Maximum seconds since `verifiedAt` before the attestation is
     *                          considered stale. Recommended: 21600 (6 h).
     */
    constructor(uint256 topicId_, string memory expectedCredType_, uint64 maxStaleness_) {
        require(bytes(expectedCredType_).length > 0, "VLEIPolicy: empty credType");
        require(maxStaleness_ > 0, "VLEIPolicy: zero staleness");
        _topicId = topicId_;
        _expectedCredType = expectedCredType_;
        _maxStaleness = maxStaleness_;
    }

    // ============ ITopicPolicy ============

    /// @inheritdoc ITopicPolicy
    function topicId() external view override returns (uint256) {
        return _topicId;
    }

    /// @inheritdoc ITopicPolicy
    function name() external pure override returns (string memory) {
        return "VLEIPolicy";
    }

    /**
     * @notice Returns true only when the vLEI credential is valid, fresh, and of the
     *         expected credential type.
     * @dev Never reverts. Returns false on any malformed, stale, or mismatched payload.
     *
     *      Checks (in order):
     *        1. Non-empty data (guard before decode attempt).
     *        2. ABI-decode of the vlei-to-eas schema — catches corrupt/truncated data.
     *        3. vleiSaid != bytes32(0): GLEIF has confirmed the credential SAID.
     *        4. block.timestamp <= verifiedAt + maxStaleness: bridge confirmed recently.
     *        5. credType == expectedCredType: correct vLEI class for this topic.
     */
    function validate(Attestation calldata attestation) external view override returns (bool) {
        if (attestation.data.length == 0) return false;

        string memory lei;
        string memory legalName;
        string memory credType;
        string memory keriAid;
        bytes32 vleiSaid;
        uint64 verifiedAt;

        // abi.decode reverts on malformed input; wrap in a low-level call to catch that.
        // We encode the call to this contract's internal decode helper and staticcall it
        // so any revert is caught cleanly.
        (bool ok, bytes memory result) = address(this).staticcall(
            abi.encodeWithSelector(this._tryDecode.selector, attestation.data)
        );
        if (!ok || result.length == 0) return false;

        (lei, legalName, credType, keriAid, vleiSaid, verifiedAt) =
            abi.decode(result, (string, string, string, string, bytes32, uint64));

        // Silence unused variable warnings — lei/legalName/keriAid are decoded for
        // completeness but only credType, vleiSaid, and verifiedAt drive policy logic.
        lei; legalName; keriAid;

        // 1. Credential must have been verified by GLEIF (non-zero SAID).
        if (vleiSaid == bytes32(0)) return false;

        // 2. Attestation must not be stale.
        if (block.timestamp > uint256(verifiedAt) + uint256(_maxStaleness)) return false;

        // 3. Credential type must match this policy's expected type.
        if (keccak256(bytes(credType)) != keccak256(bytes(_expectedCredType))) return false;

        return true;
    }

    /**
     * @notice Decodes the vlei-to-eas attestation data.
     * @dev Exposed as external so that `validate()` can staticcall it to catch
     *      abi.decode reverts without bubbling them up. Must not be called directly
     *      for any security-sensitive purpose.
     */
    function _tryDecode(bytes calldata data)
        external
        pure
        returns (string memory lei, string memory legalName, string memory credType, string memory keriAid, bytes32 vleiSaid, uint64 verifiedAt)
    {
        (lei, legalName, credType, keriAid, vleiSaid, verifiedAt) =
            abi.decode(data, (string, string, string, string, bytes32, uint64));
    }
}
