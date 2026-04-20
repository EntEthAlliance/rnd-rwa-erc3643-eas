// SPDX-License-Identifier: Apache-2.0
// Copyright © 2026 Enterprise Ethereum Alliance Inc.
pragma solidity =0.8.24;

import {Attestation} from "@eas/Common.sol";
import {TopicPolicyBase} from "./TopicPolicyBase.sol";

/**
 * @title SanctionsPolicy
 * @author EEA Working Group
 * @notice ERC-3643 Topic 13 (SANCTIONS_CHECK) payload policy.
 * @dev Passes only when `sanctionsStatus == SANCTIONS_CLEAR (0)`.
 */
contract SanctionsPolicy is TopicPolicyBase {
    uint256 internal constant TOPIC_SANCTIONS = 13;

    constructor() TopicPolicyBase(TOPIC_SANCTIONS, "SanctionsPolicy") {}

    function validate(Attestation calldata attestation) external view override returns (bool) {
        (bool ok, InvestorEligibility memory e) = _preflight(attestation.data);
        if (!ok) return false;
        return e.sanctionsStatus == SANCTIONS_CLEAR;
    }
}
