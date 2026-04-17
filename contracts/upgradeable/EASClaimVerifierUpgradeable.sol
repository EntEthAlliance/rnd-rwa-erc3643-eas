// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IEAS, Attestation} from "@eas/IEAS.sol";
import {IEASClaimVerifier} from "../interfaces/IEASClaimVerifier.sol";
import {IEASTrustedIssuersAdapter} from "../interfaces/IEASTrustedIssuersAdapter.sol";
import {IEASIdentityProxy} from "../interfaces/IEASIdentityProxy.sol";
import {IClaimTopicsRegistry} from "../interfaces/IClaimTopicsRegistry.sol";
import {ITopicPolicy} from "../policies/ITopicPolicy.sol";

/**
 * @title EASClaimVerifierUpgradeable
 * @author EEA Working Group
 * @notice UUPS-upgradeable version of EASClaimVerifier.
 * @dev Behavioural parity with `EASClaimVerifier` after audit fixes C-1, C-2,
 *      C-3, C-6 and R-6. Storage layout is a greenfield layout; no V1 production
 *      deployment exists so we are free to reorder. `__gap` is recomputed so the
 *      total slot budget remains constant for future upgrades.
 */
contract EASClaimVerifierUpgradeable is Initializable, AccessControlUpgradeable, UUPSUpgradeable, IEASClaimVerifier {
    // ============ Roles ============

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // ============ Storage ============

    IEAS private _eas;
    IEASTrustedIssuersAdapter private _trustedIssuersAdapter;
    IEASIdentityProxy private _identityProxy;
    IClaimTopicsRegistry private _claimTopicsRegistry;

    mapping(uint256 => bytes32) private _topicToSchema;
    mapping(uint256 => address) private _topicToPolicy;
    mapping(address => mapping(uint256 => mapping(address => bytes32))) private _registeredAttestations;

    /// @dev Reserved storage gap — reduced by 1 slot to account for `_topicToPolicy`.
    uint256[43] private __gap;

    // ============ Events (in addition to interface) ============

    event AttestationRegistered(
        address indexed identity, uint256 indexed claimTopic, address indexed attester, bytes32 attestationUID
    );

    // ============ Constructor / Initializer ============

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialAdmin) external initializer {
        if (initialAdmin == address(0)) revert ZeroAddressNotAllowed();
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
        _grantRole(OPERATOR_ROLE, initialAdmin);
    }

    function _authorizeUpgrade(
        address /*newImplementation*/
    )
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}

    // ============ Configuration ============

    function setEASAddress(address easAddress) external override onlyRole(OPERATOR_ROLE) {
        if (easAddress == address(0)) revert ZeroAddressNotAllowed();
        _eas = IEAS(easAddress);
        emit EASAddressSet(easAddress);
    }

    function setTrustedIssuersAdapter(address adapterAddress) external override onlyRole(OPERATOR_ROLE) {
        if (adapterAddress == address(0)) revert ZeroAddressNotAllowed();
        _trustedIssuersAdapter = IEASTrustedIssuersAdapter(adapterAddress);
        emit TrustedIssuersAdapterSet(adapterAddress);
    }

    function setIdentityProxy(address proxyAddress) external override onlyRole(OPERATOR_ROLE) {
        if (proxyAddress == address(0)) revert ZeroAddressNotAllowed();
        _identityProxy = IEASIdentityProxy(proxyAddress);
        emit IdentityProxySet(proxyAddress);
    }

    function setClaimTopicsRegistry(address registryAddress) external override onlyRole(OPERATOR_ROLE) {
        if (registryAddress == address(0)) revert ZeroAddressNotAllowed();
        _claimTopicsRegistry = IClaimTopicsRegistry(registryAddress);
        emit ClaimTopicsRegistrySet(registryAddress);
    }

    function setTopicSchemaMapping(uint256 claimTopic, bytes32 schemaUID) external override onlyRole(OPERATOR_ROLE) {
        _topicToSchema[claimTopic] = schemaUID;
        emit TopicSchemaMappingSet(claimTopic, schemaUID);
    }

    function setTopicPolicy(uint256 claimTopic, address policy) external override onlyRole(OPERATOR_ROLE) {
        _topicToPolicy[claimTopic] = policy;
        emit TopicPolicySet(claimTopic, policy);
    }

    // ============ Views ============

    function getEASAddress() external view override returns (address) {
        return address(_eas);
    }

    function getTrustedIssuersAdapter() external view override returns (address) {
        return address(_trustedIssuersAdapter);
    }

    function getIdentityProxy() external view override returns (address) {
        return address(_identityProxy);
    }

    function getClaimTopicsRegistry() external view override returns (address) {
        return address(_claimTopicsRegistry);
    }

    function getSchemaUID(uint256 claimTopic) external view override returns (bytes32) {
        return _topicToSchema[claimTopic];
    }

    function getTopicPolicy(uint256 claimTopic) external view override returns (address) {
        return _topicToPolicy[claimTopic];
    }

    // ============ Attestation Registration ============

    function registerAttestation(address identity, uint256 claimTopic, bytes32 attestationUID) external {
        if (address(_eas) == address(0)) revert EASNotConfigured();
        if (address(_trustedIssuersAdapter) == address(0)) revert TrustedIssuersAdapterNotConfigured();

        bytes32 schemaUID = _topicToSchema[claimTopic];
        if (schemaUID == bytes32(0)) revert SchemaNotMappedForTopic(claimTopic);

        Attestation memory attestation = _eas.getAttestation(attestationUID);
        require(attestation.uid != bytes32(0), "Attestation not found");
        require(attestation.schema == schemaUID, "Schema mismatch");
        require(attestation.recipient == identity, "Recipient mismatch");
        require(_trustedIssuersAdapter.isAttesterTrusted(attestation.attester, claimTopic), "Attester not trusted");

        // Audit finding C-3: identity-self registration is no longer authorized.
        bool callerIsAttester = attestation.attester == msg.sender;
        bool callerIsAuthorizedAgent = address(_identityProxy) != address(0) && _identityProxy.isAgent(msg.sender);
        require(callerIsAttester || callerIsAuthorizedAgent, "Caller not authorized");

        _registeredAttestations[identity][claimTopic][attestation.attester] = attestationUID;

        emit AttestationRegistered(identity, claimTopic, attestation.attester, attestationUID);
    }

    function getRegisteredAttestation(address identity, uint256 claimTopic, address attester)
        external
        view
        override
        returns (bytes32)
    {
        return _registeredAttestations[identity][claimTopic][attester];
    }

    // ============ Verification ============

    function isVerified(address userAddress) external view override returns (bool) {
        if (address(_eas) == address(0)) revert EASNotConfigured();
        if (address(_trustedIssuersAdapter) == address(0)) revert TrustedIssuersAdapterNotConfigured();
        if (address(_claimTopicsRegistry) == address(0)) revert ClaimTopicsRegistryNotConfigured();
        if (address(_identityProxy) == address(0)) revert IdentityProxyNotConfigured();

        address identity = _identityProxy.getIdentity(userAddress);

        uint256[] memory requiredTopics = _claimTopicsRegistry.getClaimTopics();
        if (requiredTopics.length == 0) return true;

        for (uint256 i = 0; i < requiredTopics.length; i++) {
            if (!_verifyTopic(identity, requiredTopics[i])) return false;
        }
        return true;
    }

    // ============ Internal ============

    function _verifyTopic(address identity, uint256 claimTopic) internal view returns (bool) {
        address policyAddr = _topicToPolicy[claimTopic];
        if (policyAddr == address(0)) revert PolicyNotConfiguredForTopic(claimTopic);

        bytes32 schemaUID = _topicToSchema[claimTopic];
        if (schemaUID == bytes32(0)) return false;

        ITopicPolicy policy = ITopicPolicy(policyAddr);
        address[] memory attesters = _trustedIssuersAdapter.getTrustedAttestersForTopic(claimTopic);

        for (uint256 i = 0; i < attesters.length; i++) {
            bytes32 uid = _registeredAttestations[identity][claimTopic][attesters[i]];
            if (uid == bytes32(0)) continue;

            Attestation memory att = _eas.getAttestation(uid);
            if (att.uid == bytes32(0)) continue;
            if (att.schema != schemaUID) continue;
            if (att.revocationTime != 0) continue;
            if (att.expirationTime != 0 && att.expirationTime <= block.timestamp) continue;
            if (!_trustedIssuersAdapter.isAttesterTrusted(att.attester, claimTopic)) continue;

            if (policy.validate(att)) return true;
        }
        return false;
    }
}
