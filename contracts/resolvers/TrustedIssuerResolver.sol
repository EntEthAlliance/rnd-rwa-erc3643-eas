// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IEAS} from "@eas/IEAS.sol";
import {Attestation} from "@eas/Common.sol";
import {SchemaResolver} from "@eas/resolver/SchemaResolver.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TrustedIssuerResolver
 * @author EEA Working Group
 * @notice EAS schema resolver that gates writes of the Issuer Authorization
 *         (Schema 2) attestations to an admin-curated set of "authorizers".
 * @dev Purpose (addresses audit finding C-5): Issuer Authorization attestations
 *      become the cryptographic audit trail backing the
 *      `EASTrustedIssuersAdapter.addTrustedAttester(attester, topics, authUID)`
 *      call. Without this resolver, anyone could create a Schema-2 attestation
 *      and the adapter's `authUID` check would be meaningless. With it, only
 *      addresses in `_isAuthorizer` can produce a Schema-2 attestation that
 *      EAS will accept.
 *
 *      Schema 2 string:
 *        address issuerAddress, uint256[] authorizedTopics, string issuerName
 *
 *      Typical authorizer roster: the token issuer's compliance multisig, plus
 *      any federated KYC-provider-coordination body the issuer recognises.
 *
 *      Revocations are forwarded unchanged — EAS already enforces that only the
 *      original attester can revoke their own attestation.
 */
contract TrustedIssuerResolver is SchemaResolver, Ownable {
    // ============ Storage ============

    mapping(address => bool) private _isAuthorizer;
    address[] private _authorizers;

    // ============ Events ============

    event AuthorizerAdded(address indexed authorizer);
    event AuthorizerRemoved(address indexed authorizer);

    // ============ Errors ============

    error ZeroAddressNotAllowed();

    // ============ Constructor ============

    /**
     * @param eas The EAS contract instance that will call this resolver.
     * @param initialOwner Initial owner (expected to be the token-issuer multisig).
     * @param initialAuthorizers Bootstrap authorizer set (may be empty — owner can add later).
     */
    constructor(IEAS eas, address initialOwner, address[] memory initialAuthorizers)
        SchemaResolver(eas)
        Ownable(initialOwner)
    {
        for (uint256 i = 0; i < initialAuthorizers.length; i++) {
            address a = initialAuthorizers[i];
            if (a == address(0)) revert ZeroAddressNotAllowed();
            if (!_isAuthorizer[a]) {
                _isAuthorizer[a] = true;
                _authorizers.push(a);
                emit AuthorizerAdded(a);
            }
        }
    }

    // ============ Admin ============

    function addAuthorizer(address authorizer) external onlyOwner {
        if (authorizer == address(0)) revert ZeroAddressNotAllowed();
        if (_isAuthorizer[authorizer]) return;
        _isAuthorizer[authorizer] = true;
        _authorizers.push(authorizer);
        emit AuthorizerAdded(authorizer);
    }

    function removeAuthorizer(address authorizer) external onlyOwner {
        if (!_isAuthorizer[authorizer]) return;
        _isAuthorizer[authorizer] = false;
        uint256 len = _authorizers.length;
        for (uint256 i = 0; i < len; i++) {
            if (_authorizers[i] == authorizer) {
                _authorizers[i] = _authorizers[len - 1];
                _authorizers.pop();
                break;
            }
        }
        emit AuthorizerRemoved(authorizer);
    }

    // ============ Views ============

    function isAuthorizer(address account) external view returns (bool) {
        return _isAuthorizer[account];
    }

    function getAuthorizers() external view returns (address[] memory) {
        return _authorizers;
    }

    // ============ Resolver hooks ============

    /// @inheritdoc SchemaResolver
    function onAttest(
        Attestation calldata attestation,
        uint256 /*value*/
    )
        internal
        view
        override
        returns (bool)
    {
        return _isAuthorizer[attestation.attester];
    }

    /// @inheritdoc SchemaResolver
    function onRevoke(
        Attestation calldata,
        /*attestation*/
        uint256 /*value*/
    )
        internal
        pure
        override
        returns (bool)
    {
        // EAS already enforces that only the original attester can revoke.
        return true;
    }
}
