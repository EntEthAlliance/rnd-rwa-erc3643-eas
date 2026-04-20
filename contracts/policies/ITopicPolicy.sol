// SPDX-License-Identifier: Apache-2.0
// Copyright © 2026 Enterprise Ethereum Alliance Inc.
pragma solidity =0.8.24;

import {Attestation} from "@eas/Common.sol";

/**
 * @title ITopicPolicy
 * @author EEA Working Group
 * @notice Payload-aware predicate for a single ERC-3643 claim topic.
 * @dev Each policy module decodes the EAS attestation data for its topic and returns
 *      true only when the semantic content satisfies the topic's requirement — for
 *      example, kycStatus == VERIFIED for Topic 1, or countryCode is in an allow-list
 *      for Topic 3. This is the mechanism by which the verifier checks attestation
 *      *content*, not just attestation existence.
 *
 *      The verifier invokes `validate()` after it has already confirmed:
 *        - the attestation exists on EAS,
 *        - the schema matches the topic's configured schema,
 *        - the attestation is not revoked at the EAS level,
 *        - the EAS-level `expirationTime` has not passed,
 *        - the attester is trusted for this topic.
 *
 *      Policies therefore focus on the *payload* — decoding the `data` field and
 *      enforcing semantic rules — and must not duplicate the above checks.
 */
interface ITopicPolicy {
    /**
     * @notice Returns true if the attestation satisfies this topic's policy.
     * @dev MUST be a view function and MUST NOT revert on invalid payloads —
     *      return `false` instead, so the verifier can continue evaluating other
     *      trusted attesters for the same topic.
     * @param attestation The full EAS attestation (including `data`, `recipient`,
     *        `expirationTime`, etc.).
     * @return True if this attestation satisfies the topic's policy.
     */
    function validate(Attestation calldata attestation) external view returns (bool);

    /**
     * @notice Returns the ERC-3643 claim topic ID this policy is intended to enforce.
     * @dev Informational; the binding between topic and policy is configured in the
     *      verifier via `setTopicPolicy(topic, policyAddress)` and this value is not
     *      authoritative. Used for introspection, deployment scripts, and tooling.
     */
    function topicId() external view returns (uint256);

    /**
     * @notice Short, human-readable name of the policy (e.g. "KYCStatusPolicy").
     * @dev Informational; useful for block explorers and deployment manifests.
     */
    function name() external view returns (string memory);
}
