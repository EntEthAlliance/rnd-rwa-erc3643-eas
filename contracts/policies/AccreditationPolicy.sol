// SPDX-License-Identifier: Apache-2.0
// Copyright © 2026 Enterprise Ethereum Alliance Inc.
pragma solidity ^0.8.24;

import {Attestation} from "@eas/Common.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TopicPolicyBase} from "./TopicPolicyBase.sol";

/**
 * @title AccreditationPolicy
 * @author EEA Working Group
 * @notice ERC-3643 Topic 7 (ACCREDITATION) payload policy.
 * @dev The owner maintains an allow-list of accreditation types that satisfy the
 *      policy. Typical configurations:
 *        - Reg D 506(c): allow ACCREDITED (2), QUALIFIED_PURCHASER (3), INSTITUTIONAL (4).
 *        - QIB-only offering: allow INSTITUTIONAL (4) only.
 *        - MiFID II professional: allow RETAIL_QUALIFIED (1) upward.
 *      Ownership is single-key by design; the verifier that consumes this policy
 *      is the primary control plane and is under AccessControl. Ownership can be
 *      transferred to the same multisig as the verifier.
 */
contract AccreditationPolicy is TopicPolicyBase, Ownable {
    uint256 internal constant TOPIC_ACCREDITATION = 7;

    mapping(uint8 => bool) private _allowed;
    uint8[] private _allowedTypes;

    event AccreditationTypeAllowed(uint8 indexed accreditationType);
    event AccreditationTypeDisallowed(uint8 indexed accreditationType);

    constructor(address initialOwner, uint8[] memory initialAllowed)
        TopicPolicyBase(TOPIC_ACCREDITATION, "AccreditationPolicy")
        Ownable(initialOwner)
    {
        for (uint256 i = 0; i < initialAllowed.length; i++) {
            uint8 t = initialAllowed[i];
            if (!_allowed[t]) {
                _allowed[t] = true;
                _allowedTypes.push(t);
                emit AccreditationTypeAllowed(t);
            }
        }
    }

    function allow(uint8 accreditationType) external onlyOwner {
        if (_allowed[accreditationType]) return;
        _allowed[accreditationType] = true;
        _allowedTypes.push(accreditationType);
        emit AccreditationTypeAllowed(accreditationType);
    }

    function disallow(uint8 accreditationType) external onlyOwner {
        if (!_allowed[accreditationType]) return;
        _allowed[accreditationType] = false;
        uint256 len = _allowedTypes.length;
        for (uint256 i = 0; i < len; i++) {
            if (_allowedTypes[i] == accreditationType) {
                _allowedTypes[i] = _allowedTypes[len - 1];
                _allowedTypes.pop();
                break;
            }
        }
        emit AccreditationTypeDisallowed(accreditationType);
    }

    function isAllowed(uint8 accreditationType) external view returns (bool) {
        return _allowed[accreditationType];
    }

    function getAllowedTypes() external view returns (uint8[] memory) {
        return _allowedTypes;
    }

    function validate(Attestation calldata attestation) external view override returns (bool) {
        (bool ok, InvestorEligibility memory e) = _preflight(attestation.data);
        if (!ok) return false;
        return _allowed[e.accreditationType];
    }
}
