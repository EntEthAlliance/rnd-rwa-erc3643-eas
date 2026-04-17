// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IEAS, AttestationRequest, AttestationRequestData} from "@eas/IEAS.sol";

/**
 * @title MockAttester
 * @author EEA Working Group
 * @notice Mock attester contract for testing EAS attestation flows.
 * @dev Simulates a KYC provider or compliance attestation service.
 *      Provides helpers for creating Schema v2 (Investor Eligibility) and Schema 2
 *      (Issuer Authorization) attestations.
 *
 *      Investor Eligibility v2 schema (Schema 1, ABI-encoded in order):
 *        address identity,
 *        uint8   kycStatus,
 *        uint8   amlStatus,
 *        uint8   sanctionsStatus,
 *        uint8   sourceOfFundsStatus,
 *        uint8   accreditationType,
 *        uint16  countryCode,
 *        uint64  expirationTimestamp,
 *        bytes32 evidenceHash,
 *        uint8   verificationMethod
 *
 *      Issuer Authorization schema (Schema 2, ABI-encoded in order):
 *        address issuerAddress,
 *        uint256[] authorizedTopics,
 *        string  issuerName
 */
contract MockAttester {
    IEAS public immutable eas;
    string public name;
    uint256 public attestationCount;

    event AttestationCreated(bytes32 indexed uid, address indexed recipient, bytes32 indexed schemaUID);

    constructor(address _eas, string memory _name) {
        eas = IEAS(_eas);
        name = _name;
    }

    // ============ Investor Eligibility (Schema v2) ============

    /**
     * @notice Creates an Investor Eligibility (Schema v2) attestation.
     */
    function attestInvestorEligibility(
        bytes32 schemaUID,
        address recipient,
        address identity,
        uint8 kycStatus,
        uint8 amlStatus,
        uint8 sanctionsStatus,
        uint8 sourceOfFundsStatus,
        uint8 accreditationType,
        uint16 countryCode,
        uint64 expirationTimestamp,
        bytes32 evidenceHash,
        uint8 verificationMethod
    ) external returns (bytes32 uid) {
        bytes memory data = abi.encode(
            identity,
            kycStatus,
            amlStatus,
            sanctionsStatus,
            sourceOfFundsStatus,
            accreditationType,
            countryCode,
            expirationTimestamp,
            evidenceHash,
            verificationMethod
        );

        AttestationRequest memory request = AttestationRequest({
            schema: schemaUID,
            data: AttestationRequestData({
                recipient: recipient, expirationTime: 0, revocable: true, refUID: bytes32(0), data: data, value: 0
            })
        });

        uid = eas.attest(request);
        attestationCount++;
        emit AttestationCreated(uid, recipient, schemaUID);
    }

    /**
     * @notice Encodes a Schema v2 payload. Helper for tests.
     */
    function encodeInvestorEligibility(
        address identity,
        uint8 kycStatus,
        uint8 amlStatus,
        uint8 sanctionsStatus,
        uint8 sourceOfFundsStatus,
        uint8 accreditationType,
        uint16 countryCode,
        uint64 expirationTimestamp,
        bytes32 evidenceHash,
        uint8 verificationMethod
    ) external pure returns (bytes memory) {
        return abi.encode(
            identity,
            kycStatus,
            amlStatus,
            sanctionsStatus,
            sourceOfFundsStatus,
            accreditationType,
            countryCode,
            expirationTimestamp,
            evidenceHash,
            verificationMethod
        );
    }

    /**
     * @notice Decodes a Schema v2 payload.
     */
    function decodeInvestorEligibility(bytes calldata data)
        external
        pure
        returns (
            address identity,
            uint8 kycStatus,
            uint8 amlStatus,
            uint8 sanctionsStatus,
            uint8 sourceOfFundsStatus,
            uint8 accreditationType,
            uint16 countryCode,
            uint64 expirationTimestamp,
            bytes32 evidenceHash,
            uint8 verificationMethod
        )
    {
        return abi.decode(data, (address, uint8, uint8, uint8, uint8, uint8, uint16, uint64, bytes32, uint8));
    }

    // ============ Issuer Authorization (Schema 2) ============

    /**
     * @notice Creates an Issuer Authorization (Schema 2) attestation that the
     *         `EASTrustedIssuersAdapter` uses as the `authUID` argument to
     *         `addTrustedAttester`.
     * @param schemaUID The Schema 2 UID.
     * @param issuerAddress The attester being authorized (also the `recipient`).
     * @param authorizedTopics The topics the attester is authorized for.
     * @param issuerName Human-readable name (appears in block explorers / audit logs).
     */
    function attestIssuerAuthorization(
        bytes32 schemaUID,
        address issuerAddress,
        uint256[] calldata authorizedTopics,
        string calldata issuerName
    ) external returns (bytes32 uid) {
        bytes memory data = abi.encode(issuerAddress, authorizedTopics, issuerName);

        AttestationRequest memory request = AttestationRequest({
            schema: schemaUID,
            data: AttestationRequestData({
                recipient: issuerAddress, expirationTime: 0, revocable: true, refUID: bytes32(0), data: data, value: 0
            })
        });

        uid = eas.attest(request);
        attestationCount++;
        emit AttestationCreated(uid, issuerAddress, schemaUID);
    }

    // ============ Misc ============

    function attestCustom(
        bytes32 schemaUID,
        address recipient,
        bytes calldata data,
        uint64 expirationTime,
        bool revocable
    ) external returns (bytes32 uid) {
        AttestationRequest memory request = AttestationRequest({
            schema: schemaUID,
            data: AttestationRequestData({
                recipient: recipient,
                expirationTime: expirationTime,
                revocable: revocable,
                refUID: bytes32(0),
                data: data,
                value: 0
            })
        });

        uid = eas.attest(request);
        attestationCount++;
        emit AttestationCreated(uid, recipient, schemaUID);
    }

    function attestWithReference(bytes32 schemaUID, address recipient, bytes calldata data, bytes32 refUID)
        external
        returns (bytes32 uid)
    {
        AttestationRequest memory request = AttestationRequest({
            schema: schemaUID,
            data: AttestationRequestData({
                recipient: recipient, expirationTime: 0, revocable: true, refUID: refUID, data: data, value: 0
            })
        });

        uid = eas.attest(request);
        attestationCount++;
        emit AttestationCreated(uid, recipient, schemaUID);
    }
}
