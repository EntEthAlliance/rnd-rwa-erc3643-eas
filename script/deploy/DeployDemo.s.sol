// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {DemoERC3643Token} from "../../contracts/demo/DemoERC3643Token.sol";

/**
 * @title DeployDemo
 * @notice Deploys the DemoERC3643Token used by `demo/shibui-app`'s Transfer
 *         screen. Expects the core Shibui stack (EASClaimVerifier, adapters,
 *         schemas) to already be deployed and configured — this script only
 *         mints the demo token.
 *
 * @dev Reads `EAS_CLAIM_VERIFIER` env var for the verifier address. After
 *      deploy, update `deployments/sepolia.json#demo.DemoERC3643Token` and the
 *      `demo.investors` block with Alice/Bob/Carol wallets + identities.
 *
 * Usage:
 *   EAS_CLAIM_VERIFIER=0x... DEPLOYER_PRIVATE_KEY=0x... \
 *     forge script script/deploy/DeployDemo.s.sol:DeployDemo \
 *     --rpc-url $RPC_SEPOLIA --broadcast
 */
contract DeployDemo is Script {
    function run() external {
        address verifier = vm.envAddress("EAS_CLAIM_VERIFIER");
        uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address admin = vm.addr(pk);

        vm.startBroadcast(pk);

        DemoERC3643Token token = new DemoERC3643Token(
            "Shibui Demo Token",
            "sDEMO",
            verifier,
            admin
        );

        // Seed the deployer with 1_000 tokens so the demo can sink transfers.
        token.mint(admin, 1_000 ether);

        vm.stopBroadcast();

        console2.log("DemoERC3643Token deployed at", address(token));
        console2.log("Deployer balance:", token.balanceOf(admin));
        console2.log("Bound to verifier:", verifier);
        console2.log("Next: update deployments/sepolia.json#demo.DemoERC3643Token");
    }
}
