// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract IdentityMappingOrbital is Ownable {
    string public constant ORBITAL_ID = "identity-mapping";
    string public constant ORBITAL_VERSION = "0.2.0-phase1";
    bytes32 public constant STORAGE_SLOT = keccak256("eea.valence.orbital.identity-mapping.storage.v1");

    struct ModuleMetadata {
        string id;
        string version;
        bytes32 storageSlot;
    }

    mapping(address => address) private _walletToIdentity;

    event WalletIdentitySet(address indexed wallet, address indexed identity);

    constructor(address initialOwner) Ownable(initialOwner) {}

    function moduleMetadata() external pure returns (ModuleMetadata memory) {
        return ModuleMetadata({id: ORBITAL_ID, version: ORBITAL_VERSION, storageSlot: STORAGE_SLOT});
    }

    function exportedSelectors() external pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](2);
        selectors[0] = this.setIdentity.selector;
        selectors[1] = this.getIdentity.selector;
    }

    function setIdentity(address wallet, address identity) external onlyOwner {
        require(wallet != address(0), "wallet=0");
        require(identity != address(0), "identity=0");
        _walletToIdentity[wallet] = identity;
        emit WalletIdentitySet(wallet, identity);
    }

    function getIdentity(address wallet) external view returns (address) {
        address identity = _walletToIdentity[wallet];
        return identity == address(0) ? wallet : identity;
    }
}
