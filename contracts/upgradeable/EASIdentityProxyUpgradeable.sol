// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IEASIdentityProxy} from "../interfaces/IEASIdentityProxy.sol";

/**
 * @title EASIdentityProxyUpgradeable
 * @author EEA Working Group
 * @notice UUPS-upgradeable version of EASIdentityProxy.
 * @dev Audit finding C-3 consequence: self-identity registration is disallowed.
 *      AGENT_ROLE holders are the only entities that may mutate wallet-identity
 *      bindings.
 */
contract EASIdentityProxyUpgradeable is Initializable, AccessControlUpgradeable, UUPSUpgradeable, IEASIdentityProxy {
    // ============ Roles ============

    bytes32 public constant AGENT_ROLE = keccak256("AGENT_ROLE");

    // ============ Storage ============

    mapping(address => address) private _walletToIdentity;
    mapping(address => address[]) private _identityWallets;
    mapping(address => uint256) private _walletIndex;

    /// @dev The previous `_agents` mapping slot is now unused; AGENT_ROLE lives in
    ///      AccessControl storage. Kept here as reserved storage to preserve slot
    ///      alignment with the pre-refactor layout for any experimental deployment.
    mapping(address => bool) private _reserved_legacyAgents;

    /// @dev Reserved storage gap — unchanged to preserve total slot budget.
    uint256[46] private __gap;

    // ============ Events ============

    event AgentAdded(address indexed agent);
    event AgentRemoved(address indexed agent);

    // ============ Constructor / Initializer ============

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialAdmin) external initializer {
        if (initialAdmin == address(0)) revert ZeroAddressNotAllowed();
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
        _grantRole(AGENT_ROLE, initialAdmin);
    }

    function _authorizeUpgrade(
        address /*newImplementation*/
    )
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}

    // ============ Modifiers ============

    modifier onlyAgent() {
        if (!hasRole(AGENT_ROLE, msg.sender)) revert NotAuthorized();
        _;
    }

    // ============ Agent management (helper surface) ============

    function addAgent(address agent) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (agent == address(0)) revert ZeroAddressNotAllowed();
        _grantRole(AGENT_ROLE, agent);
        emit AgentAdded(agent);
    }

    function removeAgent(address agent) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(AGENT_ROLE, agent);
        emit AgentRemoved(agent);
    }

    function isAgent(address agent) external view override returns (bool) {
        return hasRole(AGENT_ROLE, agent);
    }

    // ============ Wallet registration ============

    function registerWallet(address wallet, address identity) external override onlyAgent {
        if (wallet == address(0) || identity == address(0)) revert ZeroAddressNotAllowed();

        address existingIdentity = _walletToIdentity[wallet];
        if (existingIdentity != address(0) && existingIdentity != identity) {
            revert WalletAlreadyRegistered(wallet, existingIdentity);
        }
        if (existingIdentity == identity) return;

        _walletToIdentity[wallet] = identity;
        _walletIndex[wallet] = _identityWallets[identity].length;
        _identityWallets[identity].push(wallet);

        emit WalletRegistered(wallet, identity);
    }

    function removeWallet(address wallet) external override onlyAgent {
        address identity = _walletToIdentity[wallet];
        if (identity == address(0)) return;

        uint256 index = _walletIndex[wallet];
        address[] storage wallets = _identityWallets[identity];
        uint256 lastIndex = wallets.length - 1;

        if (index != lastIndex) {
            address lastWallet = wallets[lastIndex];
            wallets[index] = lastWallet;
            _walletIndex[lastWallet] = index;
        }
        wallets.pop();

        delete _walletToIdentity[wallet];
        delete _walletIndex[wallet];

        emit WalletRemoved(wallet, identity);
    }

    function batchRegisterWallets(address[] calldata wallets, address identity) external override onlyAgent {
        if (identity == address(0)) revert ZeroAddressNotAllowed();

        for (uint256 i = 0; i < wallets.length; i++) {
            address wallet = wallets[i];
            if (wallet == address(0)) revert ZeroAddressNotAllowed();

            address existingIdentity = _walletToIdentity[wallet];
            if (existingIdentity != address(0) && existingIdentity != identity) {
                revert WalletAlreadyRegistered(wallet, existingIdentity);
            }
            if (existingIdentity == identity) continue;

            _walletToIdentity[wallet] = identity;
            _walletIndex[wallet] = _identityWallets[identity].length;
            _identityWallets[identity].push(wallet);

            emit WalletRegistered(wallet, identity);
        }
    }

    // ============ Views ============

    function getIdentity(address wallet) external view override returns (address) {
        address identity = _walletToIdentity[wallet];
        return identity == address(0) ? wallet : identity;
    }

    function getWallets(address identity) external view override returns (address[] memory) {
        return _identityWallets[identity];
    }

    function isRegistered(address wallet) external view override returns (bool) {
        return _walletToIdentity[wallet] != address(0);
    }
}
