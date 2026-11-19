// SPDX-License-Identifier: Apache-2.0
// Copyright © 2026 Enterprise Ethereum Alliance Inc.
pragma solidity =0.8.24;

/**
 * @title IEASClaimVerifier
 * @author EEA Working Group
 * @notice Interface for the Shibui claim verifier
 * @dev Enables ERC-3643 security tokens to evaluate investor eligibility using EAS attestations
 */
interface IEASClaimVerifier {
    // ============ Types ============

    /**
     * @notice Per-topic verification outcome returned by `getTopicStatuses`.
     * @dev When several trusted attesters have registered attestations for a topic and none
     *      passes, the status reports the candidate that got furthest through the checks
     *      (later enum values = further). Order of checks per candidate:
     *      registered → exists with matching schema → not revoked → not expired →
     *      attester still trusted → policy accepts.
     */
    enum TopicStatus {
        OK, //                   topic satisfied
        NotConfigured, //        EAS, trusted-issuers adapter or identity proxy unset or without code
        PolicyMissing, //        no policy bound to the topic (isVerified reverts here)
        SchemaNotMapped, //      no schema bound to the topic
        NotRegistered, //        no attestation registered by any trusted attester
        AttestationInvalid, //   registered UID not found in EAS or schema no longer matches
        Revoked, //              attestation revoked in EAS
        Expired, //              EAS expirationTime has passed
        AttesterNotTrusted, //   attester no longer trusted for the topic
        PolicyRejected //        policy rejected the payload, reverted, has no code or returned malformed data
    }

    // ============ Events ============

    /// @notice Emitted when a claim topic to schema UID mapping is set
    /// @param claimTopic The ERC-3643 claim topic ID
    /// @param schemaUID The EAS schema UID
    event TopicSchemaMappingSet(uint256 indexed claimTopic, bytes32 indexed schemaUID);

    /// @notice Emitted when the EAS contract address is updated
    /// @param easAddress The new EAS contract address
    event EASAddressSet(address indexed easAddress);

    /// @notice Emitted when the trusted-attester registry adapter address is updated
    /// @param adapterAddress The new adapter address
    event TrustedIssuersAdapterSet(address indexed adapterAddress);

    /// @notice Emitted when the identity proxy address is updated
    /// @param proxyAddress The new identity proxy address
    event IdentityProxySet(address indexed proxyAddress);

    /// @notice Emitted when the claim topics registry address is updated
    /// @param registryAddress The new claim topics registry address
    event ClaimTopicsRegistrySet(address indexed registryAddress);

    /// @notice Emitted when a topic policy contract is set (audit finding C-1).
    /// @param claimTopic The ERC-3643 claim topic ID
    /// @param policy The ITopicPolicy contract bound to this topic
    event TopicPolicySet(uint256 indexed claimTopic, address indexed policy);

    // ============ Errors ============

    /// @notice Thrown when EAS address is not configured
    error EASNotConfigured();

    /// @notice Thrown when the trusted-attester registry adapter is not configured
    error TrustedIssuersAdapterNotConfigured();

    /// @notice Thrown when claim topics registry is not configured
    error ClaimTopicsRegistryNotConfigured();

    /// @notice Thrown when schema UID is not mapped for a claim topic
    /// @param claimTopic The unmapped claim topic
    error SchemaNotMappedForTopic(uint256 claimTopic);

    /// @notice Thrown when attempting to set zero address
    error ZeroAddressNotAllowed();

    /// @notice Thrown when a required identity proxy has not been configured (audit finding C-6).
    error IdentityProxyNotConfigured();

    /// @notice Thrown when no policy is configured for a required claim topic (audit finding C-1).
    /// @param claimTopic The topic with no bound policy
    error PolicyNotConfiguredForTopic(uint256 claimTopic);

    /// @notice Thrown when `registerAttestations` receives arrays of different lengths.
    error ArrayLengthMismatch();

    // ============ View Functions ============

    /**
     * @notice Checks if an address has valid EAS attestations for all required claim topics
     * @param userAddress The wallet address to verify
     * @return bool True if the address has valid attestations for all required topics
     */
    function isVerified(address userAddress) external view returns (bool);

    /**
     * @notice Same checks as `isVerified`, against a caller-supplied topic set instead of the
     *         ClaimTopicsRegistry. Lets several tokens with different rules share one verifier.
     * @dev Reverts on the same misconfigurations as `isVerified`. An empty `topics` returns true.
     *      Schema, policy and trusted attesters are still configured per topic on this verifier,
     *      so tokens that need different rules for the same concept use different topic IDs.
     * @param userAddress The wallet address to verify
     * @param topics The claim topics that must all be satisfied
     * @return True if every topic in `topics` is satisfied
     */
    function isVerifiedForTopics(address userAddress, uint256[] calldata topics) external view returns (bool);

    /**
     * @notice Explains verification: one status per topic, computed by the same code path as
     *         `isVerified` / `isVerifiedForTopics`.
     * @dev Does not revert on misconfiguration: an unset dependency (EAS, trusted-issuers
     *      adapter, identity proxy) or one set to an address with no code yields `NotConfigured`;
     *      a missing policy yields `PolicyMissing`; a policy that reverts, has no code or returns
     *      malformed data yields `PolicyRejected`. It can still revert if a configured dependency
     *      contract itself reverts. For a non-empty `topics`, a user is verified exactly when every
     *      returned status is `OK`, so ERC-7943 `canSend`/`canReceive`/`canTransfer` can be built
     *      on this without wrapping the call. An empty `topics` returns an empty array; callers
     *      must not treat that as verified on its own (`isVerifiedForTopics` reverts first when
     *      the verifier is unconfigured).
     * @param userAddress The wallet address to explain
     * @param topics The claim topics to evaluate (e.g. the registry's `getClaimTopics()`)
     * @return statuses `statuses[i]` is the outcome for `topics[i]`
     */
    function getTopicStatuses(address userAddress, uint256[] calldata topics)
        external
        view
        returns (TopicStatus[] memory statuses);

    /**
     * @notice Returns the EAS schema UID mapped to a given claim topic
     * @param claimTopic The ERC-3643 claim topic ID
     * @return schemaUID The EAS schema UID
     */
    function getSchemaUID(uint256 claimTopic) external view returns (bytes32 schemaUID);

    /**
     * @notice Returns the EAS contract address
     * @return The EAS contract address
     */
    function getEASAddress() external view returns (address);

    /**
     * @notice Returns the trusted-attester registry adapter address
     * @return The adapter address
     */
    function getTrustedIssuersAdapter() external view returns (address);

    /**
     * @notice Returns the identity proxy address
     * @return The identity proxy address
     */
    function getIdentityProxy() external view returns (address);

    /**
     * @notice Returns the claim topics registry address
     * @return The claim topics registry address
     */
    function getClaimTopicsRegistry() external view returns (address);

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
        returns (bytes32);

    // ============ Registration Functions ============

    /**
     * @notice Registers an attestation UID for (identity, topic, attester).
     * @dev Callable by the attester or an authorized identity-proxy agent, never the identity itself.
     * @param identity The identity the attestation is about (must equal its recipient)
     * @param claimTopic The claim topic the attestation satisfies
     * @param attestationUID The EAS attestation UID
     */
    function registerAttestation(address identity, uint256 claimTopic, bytes32 attestationUID) external;

    /**
     * @notice Batch form of `registerAttestation` for one identity: registers
     *         `attestationUIDs[i]` for `claimTopics[i]`. All-or-nothing: reverts if any entry fails.
     * @param identity The identity the attestations are about
     * @param claimTopics The claim topics, one per UID
     * @param attestationUIDs The EAS attestation UIDs
     */
    function registerAttestations(address identity, uint256[] calldata claimTopics, bytes32[] calldata attestationUIDs)
        external;

    // ============ Configuration Functions ============

    /**
     * @notice Maps an ERC-3643 claim topic to an EAS schema UID
     * @dev Only callable by OPERATOR_ROLE
     * @param claimTopic The ERC-3643 claim topic ID (uint256)
     * @param schemaUID The EAS schema UID (bytes32)
     */
    function setTopicSchemaMapping(uint256 claimTopic, bytes32 schemaUID) external;

    /**
     * @notice Sets the EAS contract address
     * @dev Only callable by OPERATOR_ROLE
     * @param easAddress The EAS contract address
     */
    function setEASAddress(address easAddress) external;

    /**
     * @notice Sets the trusted-attester registry adapter address
     * @dev Only callable by OPERATOR_ROLE
     * @param adapterAddress The adapter contract address
     */
    function setTrustedIssuersAdapter(address adapterAddress) external;

    /**
     * @notice Sets the identity proxy address for wallet-to-identity resolution
     * @dev Only callable by OPERATOR_ROLE
     * @param proxyAddress The identity proxy contract address
     */
    function setIdentityProxy(address proxyAddress) external;

    /**
     * @notice Sets the claim topics registry address
     * @dev Only callable by OPERATOR_ROLE
     * @param registryAddress The claim topics registry contract address
     */
    function setClaimTopicsRegistry(address registryAddress) external;

    /**
     * @notice Binds a policy module to a claim topic (audit finding C-1).
     * @dev Only callable by OPERATOR_ROLE. Passing `address(0)` clears the binding;
     *      `isVerified()` then rejects any required topic that lacks a bound policy.
     * @param claimTopic The ERC-3643 claim topic ID
     * @param policy An ITopicPolicy implementation, or zero to clear
     */
    function setTopicPolicy(uint256 claimTopic, address policy) external;

    /**
     * @notice Returns the policy address bound to a claim topic.
     * @param claimTopic The topic ID
     * @return The policy address (zero if unset)
     */
    function getTopicPolicy(uint256 claimTopic) external view returns (address);
}
