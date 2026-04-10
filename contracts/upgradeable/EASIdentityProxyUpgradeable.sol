// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IEASIdentityProxy} from "../interfaces/IEASIdentityProxy.sol";

/**
 * @title EASIdentityProxyUpgradeable
 * @author EEA Working Group
 * @notice UUPS-upgradeable version of EASIdentityProxy
 * @dev Maps wallet addresses to identity addresses for multi-wallet support.
 *      Enables multiple wallets to share one identity's attestations.
 */
contract EASIdentityProxyUpgradeable is Initializable, OwnableUpgradeable, UUPSUpgradeable, IEASIdentityProxy {
    // ============ Storage ============

    /// @notice Mapping from wallet to identity address
    mapping(address => address) private _walletToIdentity;

    /// @notice Mapping from identity to array of linked wallets
    mapping(address => address[]) private _identityWallets;

    /// @notice Mapping to track wallet index in identity's wallet array (for efficient removal)
    mapping(address => uint256) private _walletIndex;

    /// @notice Mapping of addresses authorized as agents
    mapping(address => bool) private _agents;

    /// @dev Reserved storage gap for future upgrades
    uint256[46] private __gap;

    // ============ Events ============

    /// @notice Emitted when an agent is added
    /// @param agent The agent address
    event AgentAdded(address indexed agent);

    /// @notice Emitted when an agent is removed
    /// @param agent The agent address
    event AgentRemoved(address indexed agent);

    // ============ Modifiers ============

    /**
     * @notice Restricts function to owner, agents, or the identity address itself
     * @param identity The identity address to check against
     */
    modifier onlyAuthorized(address identity) {
        if (msg.sender != owner() && !_agents[msg.sender] && msg.sender != identity) {
            revert NotAuthorized();
        }
        _;
    }

    // ============ Constructor ============

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // ============ Initializer ============

    /**
     * @notice Initializes the proxy with an owner
     * @param initialOwner The initial owner address
     */
    function initialize(address initialOwner) external initializer {
        __Ownable_init(initialOwner);
    }

    // ============ UUPS Authorization ============

    /**
     * @notice Authorizes contract upgrades
     * @dev Only owner can upgrade
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // ============ Agent Management ============

    /**
     * @notice Adds an agent
     * @dev Only callable by owner
     * @param agent The address to add as agent
     */
    function addAgent(address agent) external onlyOwner {
        if (agent == address(0)) revert ZeroAddressNotAllowed();
        _agents[agent] = true;
        emit AgentAdded(agent);
    }

    /**
     * @notice Removes an agent
     * @dev Only callable by owner
     * @param agent The address to remove as agent
     */
    function removeAgent(address agent) external onlyOwner {
        _agents[agent] = false;
        emit AgentRemoved(agent);
    }

    /**
     * @notice Checks if an address is an agent
     * @param agent The address to check
     * @return True if the address is an agent
     */
    function isAgent(address agent) external view override returns (bool) {
        return _agents[agent];
    }

    // ============ External Functions ============

    /**
     * @inheritdoc IEASIdentityProxy
     */
    function registerWallet(address wallet, address identity) external override onlyAuthorized(identity) {
        if (wallet == address(0) || identity == address(0)) {
            revert ZeroAddressNotAllowed();
        }

        address existingIdentity = _walletToIdentity[wallet];
        if (existingIdentity != address(0) && existingIdentity != identity) {
            revert WalletAlreadyRegistered(wallet, existingIdentity);
        }

        // If already registered to same identity, no-op
        if (existingIdentity == identity) {
            return;
        }

        _walletToIdentity[wallet] = identity;
        _walletIndex[wallet] = _identityWallets[identity].length;
        _identityWallets[identity].push(wallet);

        emit WalletRegistered(wallet, identity);
    }

    /**
     * @inheritdoc IEASIdentityProxy
     */
    function removeWallet(address wallet) external override {
        address identity = _walletToIdentity[wallet];
        if (identity == address(0)) {
            return; // Wallet not registered, no-op
        }

        // Check authorization: must be owner, agent, or the identity itself
        if (msg.sender != owner() && !_agents[msg.sender] && msg.sender != identity) {
            revert NotAuthorized();
        }

        // Remove from identity's wallet array
        uint256 index = _walletIndex[wallet];
        address[] storage wallets = _identityWallets[identity];
        uint256 lastIndex = wallets.length - 1;

        if (index != lastIndex) {
            address lastWallet = wallets[lastIndex];
            wallets[index] = lastWallet;
            _walletIndex[lastWallet] = index;
        }
        wallets.pop();

        // Clear mappings
        delete _walletToIdentity[wallet];
        delete _walletIndex[wallet];

        emit WalletRemoved(wallet, identity);
    }

    /**
     * @inheritdoc IEASIdentityProxy
     */
    function getIdentity(address wallet) external view override returns (address) {
        address identity = _walletToIdentity[wallet];
        // If no mapping exists, return the wallet address itself
        return identity == address(0) ? wallet : identity;
    }

    /**
     * @inheritdoc IEASIdentityProxy
     */
    function getWallets(address identity) external view override returns (address[] memory) {
        return _identityWallets[identity];
    }

    /**
     * @inheritdoc IEASIdentityProxy
     */
    function isRegistered(address wallet) external view override returns (bool) {
        return _walletToIdentity[wallet] != address(0);
    }

    /**
     * @inheritdoc IEASIdentityProxy
     */
    function batchRegisterWallets(address[] calldata wallets, address identity)
        external
        override
        onlyAuthorized(identity)
    {
        if (identity == address(0)) revert ZeroAddressNotAllowed();

        for (uint256 i = 0; i < wallets.length; i++) {
            address wallet = wallets[i];
            if (wallet == address(0)) revert ZeroAddressNotAllowed();

            address existingIdentity = _walletToIdentity[wallet];
            if (existingIdentity != address(0) && existingIdentity != identity) {
                revert WalletAlreadyRegistered(wallet, existingIdentity);
            }

            // Skip if already registered to same identity
            if (existingIdentity == identity) {
                continue;
            }

            _walletToIdentity[wallet] = identity;
            _walletIndex[wallet] = _identityWallets[identity].length;
            _identityWallets[identity].push(wallet);

            emit WalletRegistered(wallet, identity);
        }
    }
}
