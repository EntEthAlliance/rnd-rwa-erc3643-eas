// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IEAS, Attestation} from "@eas/IEAS.sol";
import {IIdentity, IERC735, IERC734} from "../../interfaces/IIdentity.sol";
import {RegistryOrbital} from "./RegistryOrbital.sol";
import {TrustedAttestersOrbital} from "./TrustedAttestersOrbital.sol";
import {VerificationOrbital} from "./VerificationOrbital.sol";

/**
 * @title CompatibilityWrapperOrbital
 * @author EEA Working Group
 * @notice Valence-native orbital implementing IIdentity for zero-modification Path B integration
 * @dev This orbital provides IIdentity (ERC-735 + ERC-734) compatibility for the Valence path,
 *      allowing the standard ERC-3643 Identity Registry to use Valence-based verification
 *      without any modifications to the registry contract.
 *
 *      Key differences from the legacy EASClaimVerifierIdentityWrapper:
 *      - Uses Valence orbitals (RegistryOrbital, TrustedAttestersOrbital) for state
 *      - Can be routed through a Valence kernel
 *      - Maintains parity with the legacy wrapper behavior
 *
 *      The wrapper is deployed per-identity (or via factory pattern).
 */
contract CompatibilityWrapperOrbital is IIdentity, Ownable {
    // ============ Module Metadata ============

    string public constant ORBITAL_ID = "compatibility-wrapper";
    string public constant ORBITAL_VERSION = "0.1.0-phase2";
    bytes32 public constant STORAGE_SLOT = keccak256("eea.valence.orbital.compatibility-wrapper.storage.v1");

    struct ModuleMetadata {
        string id;
        string version;
        bytes32 storageSlot;
    }

    // ============ Storage ============

    /// @notice The identity address (recipient of attestations)
    address public immutable identityAddress;

    /// @notice The EAS contract
    IEAS public immutable eas;

    /// @notice The Valence registry orbital for attestation data
    RegistryOrbital public immutable registryOrbital;

    /// @notice The Valence trusted attesters orbital
    TrustedAttestersOrbital public immutable trustedAttestersOrbital;

    /// @notice The Valence verification orbital (for isClaimValid delegation)
    VerificationOrbital public immutable verificationOrbital;

    // ============ Events ============

    event WrapperInitialized(address indexed identity, address eas, address registry, address trustedAttesters);

    // ============ Constructor ============

    /**
     * @notice Initializes the compatibility wrapper for a specific identity
     * @param initialOwner The owner address
     * @param _identityAddress The identity address (attestation recipient)
     * @param _eas The EAS contract address
     * @param _registryOrbital The Valence registry orbital address
     * @param _trustedAttestersOrbital The Valence trusted attesters orbital address
     * @param _verificationOrbital The Valence verification orbital address
     */
    constructor(
        address initialOwner,
        address _identityAddress,
        address _eas,
        address _registryOrbital,
        address _trustedAttestersOrbital,
        address _verificationOrbital
    ) Ownable(initialOwner) {
        require(_identityAddress != address(0), "identity=0");
        require(_eas != address(0), "eas=0");
        require(_registryOrbital != address(0), "registry=0");
        require(_trustedAttestersOrbital != address(0), "trustedAttesters=0");
        require(_verificationOrbital != address(0), "verification=0");

        identityAddress = _identityAddress;
        eas = IEAS(_eas);
        registryOrbital = RegistryOrbital(_registryOrbital);
        trustedAttestersOrbital = TrustedAttestersOrbital(_trustedAttestersOrbital);
        verificationOrbital = VerificationOrbital(_verificationOrbital);

        emit WrapperInitialized(_identityAddress, _eas, _registryOrbital, _trustedAttestersOrbital);
    }

    // ============ Module Metadata ============

    function moduleMetadata() external pure returns (ModuleMetadata memory) {
        return ModuleMetadata({id: ORBITAL_ID, version: ORBITAL_VERSION, storageSlot: STORAGE_SLOT});
    }

    function exportedSelectors() external pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](4);
        selectors[0] = this.getClaim.selector;
        selectors[1] = this.getClaimIdsByTopic.selector;
        selectors[2] = this.isClaimValid.selector;
        selectors[3] = this.getIdentityAddress.selector;
    }

    // ============ Helper Functions ============

    /**
     * @notice Returns the identity address this wrapper represents
     * @return The identity address
     */
    function getIdentityAddress() external view returns (address) {
        return identityAddress;
    }

    // ============ ERC-735 Claim Functions ============

    /**
     * @notice Gets a claim by its ID (translated from EAS attestation via Valence orbitals)
     * @dev The claim ID in ERC-3643 is: keccak256(abi.encode(issuer, topic))
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
        // Get all trusted attesters from the orbital
        // Since TrustedAttestersOrbital doesn't have getTrustedAttesters(), we iterate through known topics
        // This matches the behavior of the legacy wrapper

        // Get required topics from verification orbital to determine which topics to check
        uint256[] memory topics = verificationOrbital.getRequiredClaimTopics();

        for (uint256 i = 0; i < topics.length; i++) {
            address[] memory attesters = trustedAttestersOrbital.getTrustedAttestersForTopic(topics[i]);

            for (uint256 j = 0; j < attesters.length; j++) {
                // Check if this (attester, topic) combination matches the claim ID
                bytes32 expectedClaimId = keccak256(abi.encode(attesters[j], topics[i]));

                if (expectedClaimId == _claimId) {
                    // Found matching attester and topic - look up attestation via registry orbital
                    bytes32 attestationUID =
                        registryOrbital.getRegisteredAttestation(identityAddress, topics[i], attesters[j]);

                    if (attestationUID != bytes32(0)) {
                        Attestation memory att = eas.getAttestation(attestationUID);

                        if (att.uid != bytes32(0)) {
                            return (
                                topics[i], // topic
                                1, // scheme (ECDSA-equivalent)
                                attesters[j], // issuer
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
     * @notice Returns claim IDs by topic (using Valence orbitals)
     * @param _topic The claim topic
     * @return claimIds Array of claim IDs
     */
    function getClaimIdsByTopic(uint256 _topic) external view override returns (bytes32[] memory claimIds) {
        address[] memory attesters = trustedAttestersOrbital.getTrustedAttestersForTopic(_topic);
        uint256 count = 0;

        // First pass: count valid attestations
        for (uint256 i = 0; i < attesters.length; i++) {
            bytes32 attestationUID = registryOrbital.getRegisteredAttestation(identityAddress, _topic, attesters[i]);
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
            bytes32 attestationUID = registryOrbital.getRegisteredAttestation(identityAddress, _topic, attesters[i]);
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
     * @notice Validates a claim (checks EAS attestation validity via Valence verification orbital)
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
        // Determine the actual identity address to check
        address targetIdentity = address(_identity) == address(this) ? identityAddress : address(_identity);

        // Delegate to verification orbital's verifyTopic for consistent validation
        return verificationOrbital.verifyTopic(targetIdentity, claimTopic);
    }

    // ============ ERC-735 Mutation Functions (Not Supported) ============

    /**
     * @notice Add claim - NOT SUPPORTED (attestations created via EAS)
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
     */
    function removeClaim(bytes32) external pure override returns (bool) {
        revert("Use EAS to revoke attestations");
    }

    // ============ ERC-734 Key Functions (Minimal Implementation) ============

    /**
     * @notice Get key - returns identity address as management key
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
