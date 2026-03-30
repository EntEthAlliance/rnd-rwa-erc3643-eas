// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {EASTrustedIssuersAdapter} from "../contracts/EASTrustedIssuersAdapter.sol";

/**
 * @title AddTrustedAttester
 * @notice Script to add a trusted attester to the adapter
 * @dev Run with: forge script script/AddTrustedAttester.s.sol --rpc-url $RPC_URL --broadcast
 */
contract AddTrustedAttester is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address adapterAddress = vm.envAddress("ADAPTER_ADDRESS");
        address attesterAddress = vm.envAddress("ATTESTER_ADDRESS");
        string memory topicsStr = vm.envString("TOPICS"); // Comma-separated: "1,7,3"

        EASTrustedIssuersAdapter adapter = EASTrustedIssuersAdapter(adapterAddress);

        // Parse topics from string
        uint256[] memory topics = _parseTopics(topicsStr);

        console2.log("Adding trusted attester...");
        console2.log("Adapter:", adapterAddress);
        console2.log("Attester:", attesterAddress);
        console2.log("Topics count:", topics.length);

        vm.startBroadcast(deployerPrivateKey);

        adapter.addTrustedAttester(attesterAddress, topics);

        vm.stopBroadcast();

        console2.log("Trusted attester added successfully");

        // Verify
        for (uint256 i = 0; i < topics.length; i++) {
            bool trusted = adapter.isAttesterTrusted(attesterAddress, topics[i]);
            console2.log("Topic", topics[i], "trusted:", trusted);
        }
    }

    function _parseTopics(string memory topicsStr) internal pure returns (uint256[] memory) {
        // Simple parser for comma-separated numbers
        bytes memory b = bytes(topicsStr);
        uint256 count = 1;

        // Count commas
        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] == ",") count++;
        }

        uint256[] memory topics = new uint256[](count);
        uint256 topicIndex = 0;
        uint256 currentNum = 0;

        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] == ",") {
                topics[topicIndex++] = currentNum;
                currentNum = 0;
            } else if (b[i] >= "0" && b[i] <= "9") {
                currentNum = currentNum * 10 + (uint8(b[i]) - 48);
            }
        }
        topics[topicIndex] = currentNum;

        return topics;
    }
}
