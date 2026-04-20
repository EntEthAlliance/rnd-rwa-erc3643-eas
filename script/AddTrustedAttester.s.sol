// SPDX-License-Identifier: Apache-2.0
// Copyright © 2026 Enterprise Ethereum Alliance Inc.
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {EASTrustedIssuersAdapter} from "../contracts/EASTrustedIssuersAdapter.sol";

/**
 * @title AddTrustedAttester
 * @notice CLI helper that invokes `addTrustedAttester(attester, topics, authUID)`.
 * @dev Fails with a clear message if `AUTH_UID` is missing — audit fix C-5
 *      requires every trusted-attester add to reference a live Schema-2
 *      (Issuer Authorization) attestation.
 *
 *      Required env:
 *        PRIVATE_KEY        — operator key
 *        ADAPTER_ADDRESS    — EASTrustedIssuersAdapter
 *        ATTESTER_ADDRESS   — the attester being added
 *        TOPICS             — comma-separated topic IDs, e.g. "1,3,7"
 *        AUTH_UID           — bytes32 Schema-2 attestation UID
 */
contract AddTrustedAttester is Script {
    function run() external {
        uint256 key = vm.envUint("PRIVATE_KEY");
        EASTrustedIssuersAdapter adapter = EASTrustedIssuersAdapter(vm.envAddress("ADAPTER_ADDRESS"));
        address attester = vm.envAddress("ATTESTER_ADDRESS");
        bytes32 authUID = vm.envBytes32("AUTH_UID");
        require(authUID != bytes32(0), "AUTH_UID env var required (audit C-5; see RegisterSchemas + Schema 2 flow)");

        string memory topicsRaw = vm.envString("TOPICS");
        uint256[] memory topics = _parseTopics(topicsRaw);
        require(topics.length > 0, "TOPICS env var required (e.g. '1,3,7')");

        console2.log("=== Add Trusted Attester ===");
        console2.log("Adapter:", address(adapter));
        console2.log("Attester:", attester);
        console2.log("Topics:");
        for (uint256 i = 0; i < topics.length; i++) {
            console2.log("  -", topics[i]);
        }
        console2.log("AUTH_UID:");
        console2.logBytes32(authUID);

        vm.startBroadcast(key);
        adapter.addTrustedAttester(attester, topics, authUID);
        vm.stopBroadcast();

        console2.log("Attester added successfully.");
    }

    /// @notice Parses a comma-separated list like "1,3,7" into a uint256[].
    function _parseTopics(string memory raw) internal pure returns (uint256[] memory) {
        bytes memory b = bytes(raw);
        if (b.length == 0) return new uint256[](0);

        uint256 count = 1;
        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] == ",") count++;
        }

        uint256[] memory result = new uint256[](count);
        uint256 idx = 0;
        uint256 acc = 0;
        bool hasDigit = false;

        for (uint256 i = 0; i <= b.length; i++) {
            bytes1 ch = i < b.length ? b[i] : bytes1(",");
            if (ch == ",") {
                require(hasDigit, "TOPICS malformed (empty segment)");
                result[idx++] = acc;
                acc = 0;
                hasDigit = false;
            } else {
                require(ch >= 0x30 && ch <= 0x39, "TOPICS must be digits and commas");
                acc = acc * 10 + (uint8(ch) - 0x30);
                hasDigit = true;
            }
        }

        return result;
    }
}
