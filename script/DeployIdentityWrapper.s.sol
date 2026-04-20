// SPDX-License-Identifier: Apache-2.0
// Copyright © 2026 Enterprise Ethereum Alliance Inc.
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {EASClaimVerifierIdentityWrapper} from "../contracts/EASClaimVerifierIdentityWrapper.sol";

/**
 * @title DeployIdentityWrapper
 * @notice Deploys a per-identity `EASClaimVerifierIdentityWrapper` (Path B).
 * @dev **IMPORTANT**: This wrapper is a *read-compat shim* for legacy
 *      ERC-3643 Identity Registries that cannot be modified. It does NOT
 *      implement:
 *        - ERC-734 key management (no `addKey`, no recovery)
 *        - Claim signature verification (returned signatures are empty bytes)
 *        - Topic policies in `isClaimValid` (does not check payload semantics)
 *      New deployments should use Path A (`EASClaimVerifier` directly).
 *
 *      Required env:
 *        PRIVATE_KEY          — deployer key
 *        IDENTITY_ADDRESS     — the investor identity this wrapper represents
 *        EAS_ADDRESS          — EAS contract address
 *        CLAIM_VERIFIER       — deployed `EASClaimVerifier` address
 *        TRUSTED_ISSUERS_ADAPTER — deployed `EASTrustedIssuersAdapter` address
 */
contract DeployIdentityWrapper is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address identityAddress = vm.envAddress("IDENTITY_ADDRESS");
        address eas = vm.envAddress("EAS_ADDRESS");
        address claimVerifier = vm.envAddress("CLAIM_VERIFIER");
        address trustedIssuersAdapter = vm.envAddress("TRUSTED_ISSUERS_ADAPTER");

        console2.log("=== Path B Wrapper Deploy ===");
        console2.log("IDENTITY:", identityAddress);
        console2.log("");
        console2.log("WARNING: Path B wrapper does NOT implement:");
        console2.log("  - ERC-734 key management (no recovery)");
        console2.log("  - Claim signature verification (empty signatures)");
        console2.log("  - Topic policies in isClaimValid");
        console2.log("See contracts/EASClaimVerifierIdentityWrapper.sol NatSpec.");

        vm.startBroadcast(deployerKey);
        EASClaimVerifierIdentityWrapper wrapper =
            new EASClaimVerifierIdentityWrapper(identityAddress, eas, claimVerifier, trustedIssuersAdapter);
        vm.stopBroadcast();

        console2.log("Wrapper:", address(wrapper));
    }
}
