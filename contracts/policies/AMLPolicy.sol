// SPDX-License-Identifier: Apache-2.0
// Copyright © 2026 Enterprise Ethereum Alliance Inc.
pragma solidity ^0.8.24;

import {Attestation} from "@eas/Common.sol";
import {TopicPolicyBase} from "./TopicPolicyBase.sol";

/**
 * @title AMLPolicy
 * @author EEA Working Group
 * @notice ERC-3643 Topic 2 (AML) payload policy.
 * @dev Passes only when `amlStatus == AML_CLEAR (0)`. Any non-zero value is
 *      treated as a flag (hit, under review, etc.) and rejected.
 */
contract AMLPolicy is TopicPolicyBase {
    uint256 internal constant TOPIC_AML = 2;

    constructor() TopicPolicyBase(TOPIC_AML, "AMLPolicy") {}

    function validate(Attestation calldata attestation) external view override returns (bool) {
        (bool ok, InvestorEligibility memory e) = _preflight(attestation.data);
        if (!ok) return false;
        return e.amlStatus == AML_CLEAR;
    }
}
