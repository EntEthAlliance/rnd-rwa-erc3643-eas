// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IERC734
 * @notice ERC-734 Key Holder interface
 * @dev Compatible re-declaration for Solidity 0.8.24
 */
interface IERC734 {
    event KeyAdded(bytes32 indexed key, uint256 indexed purpose, uint256 indexed keyType);
    event KeyRemoved(bytes32 indexed key, uint256 indexed purpose, uint256 indexed keyType);
    event ExecutionRequested(uint256 indexed executionId, address indexed to, uint256 indexed value, bytes data);
    event Executed(uint256 indexed executionId, address indexed to, uint256 indexed value, bytes data);
    event Approved(uint256 indexed executionId, bool approved);

    function addKey(bytes32 _key, uint256 _purpose, uint256 _keyType) external returns (bool success);
    function removeKey(bytes32 _key, uint256 _purpose) external returns (bool success);
    function execute(address _to, uint256 _value, bytes calldata _data) external returns (uint256 executionId);
    function approve(uint256 _id, bool _approve) external returns (bool success);
    function getKey(bytes32 _key) external view returns (uint256[] memory purposes, uint256 keyType, bytes32 key);
    function keyHasPurpose(bytes32 _key, uint256 _purpose) external view returns (bool exists);
    function getKeysByPurpose(uint256 _purpose) external view returns (bytes32[] memory keys);
}

/**
 * @title IERC735
 * @notice ERC-735 Claim Holder interface
 * @dev Compatible re-declaration for Solidity 0.8.24
 */
interface IERC735 {
    event ClaimAdded(
        bytes32 indexed claimId,
        uint256 indexed topic,
        uint256 scheme,
        address indexed issuer,
        bytes signature,
        bytes data,
        string uri
    );

    event ClaimRemoved(
        bytes32 indexed claimId,
        uint256 indexed topic,
        uint256 scheme,
        address indexed issuer,
        bytes signature,
        bytes data,
        string uri
    );

    event ClaimChanged(
        bytes32 indexed claimId,
        uint256 indexed topic,
        uint256 scheme,
        address indexed issuer,
        bytes signature,
        bytes data,
        string uri
    );

    function addClaim(
        uint256 _topic,
        uint256 _scheme,
        address issuer,
        bytes calldata _signature,
        bytes calldata _data,
        string calldata _uri
    ) external returns (bytes32 claimRequestId);

    function removeClaim(bytes32 _claimId) external returns (bool success);

    function getClaim(bytes32 _claimId)
        external
        view
        returns (
            uint256 topic,
            uint256 scheme,
            address issuer,
            bytes memory signature,
            bytes memory data,
            string memory uri
        );

    function getClaimIdsByTopic(uint256 _topic) external view returns (bytes32[] memory claimIds);
}

/**
 * @title IIdentity
 * @notice Combined ERC-734 + ERC-735 identity interface
 * @dev Compatible re-declaration for Solidity 0.8.24
 */
interface IIdentity is IERC734, IERC735 {
    function isClaimValid(
        IIdentity _identity,
        uint256 claimTopic,
        bytes calldata sig,
        bytes calldata data
    ) external view returns (bool);
}
