// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IEAS, Attestation} from "@eas/IEAS.sol";
import {IEASClaimVerifier} from "./interfaces/IEASClaimVerifier.sol";
import {IEASTrustedIssuersAdapter} from "./interfaces/IEASTrustedIssuersAdapter.sol";
import {IEASIdentityProxy} from "./interfaces/IEASIdentityProxy.sol";
import {IClaimTopicsRegistry} from "./interfaces/IClaimTopicsRegistry.sol";

/**
 * @title EASClaimVerifier
 * @author EEA Working Group
 * @notice Core adapter that enables ERC-3643 security tokens to accept EAS attestations
 * @dev This contract implements the verification logic that the Identity Registry calls
 *      to check if a wallet holder has valid EAS attestations matching required claim topics.
 *
 *      The verification flow:
 *      1. Resolve wallet address to identity address via EASIdentityProxy
 *      2. Fetch required claim topics from the linked ClaimTopicsRegistry
 *      3. For each required topic, get the mapped EAS schema UID
 *      4. Query registered attestations for (identity, schema, trustedAttester)
 *      5. Validate attestation: not revoked, not expired
 *      6. If all topics have valid attestations, return true
 *
 *      Integration Paths:
 *      - Path A (Pluggable Verifier): Deploy as a module called by a modified Identity Registry
 *      - Path B (Zero-Modification): Use EASClaimVerifierIdentityWrapper for IIdentity compatibility
 */
contract EASClaimVerifier is IEASClaimVerifier, Ownable {
    // ============ Storage ============

    /// @notice The EAS contract address
    IEAS private _eas;

    /// @notice The trusted issuers adapter contract
    IEASTrustedIssuersAdapter private _trustedIssuersAdapter;

    /// @notice The identity proxy contract for wallet-to-identity resolution
    IEASIdentityProxy private _identityProxy;

    /// @notice The claim topics registry contract
    IClaimTopicsRegistry private _claimTopicsRegistry;

    /// @notice Mapping from claim topic to EAS schema UID
    mapping(uint256 => bytes32) private _topicToSchema;

    /// @notice Active attestation UID per identity/topic (last valid registration wins)
    mapping(address => mapping(uint256 => bytes32)) private _activeAttestations;

    /// @notice Registered attestation UIDs: identity => topic => attester => attestationUID
    /// @dev Kept for backward-compatibility reads; active verification uses _activeAttestations.
    mapping(address => mapping(uint256 => mapping(address => bytes32))) private _registeredAttestations;

    // ============ Constructor ============

    /**
     * @notice Initializes the verifier with an owner
     * @param initialOwner The initial owner address
     */
    constructor(address initialOwner) Ownable(initialOwner) {}

    // ============ Configuration Functions ============

    /**
     * @inheritdoc IEASClaimVerifier
     */
    function setEASAddress(address easAddress) external override onlyOwner {
        if (easAddress == address(0)) revert ZeroAddressNotAllowed();
        _eas = IEAS(easAddress);
        emit EASAddressSet(easAddress);
    }

    /**
     * @inheritdoc IEASClaimVerifier
     */
    function setTrustedIssuersAdapter(address adapterAddress) external override onlyOwner {
        if (adapterAddress == address(0)) revert ZeroAddressNotAllowed();
        _trustedIssuersAdapter = IEASTrustedIssuersAdapter(adapterAddress);
        emit TrustedIssuersAdapterSet(adapterAddress);
    }

    /**
     * @inheritdoc IEASClaimVerifier
     */
    function setIdentityProxy(address proxyAddress) external override onlyOwner {
        // Identity proxy can be zero address (direct wallet attestations)
        _identityProxy = IEASIdentityProxy(proxyAddress);
        emit IdentityProxySet(proxyAddress);
    }

    /**
     * @inheritdoc IEASClaimVerifier
     */
    function setClaimTopicsRegistry(address registryAddress) external override onlyOwner {
        if (registryAddress == address(0)) revert ZeroAddressNotAllowed();
        _claimTopicsRegistry = IClaimTopicsRegistry(registryAddress);
        emit ClaimTopicsRegistrySet(registryAddress);
    }

    /**
     * @inheritdoc IEASClaimVerifier
     */
    function setTopicSchemaMapping(uint256 claimTopic, bytes32 schemaUID) external override onlyOwner {
        _topicToSchema[claimTopic] = schemaUID;
        emit TopicSchemaMappingSet(claimTopic, schemaUID);
    }

    // ============ View Functions ============

    /**
     * @inheritdoc IEASClaimVerifier
     */
    function getEASAddress() external view override returns (address) {
        return address(_eas);
    }

    /**
     * @inheritdoc IEASClaimVerifier
     */
    function getTrustedIssuersAdapter() external view override returns (address) {
        return address(_trustedIssuersAdapter);
    }

    /**
     * @inheritdoc IEASClaimVerifier
     */
    function getIdentityProxy() external view override returns (address) {
        return address(_identityProxy);
    }

    /**
     * @inheritdoc IEASClaimVerifier
     */
    function getClaimTopicsRegistry() external view override returns (address) {
        return address(_claimTopicsRegistry);
    }

    /**
     * @inheritdoc IEASClaimVerifier
     */
    function getSchemaUID(uint256 claimTopic) external view override returns (bytes32) {
        return _topicToSchema[claimTopic];
    }

    // ============ Attestation Registration ============

    /**
     * @notice Registers an attestation UID for efficient lookup during verification
     * @dev Caller must be the attester, the identity, or an authorized identity-proxy agent.
     *      The function validates that the attestation exists, matches the expected schema,
     *      and is from a trusted attester.
     * @param identity The identity address the attestation is for
     * @param claimTopic The claim topic this attestation covers
     * @param attestationUID The EAS attestation UID
     */
    function registerAttestation(address identity, uint256 claimTopic, bytes32 attestationUID) external {
        if (address(_eas) == address(0)) revert EASNotConfigured();
        if (address(_trustedIssuersAdapter) == address(0)) revert TrustedIssuersAdapterNotConfigured();

        bytes32 schemaUID = _topicToSchema[claimTopic];
        if (schemaUID == bytes32(0)) revert SchemaNotMappedForTopic(claimTopic);

        // Fetch attestation from EAS
        Attestation memory attestation = _eas.getAttestation(attestationUID);

        // Validate attestation
        require(attestation.uid != bytes32(0), "Attestation not found");
        require(attestation.schema == schemaUID, "Schema mismatch");
        require(attestation.recipient == identity, "Recipient mismatch");
        require(_trustedIssuersAdapter.isAttesterTrusted(attestation.attester, claimTopic), "Attester not trusted");

        // Authorization gate: attester, identity itself, or authorized identity-proxy agent
        bool callerIsAttester = attestation.attester == msg.sender;
        bool callerIsIdentity = msg.sender == identity;
        bool callerIsAuthorizedAgent = address(_identityProxy) != address(0) && _identityProxy.isAgent(msg.sender);
        require(callerIsAttester || callerIsIdentity || callerIsAuthorizedAgent, "Caller not authorized");

        // Register the attestation (single active UID per topic)
        _activeAttestations[identity][claimTopic] = attestationUID;
        _registeredAttestations[identity][claimTopic][attestation.attester] = attestationUID;

        emit AttestationRegistered(identity, claimTopic, attestation.attester, attestationUID);
    }

    /**
     * @notice Gets a registered attestation UID
     * @param identity The identity address
     * @param claimTopic The claim topic
     * @param attester The attester address
     * @return The registered attestation UID (bytes32(0) if not registered)
     */
    function getRegisteredAttestation(address identity, uint256 claimTopic, address attester)
        external
        view
        returns (bytes32)
    {
        bytes32 activeUid = _activeAttestations[identity][claimTopic];
        if (activeUid == bytes32(0)) {
            return bytes32(0);
        }

        Attestation memory activeAttestation = _eas.getAttestation(activeUid);
        if (activeAttestation.attester != attester) {
            return bytes32(0);
        }

        return activeUid;
    }

    // ============ Verification ============

    /**
     * @inheritdoc IEASClaimVerifier
     * @dev Main verification function implementing the EAS attestation check flow:
     *      1. Resolve wallet to identity via proxy (or use wallet directly)
     *      2. Get required claim topics from registry
     *      3. For each topic, check for valid attestation from trusted attester
     *      4. Return true only if all topics are satisfied
     */
    function isVerified(address userAddress) external view override returns (bool) {
        // Check required configuration
        if (address(_eas) == address(0)) revert EASNotConfigured();
        if (address(_trustedIssuersAdapter) == address(0)) revert TrustedIssuersAdapterNotConfigured();
        if (address(_claimTopicsRegistry) == address(0)) revert ClaimTopicsRegistryNotConfigured();

        // Step 1: Resolve wallet to identity
        address identity = _resolveIdentity(userAddress);

        // Step 2: Get required claim topics
        uint256[] memory requiredTopics = _claimTopicsRegistry.getClaimTopics();

        // If no topics required, verification passes
        if (requiredTopics.length == 0) {
            return true;
        }

        // Step 3-6: Verify each required topic
        for (uint256 i = 0; i < requiredTopics.length; i++) {
            if (!_verifyTopic(identity, requiredTopics[i])) {
                return false;
            }
        }

        return true;
    }

    // ============ Internal Functions ============

    /**
     * @notice Resolves a wallet address to its identity address
     * @param wallet The wallet address
     * @return The identity address (wallet itself if no proxy or no mapping)
     */
    function _resolveIdentity(address wallet) internal view returns (address) {
        if (address(_identityProxy) == address(0)) {
            return wallet;
        }
        return _identityProxy.getIdentity(wallet);
    }

    /**
     * @notice Verifies that an identity has a valid attestation for a claim topic
     * @param identity The identity address
     * @param claimTopic The claim topic to verify
     * @return True if a valid attestation exists from a trusted attester
     */
    function _verifyTopic(address identity, uint256 claimTopic) internal view returns (bool) {
        // Get schema UID for this topic
        bytes32 schemaUID = _topicToSchema[claimTopic];
        if (schemaUID == bytes32(0)) {
            // No schema mapped for this topic - cannot verify
            return false;
        }

        // Single attestation lookup per topic (O(topics))
        bytes32 activeUid = _activeAttestations[identity][claimTopic];
        if (activeUid == bytes32(0)) {
            return false;
        }

        Attestation memory attestation = _eas.getAttestation(activeUid);
        if (attestation.uid == bytes32(0)) {
            return false;
        }
        if (attestation.attester == address(0)) {
            return false;
        }
        if (!_trustedIssuersAdapter.isAttesterTrusted(attestation.attester, claimTopic)) {
            return false;
        }

        return _isAttestationValid(activeUid, schemaUID);
    }

    /**
     * @notice Checks if an attestation is currently valid
     * @param attestationUID The attestation UID to check
     * @param expectedSchemaUID The expected schema UID
     * @return True if the attestation is valid (exists, correct schema, not revoked, not expired)
     */
    function _isAttestationValid(bytes32 attestationUID, bytes32 expectedSchemaUID) internal view returns (bool) {
        Attestation memory attestation = _eas.getAttestation(attestationUID);

        // Check attestation exists
        if (attestation.uid == bytes32(0)) {
            return false;
        }

        // Check schema matches
        if (attestation.schema != expectedSchemaUID) {
            return false;
        }

        // Check not revoked
        if (attestation.revocationTime != 0) {
            return false;
        }

        // Check EAS-level expiration
        if (attestation.expirationTime != 0 && attestation.expirationTime <= block.timestamp) {
            return false;
        }

        // Check data-level expiration (expirationTimestamp is last field in our schema)
        // Schema: address identity, uint8 kycStatus, uint8 accreditationType, uint16 countryCode, uint64 expirationTimestamp
        // abi.encode packs each value to 32 bytes: 32 + 32 + 32 + 32 + 32 = 160 bytes
        if (attestation.data.length >= 160) {
            (,,,, uint64 expirationTimestamp) = abi.decode(attestation.data, (address, uint8, uint8, uint16, uint64));

            if (expirationTimestamp != 0 && expirationTimestamp <= block.timestamp) {
                return false;
            }
        }

        return true;
    }

    // ============ Events for Attestation Registration ============

    /**
     * @notice Emitted when an attestation UID is registered for a user
     * @param identity The identity address
     * @param claimTopic The claim topic
     * @param attester The attester address
     * @param attestationUID The registered attestation UID
     */
    event AttestationRegistered(
        address indexed identity, uint256 indexed claimTopic, address indexed attester, bytes32 attestationUID
    );
}
