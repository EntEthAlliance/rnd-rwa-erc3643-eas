// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IEASIdentityProxy} from "./interfaces/IEASIdentityProxy.sol";

/**
 * @title EASIdentityProxy
 * @author EEA Working Group
 * @notice Maps wallet addresses to identity addresses for multi-wallet support.
 * @dev Audit finding C-3/C-6 consequence: identity-self registration is no longer
 *      a blessed path at the proxy level either. Only accounts holding
 *      DEFAULT_ADMIN_ROLE or AGENT_ROLE may register/remove wallet mappings.
 *      The previous "identity == msg.sender" branch is gone; the rationale is
 *      that in regulated flows, the issuer's agent is the entity who binds
 *      wallets to an investor identity, not the investor themselves.
 */
contract EASIdentityProxy is IEASIdentityProxy, AccessControl {
    // ============ Roles ============

    /// @notice Day-to-day wallet/identity binding role.
    bytes32 public constant AGENT_ROLE = keccak256("AGENT_ROLE");

    // ============ Storage ============

    mapping(address => address) private _walletToIdentity;
    mapping(address => address[]) private _identityWallets;
    mapping(address => uint256) private _walletIndex;

    // ============ Events ============

    /// @notice Emitted when an agent is granted AGENT_ROLE via the helper.
    event AgentAdded(address indexed agent);
    /// @notice Emitted when an agent's AGENT_ROLE is revoked via the helper.
    event AgentRemoved(address indexed agent);

    // ============ Constructor ============

    constructor(address initialAdmin) {
        if (initialAdmin == address(0)) revert ZeroAddressNotAllowed();
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
        _grantRole(AGENT_ROLE, initialAdmin);
    }

    // ============ Modifiers ============

    modifier onlyAgent() {
        if (!hasRole(AGENT_ROLE, msg.sender)) revert NotAuthorized();
        _;
    }

    // ============ Agent management (helper surface for backwards compat) ============

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
