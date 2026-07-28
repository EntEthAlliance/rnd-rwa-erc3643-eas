// SPDX-License-Identifier: Apache-2.0
// Copyright © 2026 Enterprise Ethereum Alliance Inc.
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {EASClaimVerifier} from "../contracts/EASClaimVerifier.sol";
import {IClaimTopicsRegistry} from "../contracts/interfaces/IClaimTopicsRegistry.sol";

/**
 * @title VerifyDeployment
 * @notice Read-only smoke test for a deployed Shibui stack. Fails loudly if
 *         the verifier is deployed but not functional.
 *
 * @dev Motivation: the 2026-07-17 Sepolia deployment shipped with
 *      `getEASAddress()`, `getTrustedIssuersAdapter()`, `getIdentityProxy()`,
 *      and `getClaimTopicsRegistry()` all returning `address(0)` — every
 *      `isVerified()` call reverted. This script makes that state impossible
 *      to miss: run it after any deploy or reconfiguration, and wire it into
 *      CI against `deployments/<network>.json`.
 *
 *      Checks, in order:
 *        1. All four verifier dependencies are non-zero.
 *        2. The claim topics registry requires at least one topic (an empty
 *           registry makes `isVerified()` return true for everyone —
 *           fail-open; see the PR discussion on making this fail-closed
 *           on-chain).
 *        3. Every required topic has a schema mapping and a policy bound.
 *        4. `isVerified()` on a throwaway address executes without reverting
 *           and returns false — proof the full read path (proxy -> registry ->
 *           adapter -> EAS) is traversable.
 *
 *      Required env:
 *        VERIFIER_ADDRESS — EASClaimVerifier (or its proxy)
 *
 *      Usage (no broadcast — pure reads):
 *        VERIFIER_ADDRESS=0x... forge script script/VerifyDeployment.s.sol \
 *          --rpc-url $RPC_SEPOLIA
 */
contract VerifyDeployment is Script {
    address constant PROBE = 0x000000000000000000000000000000000000dEaD;

    function run() external view {
        EASClaimVerifier verifier = EASClaimVerifier(vm.envAddress("VERIFIER_ADDRESS"));

        console2.log("=== Shibui deployment smoke test ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("Verifier:", address(verifier));

        // 1. Dependency wiring
        address eas = verifier.getEASAddress();
        address adapter = verifier.getTrustedIssuersAdapter();
        address proxy = verifier.getIdentityProxy();
        address registry = verifier.getClaimTopicsRegistry();

        require(eas != address(0), "FAIL: EAS address not set (setEASAddress)");
        require(adapter != address(0), "FAIL: trusted issuers adapter not set (setTrustedIssuersAdapter)");
        require(proxy != address(0), "FAIL: identity proxy not set (setIdentityProxy)");
        require(registry != address(0), "FAIL: claim topics registry not set (setClaimTopicsRegistry)");
        console2.log("PASS: all four verifier dependencies wired");
        console2.log("  EAS:     ", eas);
        console2.log("  Adapter: ", adapter);
        console2.log("  Proxy:   ", proxy);
        console2.log("  Registry:", registry);

        // 2. Required topics present
        uint256[] memory topics = IClaimTopicsRegistry(registry).getClaimTopics();
        require(
            topics.length > 0,
            "FAIL: claim topics registry is empty - isVerified() would return true for every wallet (fail-open)"
        );
        console2.log("PASS: required topics:", topics.length);

        // 3. Per-topic schema + policy bindings
        for (uint256 i = 0; i < topics.length; i++) {
            uint256 topic = topics[i];
            require(verifier.getSchemaUID(topic) != bytes32(0), "FAIL: required topic missing schema mapping");
            require(verifier.getTopicPolicy(topic) != address(0), "FAIL: required topic missing policy binding");
            console2.log("PASS: topic bound (schema + policy):", topic);
        }

        // 4. Full read path traversable
        bool probeVerified = verifier.isVerified(PROBE);
        require(!probeVerified, "FAIL: probe address unexpectedly verified");
        console2.log("PASS: isVerified() traversed full path, probe correctly unverified");

        console2.log("");
        console2.log("=== Smoke test passed ===");
    }
}
