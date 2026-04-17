// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Attestation} from "@eas/Common.sol";
import {TopicPolicyBase} from "./TopicPolicyBase.sol";

/**
 * @title KYCStatusPolicy
 * @author EEA Working Group
 * @notice ERC-3643 Topic 1 (KYC) payload policy.
 * @dev Passes only when `kycStatus == KYC_VERIFIED (1)` and the data-level
 *      expiration has not passed. Other status values (NOT_VERIFIED, EXPIRED,
 *      REVOKED, PENDING) are rejected.
 */
contract KYCStatusPolicy is TopicPolicyBase {
    uint256 internal constant TOPIC_KYC = 1;

    constructor() TopicPolicyBase(TOPIC_KYC, "KYCStatusPolicy") {}

    function validate(Attestation calldata attestation) external view override returns (bool) {
        (bool ok, InvestorEligibility memory e) = _preflight(attestation.data);
        if (!ok) return false;
        return e.kycStatus == KYC_VERIFIED;
    }
}
