// SPDX-License-Identifier: Apache-2.0
// Copyright © 2026 Enterprise Ethereum Alliance Inc.
pragma solidity =0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IEAS, Attestation} from "@eas/IEAS.sol";
import {IEASClaimVerifier} from "./interfaces/IEASClaimVerifier.sol";
import {IEASTrustedIssuersAdapter} from "./interfaces/IEASTrustedIssuersAdapter.sol";
import {IEASIdentityProxy} from "./interfaces/IEASIdentityProxy.sol";
import {IClaimTopicsRegistry} from "./interfaces/IClaimTopicsRegistry.sol";
import {ITopicPolicy} from "./policies/ITopicPolicy.sol";

/**
 * @title EASClaimVerifier
 * @author EEA Working Group
 * @notice Core adapter that enables ERC-3643 security tokens to accept EAS attestations.
 * @dev Verification flow (post audit fixes C-1, C-2, C-3, C-6):
 *      1. Resolve wallet → identity via the configured proxy. **Reverts** if no
 *         proxy is configured (C-6): there is no implicit "wallet is its own
 *         identity" fallback in production.
 *      2. For each required topic from the ClaimTopicsRegistry:
 *         a. Look up the bound ITopicPolicy (C-1). If none, verification fails.
 *         b. Look up the bound EAS schema UID.
 *         c. Iterate the trusted attesters for the topic (≤ MAX_ATTESTERS_PER_TOPIC).
 *            For each, fetch the registered attestation UID for
 *            (identity, topic, attester); verify the attestation exists, its
 *            schema matches, it is not revoked, its EAS-level expiration is
 *            current, and the topic policy's `validate()` returns true.
 *            As soon as one passes, the topic is satisfied.
 *         d. If no attester satisfies the topic, verification fails.
 *      3. Return true only if every required topic is satisfied.
 *
 *      `registerAttestation` (C-3): callable by the attester OR an authorized
 *      identity-proxy agent. **Not** callable by the identity itself, to prevent
 *      investors from self-registering weak attestations.
 */
contract EASClaimVerifier is IEASClaimVerifier, AccessControl {
    // ============ Roles ============

    /// @notice Role authorised to modify operational configuration (topic-schema mapping,
    ///         topic-policy mapping, setting adapter/proxy/registry addresses).
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // ============ Storage ============

    IEAS private _eas;
    IEASTrustedIssuersAdapter private _trustedIssuersAdapter;
    IEASIdentityProxy private _identityProxy;
    IClaimTopicsRegistry private _claimTopicsRegistry;

    /// @notice topic → schema UID
    mapping(uint256 => bytes32) private _topicToSchema;

    /// @notice topic → policy module (audit finding C-1)
    mapping(uint256 => address) private _topicToPolicy;

    /// @notice identity → topic → attester → attestationUID
    mapping(address => mapping(uint256 => mapping(address => bytes32))) private _registeredAttestations;

    // ============ Events (in addition to interface) ============

    event AttestationRegistered(
        address indexed identity, uint256 indexed claimTopic, address indexed attester, bytes32 attestationUID
    );

    // ============ Constructor ============

    /**
     * @param initialAdmin Address that receives both DEFAULT_ADMIN_ROLE and
     *        OPERATOR_ROLE. Expected to be a multisig in production (audit
     *        finding R-6). Deployer should transfer admin to the multisig and
     *        then renounce its own DEFAULT_ADMIN_ROLE grant.
     */
    constructor(address initialAdmin) {
        if (initialAdmin == address(0)) revert ZeroAddressNotAllowed();
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
        _grantRole(OPERATOR_ROLE, initialAdmin);
    }

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

    /**
     * @notice Sets the identity proxy. Audit finding C-6: zero address is NOT
     *         allowed; there is no wallet-as-identity fallback.
     */
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

    /**
     * @notice Registers an attestation UID for (identity, topic, attester).
     * @dev Audit finding C-3: the identity address itself is NOT an authorized
     *      caller. Investor self-registration is disallowed. Only the attester
     *      or an authorized identity-proxy agent may register.
     *
     *      The function still validates that the attestation exists, matches the
     *      configured schema for the topic, targets the right recipient, and is
     *      from an attester currently trusted for the topic. Payload semantics
     *      (e.g. `kycStatus == VERIFIED`) are enforced at verification time by
     *      the topic policy, not here — so an attestation that is stale at the
     *      policy level may still be registered, and will simply never satisfy
     *      `isVerified()` until refreshed.
     */
    function registerAttestation(address identity, uint256 claimTopic, bytes32 attestationUID) external override {
        _registerAttestation(identity, claimTopic, attestationUID);
    }

    /// @notice Batch form of `registerAttestation` for one identity. All-or-nothing.
    function registerAttestations(address identity, uint256[] calldata claimTopics, bytes32[] calldata attestationUIDs)
        external
        override
    {
        if (claimTopics.length != attestationUIDs.length) revert ArrayLengthMismatch();
        for (uint256 i = 0; i < claimTopics.length; i++) {
            _registerAttestation(identity, claimTopics[i], attestationUIDs[i]);
        }
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

        return _isVerified(userAddress, _claimTopicsRegistry.getClaimTopics());
    }

    function isVerifiedForTopics(address userAddress, uint256[] calldata topics) external view override returns (bool) {
        if (address(_eas) == address(0)) revert EASNotConfigured();
        if (address(_trustedIssuersAdapter) == address(0)) revert TrustedIssuersAdapterNotConfigured();
        if (address(_identityProxy) == address(0)) revert IdentityProxyNotConfigured();

        return _isVerified(userAddress, topics);
    }

    function getTopicStatuses(address userAddress, uint256[] calldata topics)
        external
        view
        override
        returns (TopicStatus[] memory statuses)
    {
        statuses = new TopicStatus[](topics.length);
        // A dependency set to an address with no code counts as unconfigured: calling it would
        // revert on the empty return data and break this view's no-revert guarantee.
        bool configured = address(_eas).code.length > 0 && address(_trustedIssuersAdapter).code.length > 0
            && address(_identityProxy).code.length > 0;
        address identity = configured ? _identityProxy.getIdentity(userAddress) : address(0);

        for (uint256 i = 0; i < topics.length; i++) {
            statuses[i] = configured ? _topicStatus(identity, topics[i]) : TopicStatus.NotConfigured;
        }
    }

    // ============ Internal ============

    function _registerAttestation(address identity, uint256 claimTopic, bytes32 attestationUID) internal {
        if (address(_eas) == address(0)) revert EASNotConfigured();
        if (address(_trustedIssuersAdapter) == address(0)) revert TrustedIssuersAdapterNotConfigured();

        bytes32 schemaUID = _topicToSchema[claimTopic];
        if (schemaUID == bytes32(0)) revert SchemaNotMappedForTopic(claimTopic);

        Attestation memory attestation = _eas.getAttestation(attestationUID);
        require(attestation.uid != bytes32(0), "Attestation not found");
        require(attestation.schema == schemaUID, "Schema mismatch");
        require(attestation.recipient == identity, "Recipient mismatch");
        require(_trustedIssuersAdapter.isAttesterTrusted(attestation.attester, claimTopic), "Attester not trusted");

        bool callerIsAttester = attestation.attester == msg.sender;
        bool callerIsAuthorizedAgent = address(_identityProxy) != address(0) && _identityProxy.isAgent(msg.sender);
        require(callerIsAttester || callerIsAuthorizedAgent, "Caller not authorized");

        _registeredAttestations[identity][claimTopic][attestation.attester] = attestationUID;

        emit AttestationRegistered(identity, claimTopic, attestation.attester, attestationUID);
    }

    /// @dev Evaluates every topic in order and stops at the first failure.
    ///      A missing policy reverts (audit finding C-1); use `getTopicStatuses` to avoid reverts.
    function _isVerified(address userAddress, uint256[] memory topics) internal view returns (bool) {
        address identity = _identityProxy.getIdentity(userAddress);
        for (uint256 i = 0; i < topics.length; i++) {
            TopicStatus status = _topicStatus(identity, topics[i]);
            if (status == TopicStatus.PolicyMissing) revert PolicyNotConfiguredForTopic(topics[i]);
            if (status != TopicStatus.OK) return false;
        }
        return true;
    }

    /**
     * @notice Verifies a single topic by iterating trusted attesters and
     *         applying the topic policy to each candidate attestation.
     * @dev Audit finding C-2: no single-slot cache; iteration over the trusted
     *      attester list is the authoritative source of truth. The list is
     *      bounded by the adapter's MAX_ATTESTERS_PER_TOPIC (currently 5).
     *      Returns OK as soon as one attester's attestation passes; otherwise the
     *      failure of the candidate that got furthest through the checks.
     */
    function _topicStatus(address identity, uint256 claimTopic) internal view returns (TopicStatus) {
        address policyAddr = _topicToPolicy[claimTopic];
        if (policyAddr == address(0)) return TopicStatus.PolicyMissing;

        bytes32 schemaUID = _topicToSchema[claimTopic];
        if (schemaUID == bytes32(0)) return TopicStatus.SchemaNotMapped;

        address[] memory attesters = _trustedIssuersAdapter.getTrustedAttestersForTopic(claimTopic);
        TopicStatus furthest = TopicStatus.NotRegistered;

        for (uint256 i = 0; i < attesters.length; i++) {
            TopicStatus status =
                _attestationStatus(identity, claimTopic, schemaUID, ITopicPolicy(policyAddr), attesters[i]);
            if (status == TopicStatus.OK) return TopicStatus.OK;
            if (uint8(status) > uint8(furthest)) furthest = status;
        }
        return furthest;
    }

    /// @dev Checks the attestation registered by one attester for (identity, topic).
    function _attestationStatus(
        address identity,
        uint256 claimTopic,
        bytes32 schemaUID,
        ITopicPolicy policy,
        address attester
    ) internal view returns (TopicStatus) {
        bytes32 uid = _registeredAttestations[identity][claimTopic][attester];
        if (uid == bytes32(0)) return TopicStatus.NotRegistered;

        Attestation memory att = _eas.getAttestation(uid);
        if (att.uid == bytes32(0) || att.schema != schemaUID) return TopicStatus.AttestationInvalid;
        if (att.revocationTime != 0) return TopicStatus.Revoked;
        if (att.expirationTime != 0 && att.expirationTime <= block.timestamp) return TopicStatus.Expired;
        // Attester may have been de-trusted since registration:
        if (!_trustedIssuersAdapter.isAttesterTrusted(att.attester, claimTopic)) return TopicStatus.AttesterNotTrusted;

        // Policies must never revert. A low-level call fails closed on everything a misbehaving
        // policy can do: revert, no code (empty return), short return, or a non-bool value.
        // try/catch would not catch the last three, because its return decoding reverts.
        (bool success, bytes memory ret) = address(policy).staticcall(abi.encodeCall(ITopicPolicy.validate, (att)));
        if (!success || ret.length < 32) return TopicStatus.PolicyRejected;
        return abi.decode(ret, (uint256)) == 1 ? TopicStatus.OK : TopicStatus.PolicyRejected;
    }
}
