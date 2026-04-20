// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IEAS} from "@eas/IEAS.sol";
import {Attestation} from "@eas/Common.sol";
import {IEASTrustedIssuersAdapter} from "./interfaces/IEASTrustedIssuersAdapter.sol";

/**
 * @title EASTrustedIssuersAdapter
 * @author EEA Working Group
 * @notice Manages trusted EAS attesters for ERC-3643 compliance verification.
 * @dev Audit finding C-5: every `addTrustedAttester` / `updateAttesterTopics`
 *      call now requires an `authUID` pointing to a live Schema 2 (Issuer
 *      Authorization) attestation on EAS. The adapter verifies:
 *        - the attestation exists and has not been revoked,
 *        - its EAS-level expiration has not passed,
 *        - its schema UID matches the configured Issuer Authorization schema,
 *        - its decoded `issuerAddress` equals the attester being added,
 *        - every element of the passed `claimTopics` argument is a member of the
 *          decoded `authorizedTopics` (subset check).
 *      The schema itself is resolver-gated by `TrustedIssuerResolver`, so only
 *      admin-curated "authorizer" addresses can write the Schema-2 attestation
 *      in the first place. This turns trusted-attester admin actions into
 *      cryptographically-signed events with an on-chain audit trail.
 */
contract EASTrustedIssuersAdapter is IEASTrustedIssuersAdapter, AccessControl {
    // ============ Roles ============

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // ============ Constants ============

    uint256 public constant MAX_ATTESTERS = 50;
    uint256 public constant MAX_TOPICS_PER_ATTESTER = 15;
    uint256 public constant MAX_ATTESTERS_PER_TOPIC = 5;

    // ============ Storage ============

    address[] private _trustedAttesters;
    mapping(address => uint256[]) private _attesterClaimTopics;
    mapping(uint256 => address[]) private _claimTopicToAttesters;
    mapping(address => bool) private _isTrusted;
    mapping(address => mapping(uint256 => bool)) private _attesterTrustedForTopic;

    IEAS private _eas;
    bytes32 private _issuerAuthSchemaUID;

    // ============ Constructor ============

    constructor(address initialAdmin) {
        if (initialAdmin == address(0)) revert ZeroAddressNotAllowed();
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
        _grantRole(OPERATOR_ROLE, initialAdmin);
    }

    // ============ Admin config ============

    function setEASAddress(address easAddress) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (easAddress == address(0)) revert ZeroAddressNotAllowed();
        _eas = IEAS(easAddress);
    }

    function getEASAddress() external view override returns (address) {
        return address(_eas);
    }

    function setIssuerAuthSchemaUID(bytes32 schemaUID) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        _issuerAuthSchemaUID = schemaUID;
        emit IssuerAuthSchemaUIDSet(schemaUID);
    }

    function getIssuerAuthSchemaUID() external view override returns (bytes32) {
        return _issuerAuthSchemaUID;
    }

    // ============ Mutative ============

    function addTrustedAttester(address attester, uint256[] calldata claimTopics, bytes32 authUID)
        external
        override
        onlyRole(OPERATOR_ROLE)
    {
        if (attester == address(0)) revert ZeroAddressNotAllowed();
        if (_isTrusted[attester]) revert AttesterAlreadyTrusted(attester);
        if (claimTopics.length == 0) revert EmptyClaimTopics();
        if (_trustedAttesters.length >= MAX_ATTESTERS) revert("MaxAttestersReached");
        if (claimTopics.length > MAX_TOPICS_PER_ATTESTER) revert("MaxTopicsPerAttesterReached");

        _validateIssuerAuth(attester, claimTopics, authUID);

        _isTrusted[attester] = true;
        _trustedAttesters.push(attester);
        _attesterClaimTopics[attester] = claimTopics;

        for (uint256 i = 0; i < claimTopics.length; i++) {
            uint256 topic = claimTopics[i];
            if (_claimTopicToAttesters[topic].length >= MAX_ATTESTERS_PER_TOPIC) {
                revert("MaxAttestersPerTopicReached");
            }
            _claimTopicToAttesters[topic].push(attester);
            _attesterTrustedForTopic[attester][topic] = true;
        }

        emit TrustedAttesterAdded(attester, claimTopics);
    }

    function removeTrustedAttester(address attester) external override onlyRole(OPERATOR_ROLE) {
        if (!_isTrusted[attester]) revert AttesterNotTrusted(attester);

        uint256[] memory topics = _attesterClaimTopics[attester];
        for (uint256 i = 0; i < topics.length; i++) {
            uint256 topic = topics[i];
            _removeAttesterFromTopic(attester, topic);
            _attesterTrustedForTopic[attester][topic] = false;
        }

        _removeFromAttestersArray(attester);
        delete _attesterClaimTopics[attester];
        _isTrusted[attester] = false;

        emit TrustedAttesterRemoved(attester);
    }

    function updateAttesterTopics(address attester, uint256[] calldata claimTopics, bytes32 authUID)
        external
        override
        onlyRole(OPERATOR_ROLE)
    {
        if (!_isTrusted[attester]) revert AttesterNotTrusted(attester);
        if (claimTopics.length == 0) revert EmptyClaimTopics();
        if (claimTopics.length > MAX_TOPICS_PER_ATTESTER) revert("MaxTopicsPerAttesterReached");

        _validateIssuerAuth(attester, claimTopics, authUID);

        uint256[] memory oldTopics = _attesterClaimTopics[attester];
        for (uint256 i = 0; i < oldTopics.length; i++) {
            uint256 topic = oldTopics[i];
            _removeAttesterFromTopic(attester, topic);
            _attesterTrustedForTopic[attester][topic] = false;
        }

        _attesterClaimTopics[attester] = claimTopics;
        for (uint256 i = 0; i < claimTopics.length; i++) {
            uint256 topic = claimTopics[i];
            if (_claimTopicToAttesters[topic].length >= MAX_ATTESTERS_PER_TOPIC) {
                revert("MaxAttestersPerTopicReached");
            }
            _claimTopicToAttesters[topic].push(attester);
            _attesterTrustedForTopic[attester][topic] = true;
        }

        emit AttesterTopicsUpdated(attester, claimTopics);
    }

    // ============ Views ============

    function isAttesterTrusted(address attester, uint256 claimTopic) external view override returns (bool) {
        return _attesterTrustedForTopic[attester][claimTopic];
    }

    function getTrustedAttestersForTopic(uint256 claimTopic) external view override returns (address[] memory) {
        return _claimTopicToAttesters[claimTopic];
    }

    function getAttesterTopics(address attester) external view override returns (uint256[] memory) {
        return _attesterClaimTopics[attester];
    }

    function getTrustedAttesters() external view override returns (address[] memory) {
        return _trustedAttesters;
    }

    function isTrustedAttester(address attester) external view override returns (bool) {
        return _isTrusted[attester];
    }

    // ============ Internal ============

    function _validateIssuerAuth(address attester, uint256[] calldata claimTopics, bytes32 authUID) internal view {
        if (address(_eas) == address(0)) revert EASNotConfigured();
        if (_issuerAuthSchemaUID == bytes32(0)) revert IssuerAuthSchemaUIDNotSet();

        Attestation memory att = _eas.getAttestation(authUID);
        if (att.uid == bytes32(0)) revert IssuerAuthAttestationMissing();
        if (att.schema != _issuerAuthSchemaUID) revert IssuerAuthAttestationMissing();
        if (att.revocationTime != 0) revert IssuerAuthAttestationMissing();
        if (att.expirationTime != 0 && att.expirationTime <= block.timestamp) revert IssuerAuthAttestationMissing();

        (address authIssuer, uint256[] memory authorizedTopics,) = abi.decode(att.data, (address, uint256[], string));

        if (authIssuer != attester) revert IssuerAuthRecipientMismatch();

        for (uint256 i = 0; i < claimTopics.length; i++) {
            bool found = false;
            for (uint256 j = 0; j < authorizedTopics.length; j++) {
                if (authorizedTopics[j] == claimTopics[i]) {
                    found = true;
                    break;
                }
            }
            if (!found) revert IssuerAuthTopicsNotAuthorized();
        }
    }

    function _removeAttesterFromTopic(address attester, uint256 topic) internal {
        address[] storage attesters = _claimTopicToAttesters[topic];
        uint256 length = attesters.length;
        for (uint256 i = 0; i < length; i++) {
            if (attesters[i] == attester) {
                attesters[i] = attesters[length - 1];
                attesters.pop();
                break;
            }
        }
    }

    function _removeFromAttestersArray(address attester) internal {
        uint256 length = _trustedAttesters.length;
        for (uint256 i = 0; i < length; i++) {
            if (_trustedAttesters[i] == attester) {
                _trustedAttesters[i] = _trustedAttesters[length - 1];
                _trustedAttesters.pop();
                break;
            }
        }
    }
}
