// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract TrustedAttestersOrbital is Ownable {
    string public constant ORBITAL_ID = "trusted-attesters";
    string public constant ORBITAL_VERSION = "0.2.0-phase1";
    bytes32 public constant STORAGE_SLOT = keccak256("eea.valence.orbital.trusted-attesters.storage.v1");

    struct ModuleMetadata {
        string id;
        string version;
        bytes32 storageSlot;
    }

    mapping(uint256 => mapping(address => bool)) private _trustedByTopic;
    mapping(uint256 => address[]) private _topicAttesters;

    event TrustedAttesterSet(uint256 indexed topic, address indexed attester, bool trusted);

    constructor(address initialOwner) Ownable(initialOwner) {}

    function moduleMetadata() external pure returns (ModuleMetadata memory) {
        return ModuleMetadata({id: ORBITAL_ID, version: ORBITAL_VERSION, storageSlot: STORAGE_SLOT});
    }

    function exportedSelectors() external pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](3);
        selectors[0] = this.setTrustedAttester.selector;
        selectors[1] = this.isAttesterTrusted.selector;
        selectors[2] = this.getTrustedAttestersForTopic.selector;
    }

    function setTrustedAttester(uint256 claimTopic, address attester, bool trusted) external onlyOwner {
        require(attester != address(0), "attester=0");

        bool current = _trustedByTopic[claimTopic][attester];
        if (current == trusted) return;

        _trustedByTopic[claimTopic][attester] = trusted;

        if (trusted) {
            _topicAttesters[claimTopic].push(attester);
        }

        emit TrustedAttesterSet(claimTopic, attester, trusted);
    }

    function isAttesterTrusted(address attester, uint256 claimTopic) external view returns (bool) {
        return _trustedByTopic[claimTopic][attester];
    }

    function getTrustedAttestersForTopic(uint256 claimTopic) external view returns (address[] memory out) {
        address[] memory all = _topicAttesters[claimTopic];
        uint256 n;

        for (uint256 i = 0; i < all.length; i++) {
            if (_trustedByTopic[claimTopic][all[i]]) n++;
        }

        out = new address[](n);
        uint256 j;
        for (uint256 i = 0; i < all.length; i++) {
            if (_trustedByTopic[claimTopic][all[i]]) {
                out[j++] = all[i];
            }
        }
    }
}
