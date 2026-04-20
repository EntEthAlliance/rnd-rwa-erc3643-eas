// SPDX-License-Identifier: Apache-2.0
// Copyright © 2026 Enterprise Ethereum Alliance Inc.
pragma solidity =0.8.24;

import {Attestation} from "@eas/Common.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TopicPolicyBase} from "./TopicPolicyBase.sol";

/**
 * @title CountryAllowListPolicy
 * @author EEA Working Group
 * @notice ERC-3643 Topic 3 (COUNTRY) payload policy backed by an allow-list.
 * @dev The owner maintains a set of ISO 3166-1 numeric country codes that satisfy
 *      the policy. Typical use is to populate with jurisdictions where the token
 *      issuer has a valid offering (e.g. Reg D: US only; Reg S: non-US-set).
 *
 *      A mode flag lets the owner invert the semantic to a block-list style check
 *      without redeploying:
 *        - `Mode.Allow` — country must be in the set.
 *        - `Mode.Block` — country must NOT be in the set.
 *
 *      Ownership is single-key here by design; the verifier that consumes this
 *      policy is under `AccessControl` and is the primary control plane. Policy
 *      ownership may be transferred to the same multisig managing the verifier.
 */
contract CountryAllowListPolicy is TopicPolicyBase, Ownable {
    uint256 internal constant TOPIC_COUNTRY = 3;

    enum Mode {
        Allow,
        Block
    }

    Mode private _mode;
    mapping(uint16 => bool) private _inSet;
    uint16[] private _set;

    event CountryAdded(uint16 indexed countryCode);
    event CountryRemoved(uint16 indexed countryCode);
    event ModeChanged(Mode mode);

    constructor(address initialOwner, Mode initialMode, uint16[] memory initialSet)
        TopicPolicyBase(TOPIC_COUNTRY, "CountryAllowListPolicy")
        Ownable(initialOwner)
    {
        _mode = initialMode;
        for (uint256 i = 0; i < initialSet.length; i++) {
            uint16 c = initialSet[i];
            if (!_inSet[c]) {
                _inSet[c] = true;
                _set.push(c);
                emit CountryAdded(c);
            }
        }
        emit ModeChanged(initialMode);
    }

    // ============ Admin ============

    function addCountry(uint16 countryCode) external onlyOwner {
        if (_inSet[countryCode]) return;
        _inSet[countryCode] = true;
        _set.push(countryCode);
        emit CountryAdded(countryCode);
    }

    function removeCountry(uint16 countryCode) external onlyOwner {
        if (!_inSet[countryCode]) return;
        _inSet[countryCode] = false;
        // swap-and-pop
        uint256 len = _set.length;
        for (uint256 i = 0; i < len; i++) {
            if (_set[i] == countryCode) {
                _set[i] = _set[len - 1];
                _set.pop();
                break;
            }
        }
        emit CountryRemoved(countryCode);
    }

    function setMode(Mode newMode) external onlyOwner {
        _mode = newMode;
        emit ModeChanged(newMode);
    }

    // ============ Views ============

    function mode() external view returns (Mode) {
        return _mode;
    }

    function isInSet(uint16 countryCode) external view returns (bool) {
        return _inSet[countryCode];
    }

    function getSet() external view returns (uint16[] memory) {
        return _set;
    }

    // ============ Policy ============

    function validate(Attestation calldata attestation) external view override returns (bool) {
        (bool ok, InvestorEligibility memory e) = _preflight(attestation.data);
        if (!ok) return false;
        bool inSet = _inSet[e.countryCode];
        return _mode == Mode.Allow ? inSet : !inSet;
    }
}
