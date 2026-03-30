// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {EASClaimVerifierIdentityWrapper} from "../contracts/EASClaimVerifierIdentityWrapper.sol";

/**
 * @title DeployIdentityWrapper
 * @notice Deployment script for Path B: IIdentity wrapper per investor
 * @dev Run with: forge script script/DeployIdentityWrapper.s.sol --rpc-url $RPC_URL --broadcast
 */
contract DeployIdentityWrapper is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Required addresses
        address identityAddress = vm.envAddress("IDENTITY_ADDRESS");
        address easAddress = vm.envAddress("EAS_ADDRESS");
        address verifierAddress = vm.envAddress("VERIFIER_ADDRESS");
        address adapterAddress = vm.envAddress("ADAPTER_ADDRESS");

        console2.log("Deploying EASClaimVerifierIdentityWrapper...");
        console2.log("Identity:", identityAddress);
        console2.log("EAS:", easAddress);
        console2.log("Verifier:", verifierAddress);
        console2.log("Adapter:", adapterAddress);

        vm.startBroadcast(deployerPrivateKey);

        EASClaimVerifierIdentityWrapper wrapper = new EASClaimVerifierIdentityWrapper(
            identityAddress,
            easAddress,
            verifierAddress,
            adapterAddress
        );

        vm.stopBroadcast();

        console2.log("\n=== Wrapper Deployed ===");
        console2.log("Wrapper address:", address(wrapper));
        console2.log("");
        console2.log("Next step: Register this wrapper as the identity in your IdentityRegistry");
        console2.log("identityRegistry.registerIdentity(investorAddress, wrapperAddress, countryCode)");
    }
}
