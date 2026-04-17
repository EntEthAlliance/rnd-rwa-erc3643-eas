// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Attestation} from "@eas/Common.sol";
import {ITopicPolicy} from "./ITopicPolicy.sol";

/**
 * @title TopicPolicyBase
 * @author EEA Working Group
 * @notice Abstract base for Shibui topic policies that read the Investor Eligibility v2 schema.
 * @dev Schema v2 fields (in ABI-encoded order):
 *        address identity,
 *        uint8  kycStatus,
 *        uint8  amlStatus,
 *        uint8  sanctionsStatus,
 *        uint8  sourceOfFundsStatus,
 *        uint8  accreditationType,
 *        uint16 countryCode,
 *        uint64 expirationTimestamp,
 *        bytes32 evidenceHash,
 *        uint8  verificationMethod
 *
 *      Each field is ABI-packed to 32 bytes, so the expected encoded length is
 *      10 * 32 = 320 bytes.
 *
 *      Concrete policies extend this base and implement `validate()` with a single
 *      predicate against the decoded payload. This base provides:
 *        - length-safe decoding,
 *        - a shared data-level expiration check,
 *        - canonical enum values (KYC_VERIFIED, AML_CLEAR, etc.) that individual
 *          policies can reuse so on-chain and off-chain tooling agree on constants.
 */
abstract contract TopicPolicyBase is ITopicPolicy {
    // ============ Canonical enum values ============

    /// @notice `kycStatus` value meaning "KYC verified and current".
    uint8 internal constant KYC_NOT_VERIFIED = 0;
    uint8 internal constant KYC_VERIFIED = 1;
    uint8 internal constant KYC_EXPIRED = 2;
    uint8 internal constant KYC_REVOKED = 3;
    uint8 internal constant KYC_PENDING = 4;

    /// @notice `amlStatus` value meaning "no adverse AML flag".
    uint8 internal constant AML_CLEAR = 0;
    uint8 internal constant AML_FLAGGED = 1;

    /// @notice `sanctionsStatus` value meaning "not on any applicable sanctions list".
    uint8 internal constant SANCTIONS_CLEAR = 0;
    uint8 internal constant SANCTIONS_HIT = 1;

    /// @notice `sourceOfFundsStatus` value meaning "source of funds verified".
    uint8 internal constant SOF_NOT_VERIFIED = 0;
    uint8 internal constant SOF_VERIFIED = 1;

    /// @notice `accreditationType` canonical values (match `docs/schemas/schema-definitions.md`).
    uint8 internal constant ACCREDITATION_NONE = 0;
    uint8 internal constant ACCREDITATION_RETAIL_QUALIFIED = 1;
    uint8 internal constant ACCREDITATION_ACCREDITED = 2;
    uint8 internal constant ACCREDITATION_QUALIFIED_PURCHASER = 3;
    uint8 internal constant ACCREDITATION_INSTITUTIONAL = 4;

    /// @notice Expected ABI-encoded length of Schema v2 payload (10 × 32).
    uint256 internal constant EXPECTED_DATA_LENGTH = 320;

    // ============ Decoded payload struct ============

    struct InvestorEligibility {
        address identity;
        uint8 kycStatus;
        uint8 amlStatus;
        uint8 sanctionsStatus;
        uint8 sourceOfFundsStatus;
        uint8 accreditationType;
        uint16 countryCode;
        uint64 expirationTimestamp;
        bytes32 evidenceHash;
        uint8 verificationMethod;
    }

    // ============ Immutable policy metadata ============

    uint256 private immutable _topicId;
    string private _name;

    constructor(uint256 topicId_, string memory name_) {
        _topicId = topicId_;
        _name = name_;
    }

    /// @inheritdoc ITopicPolicy
    function topicId() external view override returns (uint256) {
        return _topicId;
    }

    /// @inheritdoc ITopicPolicy
    function name() external view override returns (string memory) {
        return _name;
    }

    // ============ Internal helpers ============

    /**
     * @notice Returns true if `data` can be decoded as a Schema v2 payload.
     * @dev Length-safe: returns false rather than reverting on a short payload so
     *      that `validate()` can return false cleanly.
     */
    function _isDecodable(bytes calldata data) internal pure returns (bool) {
        return data.length >= EXPECTED_DATA_LENGTH;
    }

    /**
     * @notice Decodes a Schema v2 payload.
     * @dev Caller MUST confirm `_isDecodable(data)` first. Invalid input will revert.
     */
    function _decode(bytes calldata data) internal pure returns (InvestorEligibility memory e) {
        (
            e.identity,
            e.kycStatus,
            e.amlStatus,
            e.sanctionsStatus,
            e.sourceOfFundsStatus,
            e.accreditationType,
            e.countryCode,
            e.expirationTimestamp,
            e.evidenceHash,
            e.verificationMethod
        ) = abi.decode(
            data, (address, uint8, uint8, uint8, uint8, uint8, uint16, uint64, bytes32, uint8)
        );
    }

    /**
     * @notice Data-level freshness check.
     * @dev A payload is "fresh" when its `expirationTimestamp` is zero (never) or
     *      strictly in the future. The verifier also performs an EAS-level
     *      expiration check independently.
     */
    function _isPayloadFresh(InvestorEligibility memory e) internal view returns (bool) {
        return e.expirationTimestamp == 0 || e.expirationTimestamp > block.timestamp;
    }

    /**
     * @notice Common preflight: length check + decode + freshness.
     * @return ok True if the payload is decodable and fresh.
     * @return e  The decoded payload (zeroed if not decodable).
     */
    function _preflight(bytes calldata data) internal view returns (bool ok, InvestorEligibility memory e) {
        if (!_isDecodable(data)) return (false, e);
        e = _decode(data);
        if (!_isPayloadFresh(e)) return (false, e);
        return (true, e);
    }
}
