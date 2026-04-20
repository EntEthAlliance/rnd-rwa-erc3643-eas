// SPDX-License-Identifier: Apache-2.0
// Copyright © 2026 Enterprise Ethereum Alliance Inc.
pragma solidity =0.8.24;

/**
 * @title IEASClaimVerifier
 * @author EEA Working Group
 * @notice Interface for the EAS Claim Verifier contract that bridges EAS attestations to ERC-3643 compliance
 * @dev The core adapter that enables ERC-3643 security tokens to accept EAS attestations for identity verification
 */
interface IEASClaimVerifier {
    // ============ Events ============

    /// @notice Emitted when a claim topic to schema UID mapping is set
    /// @param claimTopic The ERC-3643 claim topic ID
    /// @param schemaUID The EAS schema UID
    event TopicSchemaMappingSet(uint256 indexed claimTopic, bytes32 indexed schemaUID);

    /// @notice Emitted when the EAS contract address is updated
    /// @param easAddress The new EAS contract address
    event EASAddressSet(address indexed easAddress);

    /// @notice Emitted when the trusted issuers adapter address is updated
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

    /// @notice Thrown when trusted issuers adapter is not configured
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

    // ============ View Functions ============

    /**
     * @notice Checks if an address has valid EAS attestations for all required claim topics
     * @param userAddress The wallet address to verify
     * @return bool True if the address has valid attestations for all required topics
     */
    function isVerified(address userAddress) external view returns (bool);

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
     * @notice Returns the trusted issuers adapter address
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

    // ============ Configuration Functions ============

    /**
     * @notice Maps an ERC-3643 claim topic to an EAS schema UID
     * @dev Only callable by owner
     * @param claimTopic The ERC-3643 claim topic ID (uint256)
     * @param schemaUID The EAS schema UID (bytes32)
     */
    function setTopicSchemaMapping(uint256 claimTopic, bytes32 schemaUID) external;

    /**
     * @notice Sets the EAS contract address
     * @dev Only callable by owner
     * @param easAddress The EAS contract address
     */
    function setEASAddress(address easAddress) external;

    /**
     * @notice Sets the trusted issuers adapter address
     * @dev Only callable by owner
     * @param adapterAddress The adapter contract address
     */
    function setTrustedIssuersAdapter(address adapterAddress) external;

    /**
     * @notice Sets the identity proxy address for wallet-to-identity resolution
     * @dev Only callable by owner
     * @param proxyAddress The identity proxy contract address
     */
    function setIdentityProxy(address proxyAddress) external;

    /**
     * @notice Sets the claim topics registry address
     * @dev Only callable by owner
     * @param registryAddress The claim topics registry contract address
     */
    function setClaimTopicsRegistry(address registryAddress) external;

    /**
     * @notice Binds a policy module to a claim topic (audit finding C-1).
     * @dev Only callable by an operator role. Passing `address(0)` clears the
     *      binding; `isVerified()` will then reject any required topic that
     *      lacks a bound policy.
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
