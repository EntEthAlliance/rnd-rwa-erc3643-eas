// SPDX-License-Identifier: Apache-2.0
// Copyright © 2026 Enterprise Ethereum Alliance Inc.
pragma solidity ^0.8.24;

import {Attestation} from "@eas/Common.sol";
import {TopicPolicyBase} from "./TopicPolicyBase.sol";

/**
 * @title InstitutionalInvestorPolicy
 * @author EEA Working Group
 * @notice ERC-3643 Topic 10 (INSTITUTIONAL) payload policy.
 * @dev Passes only when `accreditationType == ACCREDITATION_INSTITUTIONAL (4)`.
 */
contract InstitutionalInvestorPolicy is TopicPolicyBase {
    uint256 internal constant TOPIC_INSTITUTIONAL = 10;

    constructor() TopicPolicyBase(TOPIC_INSTITUTIONAL, "InstitutionalInvestorPolicy") {}

    function validate(Attestation calldata attestation) external view override returns (bool) {
        (bool ok, InvestorEligibility memory e) = _preflight(attestation.data);
        if (!ok) return false;
        return e.accreditationType == ACCREDITATION_INSTITUTIONAL;
    }
}
