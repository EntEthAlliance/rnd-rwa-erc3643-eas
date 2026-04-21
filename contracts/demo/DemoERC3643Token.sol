// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IEASClaimVerifier} from "../interfaces/IEASClaimVerifier.sol";

/**
 * @title DemoERC3643Token
 * @notice Demo-only, testnet-only ERC-3643-shaped token that gates every
 *         transfer on Shibui's `EASClaimVerifier.isVerified()`.
 *
 *         This contract is deliberately NOT a full T-REX implementation — it
 *         omits ModularCompliance, OnchainID, recovery, and partial freeze.
 *         Its single job is to render the "transfer blocked because the
 *         recipient is not verified" moment in the demo UI.
 *
 *         DO NOT deploy to mainnet. The name, the revert message, and this
 *         comment all say demo; the audited production path is through the
 *         ERC-3643 reference implementation wired to `EASClaimVerifier` via
 *         ModularCompliance.
 */
contract DemoERC3643Token is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant AGENT_ROLE = keccak256("AGENT_ROLE");

    IEASClaimVerifier public immutable claimVerifier;

    error DemoTransferBlocked(address account, string reason);

    constructor(
        string memory name_,
        string memory symbol_,
        address claimVerifier_,
        address admin
    ) ERC20(name_, symbol_) {
        require(claimVerifier_ != address(0), "verifier=0");
        claimVerifier = IEASClaimVerifier(claimVerifier_);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(AGENT_ROLE, admin);
    }

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function _update(address from, address to, uint256 value) internal override {
        // Mints (from=0) and burns (to=0) skip the compliance gate — same as
        // the T-REX reference. Transfers between wallets must both sides be
        // verified under Shibui's current policy set.
        if (from != address(0) && !claimVerifier.isVerified(from)) {
            revert DemoTransferBlocked(from, "Sender not verified");
        }
        if (to != address(0) && !claimVerifier.isVerified(to)) {
            revert DemoTransferBlocked(to, "Recipient not verified");
        }
        super._update(from, to, value);
    }
}
