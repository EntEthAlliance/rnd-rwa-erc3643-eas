// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {EASClaimVerifier} from "../contracts/EASClaimVerifier.sol";
import {EASTrustedIssuersAdapter} from "../contracts/EASTrustedIssuersAdapter.sol";
import {EASIdentityProxy} from "../contracts/EASIdentityProxy.sol";

/**
 * @title DeployMainnet
 * @author EEA Working Group
 * @notice Production deployment script with multi-sig ownership
 * @dev Deploys the EAS-ERC3643 bridge with production-ready configuration.
 *      Transfers ownership to a multi-sig wallet for security.
 *
 *      IMPORTANT: Production deployments should:
 *      1. Use a hardware wallet for the deployer key
 *      2. Transfer ownership to a multi-sig (Gnosis Safe recommended)
 *      3. Verify contracts on Etherscan
 *      4. Document deployment addresses
 *
 *      Run with:
 *      forge script script/DeployMainnet.s.sol:DeployMainnet --rpc-url $MAINNET_RPC_URL --broadcast --verify --slow
 *
 *      Environment variables (all required for production):
 *      - PRIVATE_KEY: Deployer private key (use hardware wallet)
 *      - MULTISIG_ADDRESS: Multi-sig wallet for ownership (REQUIRED)
 *      - CLAIM_TOPICS_REGISTRY: Existing registry address (REQUIRED)
 *      - ETHERSCAN_API_KEY: For contract verification
 *      - AUDIT_ACKNOWLEDGED: Must be true to pass audit deployment gate
 */
contract DeployMainnet is Script {
    // Mainnet EAS addresses
    address constant EAS_MAINNET = 0xA1207F3BBa224E2c9c3c6D5aF63D0eb1582Ce587;
    address constant EAS_BASE = 0x4200000000000000000000000000000000000021;
    address constant EAS_ARBITRUM = 0xbD75f629A22Dc1ceD33dDA0b68c546A1c035c458;
    address constant EAS_OPTIMISM = 0x4200000000000000000000000000000000000021;

    // Production claim topics
    uint256 constant TOPIC_KYC = 1;
    uint256 constant TOPIC_AML = 2;
    uint256 constant TOPIC_COUNTRY = 3;
    uint256 constant TOPIC_ACCREDITATION = 7;

    function run() external {
        // Load required environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Multi-sig is REQUIRED for production
        address multisig = vm.envAddress("MULTISIG_ADDRESS");
        require(multisig != address(0), "MULTISIG_ADDRESS is required for production");
        require(multisig != deployer, "MULTISIG_ADDRESS cannot be the deployer");

        // Claim topics registry is REQUIRED
        address claimTopicsRegistry = vm.envAddress("CLAIM_TOPICS_REGISTRY");
        require(claimTopicsRegistry != address(0), "CLAIM_TOPICS_REGISTRY is required");

        // Get EAS address for this network
        address easAddress = _getEasAddress();

        // Production checks
        require(block.chainid != 31337, "Cannot deploy to local network");
        require(_isMainnet(), "Use DeployTestnet.s.sol for testnets");

        // Audit gate: blocks unaudited mainnet deployment unless explicitly acknowledged
        bool auditAcknowledged = vm.envBool("AUDIT_ACKNOWLEDGED");
        require(
            auditAcknowledged,
            "AUDIT GATE: set AUDIT_ACKNOWLEDGED=true only after audit scope/review is complete (see AUDIT.md)"
        );

        console2.log("=== EAS-ERC3643 Bridge PRODUCTION Deployment ===");
        console2.log("");
        console2.log("PRODUCTION DEPLOYMENT - PLEASE VERIFY ALL PARAMETERS");
        console2.log("");
        console2.log("Network:", _getNetworkName());
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", deployer);
        console2.log("Multi-sig Owner:", multisig);
        console2.log("EAS:", easAddress);
        console2.log("Claim Topics Registry:", claimTopicsRegistry);
        console2.log("");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy contracts with deployer as initial owner
        console2.log("Step 1: Deploying contracts...");

        EASTrustedIssuersAdapter adapter = new EASTrustedIssuersAdapter(deployer);
        console2.log("  EASTrustedIssuersAdapter:", address(adapter));

        EASIdentityProxy identityProxy = new EASIdentityProxy(deployer);
        console2.log("  EASIdentityProxy:", address(identityProxy));

        EASClaimVerifier verifier = new EASClaimVerifier(deployer);
        console2.log("  EASClaimVerifier:", address(verifier));

        // Configure verifier
        console2.log("");
        console2.log("Step 2: Configuring verifier...");

        verifier.setEASAddress(easAddress);
        verifier.setTrustedIssuersAdapter(address(adapter));
        verifier.setIdentityProxy(address(identityProxy));
        verifier.setClaimTopicsRegistry(claimTopicsRegistry);
        console2.log("  Verifier fully configured");

        // Transfer ownership to multi-sig
        console2.log("");
        console2.log("Step 3: Transferring ownership to multi-sig...");

        adapter.transferOwnership(multisig);
        console2.log("  Adapter ownership transferred");

        identityProxy.transferOwnership(multisig);
        console2.log("  Identity Proxy ownership transferred");

        verifier.transferOwnership(multisig);
        console2.log("  Verifier ownership transferred");

        vm.stopBroadcast();

        // Output deployment summary
        console2.log("");
        console2.log("=== PRODUCTION Deployment Complete ===");
        console2.log("");
        console2.log("Contract Addresses (SAVE THESE):");
        console2.log("  EASClaimVerifier:", address(verifier));
        console2.log("  EASTrustedIssuersAdapter:", address(adapter));
        console2.log("  EASIdentityProxy:", address(identityProxy));
        console2.log("");
        console2.log("Ownership: All contracts owned by", multisig);
        console2.log("");
        console2.log("REQUIRED MULTI-SIG ACTIONS:");
        console2.log("1. Accept ownership of all contracts");
        console2.log("2. Set schema mappings via verifier.setTopicSchemaMapping()");
        console2.log("3. Add trusted attesters via adapter.addTrustedAttester()");
        console2.log("");
        console2.log("Verify contracts:");
        console2.log("  forge verify-contract", address(verifier), "EASClaimVerifier --chain", _getNetworkName());
        console2.log("  forge verify-contract", address(adapter), "EASTrustedIssuersAdapter --chain", _getNetworkName());
        console2.log("  forge verify-contract", address(identityProxy), "EASIdentityProxy --chain", _getNetworkName());
    }

    function _getEasAddress() internal view returns (address) {
        uint256 chainId = block.chainid;

        if (chainId == 1) return EAS_MAINNET;
        if (chainId == 8453) return EAS_BASE;
        if (chainId == 42161) return EAS_ARBITRUM;
        if (chainId == 10) return EAS_OPTIMISM;

        revert("Unsupported mainnet. Add EAS address for this network.");
    }

    function _isMainnet() internal view returns (bool) {
        uint256 chainId = block.chainid;
        return chainId == 1 || chainId == 8453 || chainId == 42161 || chainId == 10;
    }

    function _getNetworkName() internal view returns (string memory) {
        uint256 chainId = block.chainid;

        if (chainId == 1) return "mainnet";
        if (chainId == 8453) return "base";
        if (chainId == 42161) return "arbitrum";
        if (chainId == 10) return "optimism";

        return "unknown";
    }
}
