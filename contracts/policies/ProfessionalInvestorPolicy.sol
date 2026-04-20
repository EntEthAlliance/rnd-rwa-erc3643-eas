// SPDX-License-Identifier: Apache-2.0
// Copyright © 2026 Enterprise Ethereum Alliance Inc.
pragma solidity ^0.8.24;

import {Attestation} from "@eas/Common.sol";
import {TopicPolicyBase} from "./TopicPolicyBase.sol";

/**
 * @title ProfessionalInvestorPolicy
 * @author EEA Working Group
 * @notice ERC-3643 Topic 9 (PROFESSIONAL) payload policy.
 * @dev Passes when `accreditationType` is any non-zero value, i.e. the investor is
 *      classified at or above RETAIL_QUALIFIED (1). Per MiFID II, retail-opted-up
 *      professionals count as professional investors; institutional investors do too.
 *      Stricter gating (e.g. "institutional only") should use
 *      `InstitutionalInvestorPolicy`.
 */
contract ProfessionalInvestorPolicy is TopicPolicyBase {
    uint256 internal constant TOPIC_PROFESSIONAL = 9;

    constructor() TopicPolicyBase(TOPIC_PROFESSIONAL, "ProfessionalInvestorPolicy") {}

    function validate(Attestation calldata attestation) external view override returns (bool) {
        (bool ok, InvestorEligibility memory e) = _preflight(attestation.data);
        if (!ok) return false;
        return e.accreditationType >= ACCREDITATION_RETAIL_QUALIFIED;
    }
}
