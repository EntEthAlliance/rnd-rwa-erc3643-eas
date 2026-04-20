// SPDX-License-Identifier: Apache-2.0
// Copyright © 2026 Enterprise Ethereum Alliance Inc.
pragma solidity =0.8.24;

import {IIdentity, IERC735, IERC734} from "../interfaces/IIdentity.sol";
import {IEASClaimVerifier} from "../interfaces/IEASClaimVerifier.sol";
import {IEASTrustedIssuersAdapter} from "../interfaces/IEASTrustedIssuersAdapter.sol";
import {IEAS, Attestation} from "@eas/IEAS.sol";

/**
 * @title EASClaimVerifierIdentityWrapper
 * @author EEA Working Group
 * @notice Path B — **Read-compatibility shim** exposing EAS attestations behind
 *         the IIdentity / ERC-735 / ERC-734 interface surface.
 *
 * @dev **This is NOT a drop-in replacement for ONCHAINID.** Audit finding C-4
 *      flagged that earlier documentation presented this contract as such, which
 *      is misleading. It is a minimal shim intended for the narrow case of an
 *      existing ERC-3643 deployment whose `IdentityRegistryStorage` cannot be
 *      modified to call the new payload-aware verifier directly. New
 *      deployments should use Path A (`EASClaimVerifier` called from a modified
 *      Identity Registry) and skip this wrapper entirely.
 *
 *      **What this wrapper DOES:**
 *        - Translates `getClaim(claimId)` lookups into EAS attestation reads
 *          via `EASClaimVerifier.getRegisteredAttestation(...)`.
 *        - Reports claim IDs by topic.
 *        - Provides a minimal `isClaimValid()` that verifies attestation
 *          existence, revocation status, and EAS-level expiration.
 *
 *      **What this wrapper DOES NOT do — and why each matters:**
 *        - **Does not run topic policies.** `isClaimValid()` does NOT check
 *          payload semantics (kycStatus, accreditationType, country, etc.).
 *          Downstream consumers that rely on it for Reg D / Reg S / MiFID
 *          gating will make incorrect decisions. Call
 *          `EASClaimVerifier.isVerified()` for policy-aware checks.
 *        - **Does not implement ERC-734 key management.** `addKey`,
 *          `removeKey`, `approve`, `execute` all revert. ONCHAINID-style
 *          recovery flows (rotation, management keys) are unavailable.
 *        - **Does not return real ECDSA signatures from `getClaim`.** The
 *          returned `signature` field is empty bytes; EAS does not expose
 *          the attester signature post-creation. ERC-3643 consumers that
 *          re-verify claim signatures out-of-band will fail.
 *        - **Gas profile is not suitable for hot paths.** `getClaim`
 *          brute-forces the (attester × topic) space via nested loops
 *          bounded by `MAX_ATTESTERS` × `MAX_TOPICS_PER_ATTESTER` — up to
 *          50 × 15 = 750 combinations, each invoking an EAS read. Deploy a
 *          per-identity wrapper + cache if you must use Path B, and profile
 *          before production.
 *        - **Does not handle wallet recovery.** The `identityAddress` is
 *          immutable at construction; losing the key means losing the
 *          identity. Use the token contract's `recoveryAddress` flow on
 *          the ERC-3643 side.
 *
 *      See `docs/integration-guide.md` § "Path B caveats" for the integration
 *      matrix and guidance on when to use this shim.
 */
contract EASClaimVerifierIdentityWrapper is IIdentity {
    // ============ Storage ============

    /// @notice The identity address (recipient of attestations)
    address public immutable identityAddress;

    /// @notice The EAS contract
    IEAS public immutable eas;

    /// @notice The EAS claim verifier
    IEASClaimVerifier public immutable claimVerifier;

    /// @notice The trusted issuers adapter
    IEASTrustedIssuersAdapter public immutable trustedIssuersAdapter;

    // ============ Constructor ============

    /**
     * @notice Initializes the wrapper for a specific identity
     * @param _identityAddress The identity address (attestation recipient)
     * @param _eas The EAS contract address
     * @param _claimVerifier The EASClaimVerifier address
     * @param _trustedIssuersAdapter The trusted issuers adapter address
     */
    constructor(address _identityAddress, address _eas, address _claimVerifier, address _trustedIssuersAdapter) {
        identityAddress = _identityAddress;
        eas = IEAS(_eas);
        claimVerifier = IEASClaimVerifier(_claimVerifier);
        trustedIssuersAdapter = IEASTrustedIssuersAdapter(_trustedIssuersAdapter);
    }

    // ============ ERC-735 Claim Functions ============

    /**
     * @notice Gets a claim by its ID (translated from EAS attestation)
     * @dev The claim ID in ERC-3643 is: keccak256(abi.encode(issuer, topic))
     *      This function reverses that to find the matching EAS attestation
     * @param _claimId The claim ID to look up
     * @return topic The claim topic
     * @return scheme The signature scheme (always 1 for EAS - ECDSA equivalent)
     * @return issuer The issuer address (attester)
     * @return signature Empty bytes (EAS handles signatures internally)
     * @return data The claim data (decoded from attestation)
     * @return uri Empty string (not used in EAS)
     */
    function getClaim(bytes32 _claimId)
        external
        view
        override
        returns (
            uint256 topic,
            uint256 scheme,
            address issuer,
            bytes memory signature,
            bytes memory data,
            string memory uri
        )
    {
        // Try to find matching attestation by iterating through trusted attesters
        // This is not ideal but necessary due to the claim ID encoding in ERC-3643

        // Get all trusted attesters
        address[] memory attesters = trustedIssuersAdapter.getTrustedAttesters();

        for (uint256 i = 0; i < attesters.length; i++) {
            uint256[] memory topics = trustedIssuersAdapter.getAttesterTopics(attesters[i]);

            for (uint256 j = 0; j < topics.length; j++) {
                // Check if this (attester, topic) combination matches the claim ID
                bytes32 expectedClaimId = keccak256(abi.encode(attesters[i], topics[j]));

                if (expectedClaimId == _claimId) {
                    // Found the matching attester and topic
                    // Look up the registered attestation
                    bytes32 attestationUID =
                        claimVerifier.getRegisteredAttestation(identityAddress, topics[j], attesters[i]);

                    if (attestationUID != bytes32(0)) {
                        Attestation memory att = eas.getAttestation(attestationUID);

                        if (att.uid != bytes32(0)) {
                            return (
                                topics[j], // topic
                                1, // scheme (ECDSA-equivalent)
                                attesters[i], // issuer
                                "", // signature (handled by EAS)
                                att.data, // data
                                "" // uri
                            );
                        }
                    }
                }
            }
        }

        // Claim not found - return empty
        return (0, 0, address(0), "", "", "");
    }

    /**
     * @notice Returns claim IDs by topic
     * @dev Returns all attestation-based claim IDs for a given topic
     * @param _topic The claim topic
     * @return claimIds Array of claim IDs
     */
    function getClaimIdsByTopic(uint256 _topic) external view override returns (bytes32[] memory claimIds) {
        address[] memory attesters = trustedIssuersAdapter.getTrustedAttestersForTopic(_topic);
        uint256 count = 0;

        // First pass: count valid attestations
        for (uint256 i = 0; i < attesters.length; i++) {
            bytes32 attestationUID = claimVerifier.getRegisteredAttestation(identityAddress, _topic, attesters[i]);
            if (attestationUID != bytes32(0)) {
                Attestation memory att = eas.getAttestation(attestationUID);
                if (att.uid != bytes32(0)) {
                    count++;
                }
            }
        }

        // Second pass: build array
        claimIds = new bytes32[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < attesters.length; i++) {
            bytes32 attestationUID = claimVerifier.getRegisteredAttestation(identityAddress, _topic, attesters[i]);
            if (attestationUID != bytes32(0)) {
                Attestation memory att = eas.getAttestation(attestationUID);
                if (att.uid != bytes32(0)) {
                    claimIds[index] = keccak256(abi.encode(attesters[i], _topic));
                    index++;
                }
            }
        }

        return claimIds;
    }

    /**
     * @notice Validates a claim (checks EAS attestation validity)
     * @dev The sig and data parameters are unused since EAS handles validation internally
     * @param _identity The identity to validate against
     * @param claimTopic The claim topic
     * @return True if the claim is valid
     */
    function isClaimValid(IIdentity _identity, uint256 claimTopic, bytes calldata, bytes calldata)
        external
        view
        override
        returns (bool)
    {
        // Get trusted attesters for this topic
        address[] memory attesters = trustedIssuersAdapter.getTrustedAttestersForTopic(claimTopic);

        for (uint256 i = 0; i < attesters.length; i++) {
            bytes32 attestationUID = claimVerifier.getRegisteredAttestation(
                address(_identity) == address(this) ? identityAddress : address(_identity), claimTopic, attesters[i]
            );

            if (attestationUID != bytes32(0)) {
                Attestation memory att = eas.getAttestation(attestationUID);

                // Check validity
                if (
                    att.uid != bytes32(0) && att.revocationTime == 0
                        && (att.expirationTime == 0 || att.expirationTime > block.timestamp)
                ) {
                    return true;
                }
            }
        }

        return false;
    }

    // ============ ERC-735 Mutation Functions (Not Supported) ============

    /**
     * @notice Add claim - NOT SUPPORTED (attestations created via EAS)
     * @dev Reverts because claims should be created via EAS attestations
     */
    function addClaim(uint256, uint256, address, bytes calldata, bytes calldata, string calldata)
        external
        pure
        override
        returns (bytes32)
    {
        revert("Use EAS to create attestations");
    }

    /**
     * @notice Remove claim - NOT SUPPORTED (revocation via EAS)
     * @dev Reverts because claims should be revoked via EAS
     */
    function removeClaim(bytes32) external pure override returns (bool) {
        revert("Use EAS to revoke attestations");
    }

    // ============ ERC-734 Key Functions (Minimal Implementation) ============

    /**
     * @notice Get key - returns identity address as management key
     * @dev Minimal implementation for compatibility
     */
    function getKey(bytes32 _key)
        external
        view
        override
        returns (uint256[] memory purposes, uint256 keyType, bytes32 key)
    {
        if (_key == keccak256(abi.encode(identityAddress))) {
            purposes = new uint256[](1);
            purposes[0] = 1; // MANAGEMENT
            return (purposes, 1, _key);
        }
        return (new uint256[](0), 0, bytes32(0));
    }

    /**
     * @notice Check if key has purpose
     */
    function keyHasPurpose(bytes32 _key, uint256 _purpose) external view override returns (bool) {
        return _key == keccak256(abi.encode(identityAddress)) && _purpose == 1;
    }

    /**
     * @notice Get keys by purpose - minimal implementation
     */
    function getKeysByPurpose(uint256 _purpose) external view override returns (bytes32[] memory keys) {
        if (_purpose == 1) {
            keys = new bytes32[](1);
            keys[0] = keccak256(abi.encode(identityAddress));
            return keys;
        }
        return new bytes32[](0);
    }

    // ============ ERC-734 Mutation Functions (Not Supported) ============

    function addKey(bytes32, uint256, uint256) external pure override returns (bool) {
        revert("Key management not supported");
    }

    function removeKey(bytes32, uint256) external pure override returns (bool) {
        revert("Key management not supported");
    }

    function approve(uint256, bool) external pure override returns (bool) {
        revert("Execution not supported");
    }

    function execute(address, uint256, bytes calldata) external pure override returns (uint256) {
        revert("Execution not supported");
    }
}
