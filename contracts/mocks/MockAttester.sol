// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IEAS, AttestationRequest, AttestationRequestData} from "@eas/IEAS.sol";

/**
 * @title MockAttester
 * @author EEA Working Group
 * @notice Mock attester contract for testing EAS attestation flows
 * @dev Simulates a KYC provider or compliance attestation service.
 *      Provides helpers for creating attestations with proper encoding.
 */
contract MockAttester {
    // ============ Storage ============

    /// @notice The EAS contract reference
    IEAS public immutable eas;

    /// @notice The attester's name
    string public name;

    /// @notice Counter for tracking attestations
    uint256 public attestationCount;

    // ============ Events ============

    /// @notice Emitted when an attestation is created
    event AttestationCreated(
        bytes32 indexed uid,
        address indexed recipient,
        bytes32 indexed schemaUID
    );

    // ============ Constructor ============

    /**
     * @notice Initializes the mock attester
     * @param _eas The EAS contract address
     * @param _name The attester's name
     */
    constructor(address _eas, string memory _name) {
        eas = IEAS(_eas);
        name = _name;
    }

    // ============ Attestation Functions ============

    /**
     * @notice Creates an investor eligibility attestation
     * @param schemaUID The schema UID
     * @param recipient The attestation recipient (identity address)
     * @param identity The identity address (encoded in data)
     * @param kycStatus The KYC status (0-4)
     * @param accreditationType The accreditation type (0-6)
     * @param countryCode The ISO 3166-1 country code
     * @param expirationTimestamp The expiration timestamp
     * @return uid The created attestation UID
     */
    function attestInvestorEligibility(
        bytes32 schemaUID,
        address recipient,
        address identity,
        uint8 kycStatus,
        uint8 accreditationType,
        uint16 countryCode,
        uint64 expirationTimestamp
    ) external returns (bytes32 uid) {
        bytes memory data = abi.encode(
            identity,
            kycStatus,
            accreditationType,
            countryCode,
            expirationTimestamp
        );

        AttestationRequest memory request = AttestationRequest({
            schema: schemaUID,
            data: AttestationRequestData({
                recipient: recipient,
                expirationTime: 0, // No EAS-level expiration, using data-level
                revocable: true,
                refUID: bytes32(0),
                data: data,
                value: 0
            })
        });

        uid = eas.attest(request);
        attestationCount++;

        emit AttestationCreated(uid, recipient, schemaUID);
        return uid;
    }

    /**
     * @notice Creates an attestation with custom data
     * @param schemaUID The schema UID
     * @param recipient The attestation recipient
     * @param data The encoded attestation data
     * @param expirationTime The EAS-level expiration time
     * @param revocable Whether the attestation is revocable
     * @return uid The created attestation UID
     */
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
        return uid;
    }

    /**
     * @notice Creates an attestation with a reference to another attestation
     * @param schemaUID The schema UID
     * @param recipient The attestation recipient
     * @param data The encoded attestation data
     * @param refUID The reference attestation UID
     * @return uid The created attestation UID
     */
    function attestWithReference(
        bytes32 schemaUID,
        address recipient,
        bytes calldata data,
        bytes32 refUID
    ) external returns (bytes32 uid) {
        AttestationRequest memory request = AttestationRequest({
            schema: schemaUID,
            data: AttestationRequestData({
                recipient: recipient,
                expirationTime: 0,
                revocable: true,
                refUID: refUID,
                data: data,
                value: 0
            })
        });

        uid = eas.attest(request);
        attestationCount++;

        emit AttestationCreated(uid, recipient, schemaUID);
        return uid;
    }

    // ============ Helper Functions ============

    /**
     * @notice Encodes investor eligibility data
     * @param identity The identity address
     * @param kycStatus The KYC status
     * @param accreditationType The accreditation type
     * @param countryCode The country code
     * @param expirationTimestamp The expiration timestamp
     * @return The encoded data
     */
    function encodeInvestorEligibility(
        address identity,
        uint8 kycStatus,
        uint8 accreditationType,
        uint16 countryCode,
        uint64 expirationTimestamp
    ) external pure returns (bytes memory) {
        return abi.encode(
            identity,
            kycStatus,
            accreditationType,
            countryCode,
            expirationTimestamp
        );
    }

    /**
     * @notice Decodes investor eligibility data
     * @param data The encoded data
     * @return identity The identity address
     * @return kycStatus The KYC status
     * @return accreditationType The accreditation type
     * @return countryCode The country code
     * @return expirationTimestamp The expiration timestamp
     */
    function decodeInvestorEligibility(
        bytes calldata data
    )
        external
        pure
        returns (
            address identity,
            uint8 kycStatus,
            uint8 accreditationType,
            uint16 countryCode,
            uint64 expirationTimestamp
        )
    {
        return abi.decode(data, (address, uint8, uint8, uint16, uint64));
    }
}
