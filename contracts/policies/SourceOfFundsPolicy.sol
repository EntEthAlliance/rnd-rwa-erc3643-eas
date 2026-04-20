// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import {Attestation} from "@eas/Common.sol";
import {TopicPolicyBase} from "./TopicPolicyBase.sol";

/**
 * @title SourceOfFundsPolicy
 * @author EEA Working Group
 * @notice ERC-3643 Topic 14 (SOURCE_OF_FUNDS) payload policy.
 * @dev Passes only when `sourceOfFundsStatus == SOF_VERIFIED (1)`.
 */
contract SourceOfFundsPolicy is TopicPolicyBase {
    uint256 internal constant TOPIC_SOURCE_OF_FUNDS = 14;

    constructor() TopicPolicyBase(TOPIC_SOURCE_OF_FUNDS, "SourceOfFundsPolicy") {}

    function validate(Attestation calldata attestation) external view override returns (bool) {
        (bool ok, InvestorEligibility memory e) = _preflight(attestation.data);
        if (!ok) return false;
        return e.sourceOfFundsStatus == SOF_VERIFIED;
    }
}
