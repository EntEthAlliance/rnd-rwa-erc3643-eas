// SPDX-License-Identifier: Apache-2.0
// Copyright © 2026 Enterprise Ethereum Alliance Inc.
pragma solidity ^0.8.24;

/**
 * @title IEASIdentityProxy
 * @author EEA Working Group
 * @notice Interface for mapping wallet addresses to identity addresses
 * @dev Enables multi-wallet support where attestations are made to a single identity
 *      that multiple wallets share. This mirrors the IdentityRegistryStorage pattern.
 */
interface IEASIdentityProxy {
    /// @notice Emitted when a wallet is registered under an identity
    /// @param wallet The wallet address
    /// @param identity The identity address
    event WalletRegistered(address indexed wallet, address indexed identity);

    /// @notice Emitted when a wallet mapping is removed
    /// @param wallet The wallet address
    /// @param identity The previous identity address
    event WalletRemoved(address indexed wallet, address indexed identity);

    /// @notice Error thrown when caller is not authorized
    error NotAuthorized();

    /// @notice Error thrown when zero address is provided
    error ZeroAddressNotAllowed();

    /// @notice Error thrown when wallet is already registered to a different identity
    error WalletAlreadyRegistered(address wallet, address existingIdentity);

    /**
     * @notice Registers a wallet under an identity address
     * @dev Only callable by an agent or by the identity address itself
     * @param wallet The wallet address to register
     * @param identity The identity address (attestations are made to this address)
     */
    function registerWallet(address wallet, address identity) external;

    /**
     * @notice Removes a wallet mapping
     * @dev Only callable by an agent or by the identity address
     * @param wallet The wallet address to remove
     */
    function removeWallet(address wallet) external;

    /**
     * @notice Gets the identity address for a wallet
     * @dev Returns the wallet itself if no mapping exists
     * @param wallet The wallet address to look up
     * @return The identity address (or wallet address if no mapping)
     */
    function getIdentity(address wallet) external view returns (address);

    /**
     * @notice Gets all wallets registered under an identity
     * @param identity The identity address
     * @return Array of wallet addresses
     */
    function getWallets(address identity) external view returns (address[] memory);

    /**
     * @notice Checks if a wallet is registered (has a mapping)
     * @param wallet The wallet address to check
     * @return True if the wallet has a registered identity mapping
     */
    function isRegistered(address wallet) external view returns (bool);

    /**
     * @notice Checks whether an address is an authorized agent
     * @param agent The address to check
     * @return True if the address is an authorized agent
     */
    function isAgent(address agent) external view returns (bool);

    /**
     * @notice Registers multiple wallets under an identity in a single transaction
     * @dev Only callable by an agent or by the identity address itself
     * @param wallets Array of wallet addresses to register
     * @param identity The identity address
     */
    function batchRegisterWallets(address[] calldata wallets, address identity) external;
}
