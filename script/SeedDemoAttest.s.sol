// SPDX-License-Identifier: Apache-2.0
// Copyright © 2026 Enterprise Ethereum Alliance Inc.
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IEAS, AttestationRequest, AttestationRequestData} from "@eas/IEAS.sol";

/**
 * @title SeedDemoAttest
 * @notice Step 2a of demo seeding: mints one InvestorEligibility attestation
 *         per demo investor on real EAS. Does NOT call registerAttestation
 *         because the simulation UID ≠ the on-chain UID (EAS uses a global
 *         counter). Run SeedDemoRegister.s.sol after this with the UIDs from
 *         this script's tx logs.
 *
 *         Required env:
 *           PRIVATE_KEY
 *           EAS_ADDRESS
 *           INVESTOR_ELIGIBILITY_SCHEMA_UID
 *           ALICE_WALLET / BOB_WALLET / CAROL_WALLET (or defaults)
 */
contract SeedDemoAttest is Script {
    function run() external {
        uint256 key = vm.envUint("PRIVATE_KEY");

        address easAddress = vm.envAddress("EAS_ADDRESS");
        IEAS eas = IEAS(easAddress);

        bytes32 invSchema = vm.envBytes32("INVESTOR_ELIGIBILITY_SCHEMA_UID");

        address alice = vm.envOr("ALICE_WALLET", vm.addr(uint256(keccak256("shibui.demo.alice"))));
        address bob   = vm.envOr("BOB_WALLET",   vm.addr(uint256(keccak256("shibui.demo.bob"))));
        address carol = vm.envOr("CAROL_WALLET",  vm.addr(uint256(keccak256("shibui.demo.carol"))));

        vm.startBroadcast(key);

        _attest(eas, invSchema, alice, "alice", 2);
        _attest(eas, invSchema, bob,   "bob",   0);
        _attest(eas, invSchema, carol, "carol", 2);

        vm.stopBroadcast();

        console2.log("alice:", alice);
        console2.log("bob:  ", bob);
        console2.log("carol:", carol);
        console2.log("=> Parse UIDs from the 3 Attested events above, then run SeedDemoRegister.s.sol");
    }

    function _attest(IEAS eas, bytes32 schema, address wallet, string memory label, uint8 accreditationType)
        internal
    {
        eas.attest(
            AttestationRequest({
                schema: schema,
                data: AttestationRequestData({
                    recipient: wallet,
                    expirationTime: 0,
                    revocable: true,
                    refUID: bytes32(0),
                    data: abi.encode(
                        wallet,
                        uint8(1),  // kycStatus = VERIFIED
                        uint8(0),  // amlStatus = CLEAR
                        uint8(0),  // sanctionsStatus = CLEAR
                        uint8(1),  // sourceOfFundsStatus = VERIFIED
                        accreditationType,
                        uint16(840), // US
                        uint64(block.timestamp + 365 days),
                        keccak256(abi.encodePacked("demo-evidence-", label)),
                        uint8(2)   // verificationMethod = third-party
                    ),
                    value: 0
                })
            })
        );
        console2.log("Attested for:", label, wallet);
    }
}
