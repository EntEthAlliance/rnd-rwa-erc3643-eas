// SPDX-License-Identifier: Apache-2.0
// Copyright © 2026 Enterprise Ethereum Alliance Inc.
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {EASClaimVerifier} from "../contracts/EASClaimVerifier.sol";

/**
 * @title SeedDemoRegister
 * @notice Step 2b of demo seeding: registers previously-minted EAS attestation
 *         UIDs with the verifier for each demo investor and topic.
 *
 *         Run after SeedDemoAttest.s.sol. Get the UIDs from the Attested event
 *         logs of those three transactions, then set:
 *
 *           ALICE_UID=0x...  BOB_UID=0x...  CAROL_UID=0x...
 *
 *         Required env:
 *           PRIVATE_KEY
 *           VERIFIER_ADDRESS
 *           ALICE_WALLET / BOB_WALLET / CAROL_WALLET (or defaults)
 *           ALICE_UID / BOB_UID / CAROL_UID
 */
contract SeedDemoRegister is Script {
    uint256 constant TOPIC_KYC            = 1;
    uint256 constant TOPIC_AML            = 2;
    uint256 constant TOPIC_COUNTRY        = 3;
    uint256 constant TOPIC_ACCREDITATION  = 7;
    uint256 constant TOPIC_SANCTIONS      = 13;
    uint256 constant TOPIC_SOURCE_OF_FUNDS = 14;

    function run() external {
        uint256 key = vm.envUint("PRIVATE_KEY");

        EASClaimVerifier verifier = EASClaimVerifier(vm.envAddress("VERIFIER_ADDRESS"));

        address alice = vm.envOr("ALICE_WALLET", vm.addr(uint256(keccak256("shibui.demo.alice"))));
        address bob   = vm.envOr("BOB_WALLET",   vm.addr(uint256(keccak256("shibui.demo.bob"))));
        address carol = vm.envOr("CAROL_WALLET",  vm.addr(uint256(keccak256("shibui.demo.carol"))));

        bytes32 aliceUID = vm.envBytes32("ALICE_UID");
        bytes32 bobUID   = vm.envBytes32("BOB_UID");
        bytes32 carolUID = vm.envBytes32("CAROL_UID");

        uint256[] memory topics = new uint256[](6);
        topics[0] = TOPIC_KYC;
        topics[1] = TOPIC_AML;
        topics[2] = TOPIC_COUNTRY;
        topics[3] = TOPIC_ACCREDITATION;
        topics[4] = TOPIC_SANCTIONS;
        topics[5] = TOPIC_SOURCE_OF_FUNDS;

        vm.startBroadcast(key);

        _register(verifier, alice, topics, aliceUID, "alice");
        _register(verifier, bob,   topics, bobUID,   "bob");
        _register(verifier, carol, topics, carolUID,  "carol");

        vm.stopBroadcast();

        console2.log("=== Registration complete ===");
        console2.log("alice verified:", verifier.isVerified(alice));
        console2.log("bob verified (expect false):", verifier.isVerified(bob));
        console2.log("carol verified:", verifier.isVerified(carol));
    }

    function _register(
        EASClaimVerifier verifier,
        address wallet,
        uint256[] memory topics,
        bytes32 uid,
        string memory label
    ) internal {
        for (uint256 i = 0; i < topics.length; i++) {
            verifier.registerAttestation(wallet, topics[i], uid);
        }
        console2.log("Registered:", label, wallet);
    }
}
