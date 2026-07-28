// SPDX-License-Identifier: Apache-2.0
// Copyright © 2026 Enterprise Ethereum Alliance Inc.
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IEAS, AttestationRequest, AttestationRequestData} from "@eas/IEAS.sol";

import {EASClaimVerifier} from "../contracts/EASClaimVerifier.sol";
import {EASTrustedIssuersAdapter} from "../contracts/EASTrustedIssuersAdapter.sol";
import {TrustedIssuerResolver} from "../contracts/resolvers/TrustedIssuerResolver.sol";
import {AccreditationPolicy} from "../contracts/policies/AccreditationPolicy.sol";

/**
 * @title SeedDemo
 * @notice Seeds the three demo investors on REAL EAS (Sepolia / Base Sepolia)
 *         so the demo UI has live data. Previously only `SetupPilot` existed,
 *         which targets MockEAS on anvil — the real-network path was manual.
 *
 *         Investors (matching deployments/sepolia.json#demo):
 *           Alice — fully verified: transfers clear
 *           Bob   — accreditationType = 0: ACCREDITATION topic fails, blocked
 *           Carol — fully verified; revoke live during the demo with:
 *                   cast send $EAS "revoke(((bytes32),(bytes32,uint256)))" ...
 *                   (Carol's attestation UID is printed at the end)
 *
 * @dev Single-key testnet model: the broadcaster acts as authorizer, KYC
 *      attester, adapter operator, and identity-proxy agent — consistent with
 *      DeployTestnet's stated single-admin design. NOT for mainnet.
 *
 *      Idempotent per step: authorizer registration, trusted-attester add, and
 *      wallet bindings are skipped when already present. Attestations are
 *      re-issued on every run (each run prints fresh UIDs).
 *
 *      Required env:
 *        PRIVATE_KEY                     — admin key (all roles)
 *        VERIFIER_ADDRESS                — EASClaimVerifier
 *        ADAPTER_ADDRESS                 — EASTrustedIssuersAdapter
 *        RESOLVER_ADDRESS                — TrustedIssuerResolver
 *        ACCREDITATION_POLICY            — AccreditationPolicy (admin-owned)
 *        INVESTOR_ELIGIBILITY_SCHEMA_UID — real EAS schema UID
 *        ISSUER_AUTHORIZATION_SCHEMA_UID — real EAS schema UID
 *
 *      Optional env:
 *        EAS_ADDRESS                     — auto-detected if unset
 *        ALICE_WALLET/BOB_WALLET/CAROL_WALLET — default to derived addresses
 */
contract SeedDemo is Script {
    address constant EAS_SEPOLIA = 0xC2679fBD37d54388Ce493F1DB75320D236e1815e;
    address constant EAS_BASE_SEPOLIA = 0x4200000000000000000000000000000000000021;

    uint256 constant TOPIC_KYC = 1;
    uint256 constant TOPIC_AML = 2;
    uint256 constant TOPIC_COUNTRY = 3;
    uint256 constant TOPIC_ACCREDITATION = 7;
    uint256 constant TOPIC_SANCTIONS = 13;
    uint256 constant TOPIC_SOURCE_OF_FUNDS = 14;

    function run() external {
        uint256 key = vm.envUint("PRIVATE_KEY");
        address admin = vm.addr(key);

        EASClaimVerifier verifier = EASClaimVerifier(vm.envAddress("VERIFIER_ADDRESS"));
        EASTrustedIssuersAdapter adapter = EASTrustedIssuersAdapter(vm.envAddress("ADAPTER_ADDRESS"));
        TrustedIssuerResolver resolver = TrustedIssuerResolver(payable(vm.envAddress("RESOLVER_ADDRESS")));
        AccreditationPolicy accreditationPolicy = AccreditationPolicy(vm.envAddress("ACCREDITATION_POLICY"));

        address easAddress = vm.envOr("EAS_ADDRESS", address(0));
        if (easAddress == address(0)) easAddress = _getEAS();
        IEAS eas = IEAS(easAddress);

        bytes32 invSchema = vm.envBytes32("INVESTOR_ELIGIBILITY_SCHEMA_UID");
        bytes32 authSchema = vm.envBytes32("ISSUER_AUTHORIZATION_SCHEMA_UID");

        address alice = vm.envOr("ALICE_WALLET", vm.addr(uint256(keccak256("shibui.demo.alice"))));
        address bob = vm.envOr("BOB_WALLET", vm.addr(uint256(keccak256("shibui.demo.bob"))));
        address carol = vm.envOr("CAROL_WALLET", vm.addr(uint256(keccak256("shibui.demo.carol"))));

        vm.startBroadcast(key);

        // --- 0. Accreditation allow-set: DeployTestnet ships it empty, which
        //        would fail even Alice on topic 7. Allow ACCREDITED (2). ---
        if (!accreditationPolicy.isAllowed(2)) {
            accreditationPolicy.allow(2);
            console2.log("AccreditationPolicy: allowed type 2 (ACCREDITED)");
        }

        // --- 1. Admin becomes a Schema-2 authorizer (resolver gate, audit C-5) ---
        if (!resolver.isAuthorizer(admin)) {
            resolver.addAuthorizer(admin);
            console2.log("Authorizer registered:", admin);
        }

        // --- 2. Admin self-authorizes as the demo KYC attester on real EAS ---
        uint256[] memory topics = new uint256[](6);
        topics[0] = TOPIC_KYC;
        topics[1] = TOPIC_AML;
        topics[2] = TOPIC_COUNTRY;
        topics[3] = TOPIC_ACCREDITATION;
        topics[4] = TOPIC_SANCTIONS;
        topics[5] = TOPIC_SOURCE_OF_FUNDS;

        if (!adapter.isAttesterTrusted(admin, TOPIC_KYC)) {
            bytes32 authUID = eas.attest(
                AttestationRequest({
                    schema: authSchema,
                    data: AttestationRequestData({
                        recipient: admin,
                        expirationTime: 0,
                        revocable: true,
                        refUID: bytes32(0),
                        data: abi.encode(admin, topics, "Shibui Demo KYC"),
                        value: 0
                    })
                })
            );
            adapter.addTrustedAttester(admin, topics, authUID);
            console2.log("Trusted attester added (Schema-2 UID):");
            console2.logBytes32(authUID);
        }

        // --- 3. Seed the three investors ---
        // accreditationType 2 = ACCREDITED, 0 = none (Bob's failing field).
        bytes32 aliceUID = _seedInvestor(eas, verifier, invSchema, topics, alice, "alice", 2);
        bytes32 bobUID = _seedInvestor(eas, verifier, invSchema, topics, bob, "bob", 0);
        bytes32 carolUID = _seedInvestor(eas, verifier, invSchema, topics, carol, "carol", 2);

        vm.stopBroadcast();

        console2.log("");
        console2.log("=== Demo seeded - paste into deployments/sepolia.json#demo ===");
        console2.log("alice wallet:", alice);
        console2.log("alice UID:");
        console2.logBytes32(aliceUID);
        console2.log("alice verified:", verifier.isVerified(alice));
        console2.log("bob wallet:", bob);
        console2.log("bob UID:");
        console2.logBytes32(bobUID);
        console2.log("bob verified (expect false):", verifier.isVerified(bob));
        console2.log("carol wallet:", carol);
        console2.log("carol UID (revoke this live in the demo):");
        console2.logBytes32(carolUID);
        console2.log("carol verified:", verifier.isVerified(carol));
    }

    /// @dev Identity = wallet. EASIdentityProxy.getIdentity falls back to the
    ///      wallet itself for unregistered wallets, so no proxy registration
    ///      is needed for the self-identity demo model.
    function _seedInvestor(
        IEAS eas,
        EASClaimVerifier verifier,
        bytes32 invSchema,
        uint256[] memory topics,
        address wallet,
        string memory label,
        uint8 accreditationType
    ) internal returns (bytes32 uid) {
        uid = eas.attest(
            AttestationRequest({
                schema: invSchema,
                data: AttestationRequestData({
                    recipient: wallet,
                    expirationTime: 0,
                    revocable: true,
                    refUID: bytes32(0),
                    data: abi.encode(
                        wallet, // identity
                        uint8(1), // kycStatus = VERIFIED
                        uint8(0), // amlStatus = CLEAR
                        uint8(0), // sanctionsStatus = CLEAR
                        uint8(1), // sourceOfFundsStatus = VERIFIED
                        accreditationType,
                        uint16(840), // US
                        uint64(block.timestamp + 365 days),
                        keccak256(abi.encodePacked("demo-evidence-", label)),
                        uint8(2) // verificationMethod = third-party
                    ),
                    value: 0
                })
            })
        );

        // Register the same attestation for every required topic.
        for (uint256 i = 0; i < topics.length; i++) {
            verifier.registerAttestation(wallet, topics[i], uid);
        }
        console2.log("Seeded investor:", label, wallet);
    }

    function _getEAS() internal view returns (address) {
        if (block.chainid == 11155111) return EAS_SEPOLIA;
        if (block.chainid == 84532) return EAS_BASE_SEPOLIA;
        revert("EAS_ADDRESS required for this network");
    }
}
