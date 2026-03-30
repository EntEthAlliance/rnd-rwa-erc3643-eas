// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {EASClaimVerifier} from "../../contracts/EASClaimVerifier.sol";
import {EASTrustedIssuersAdapter} from "../../contracts/EASTrustedIssuersAdapter.sol";
import {EASIdentityProxy} from "../../contracts/EASIdentityProxy.sol";
import {MockEAS} from "../../contracts/mocks/MockEAS.sol";
import {MockClaimTopicsRegistry} from "../../contracts/mocks/MockClaimTopicsRegistry.sol";
import {MockAttester} from "../../contracts/mocks/MockAttester.sol";
import {RevocationRequest, RevocationRequestData} from "@eas/IEAS.sol";

/**
 * @title FullTransferLifecycleTest
 * @notice Integration tests walking through complete ERC-3643 transfer lifecycle with EAS bridge
 * @dev Tests the full flow from deployment through investor verification, transfer, and re-verification
 */
contract FullTransferLifecycleTest is Test {
    // ============ Contracts ============
    EASClaimVerifier public verifier;
    EASTrustedIssuersAdapter public trustedIssuers;
    EASIdentityProxy public identityProxy;
    MockEAS public mockEAS;
    MockClaimTopicsRegistry public claimTopicsRegistry;
    MockAttester public kycProvider;

    // ============ Addresses ============
    address public tokenIssuer;
    address public kycProviderAddr;
    address public investor1;
    address public investor2;
    address public nonVerifiedWallet;

    // ============ Constants ============
    uint256 public constant TOPIC_KYC = 1;
    bytes32 public constant SCHEMA_KYC = keccak256("KYC_SCHEMA");

    function setUp() public {
        // Create addresses
        tokenIssuer = makeAddr("tokenIssuer");
        investor1 = makeAddr("investor1");
        investor2 = makeAddr("investor2");
        nonVerifiedWallet = makeAddr("nonVerifiedWallet");

        // Step 1: Deploy all contracts
        mockEAS = new MockEAS();
        claimTopicsRegistry = new MockClaimTopicsRegistry();
        kycProvider = new MockAttester(address(mockEAS), "Acme KYC");
        kycProviderAddr = address(kycProvider);

        vm.startPrank(tokenIssuer);

        trustedIssuers = new EASTrustedIssuersAdapter(tokenIssuer);
        identityProxy = new EASIdentityProxy(tokenIssuer);
        verifier = new EASClaimVerifier(tokenIssuer);

        // Step 2: Configure bridge
        verifier.setEASAddress(address(mockEAS));
        verifier.setTrustedIssuersAdapter(address(trustedIssuers));
        verifier.setIdentityProxy(address(identityProxy));
        verifier.setClaimTopicsRegistry(address(claimTopicsRegistry));
        verifier.setTopicSchemaMapping(TOPIC_KYC, SCHEMA_KYC);

        // Step 3: Register KYC provider as trusted attester
        uint256[] memory topics = new uint256[](1);
        topics[0] = TOPIC_KYC;
        trustedIssuers.addTrustedAttester(kycProviderAddr, topics);

        vm.stopPrank();

        // Set required claim topics
        claimTopicsRegistry.addClaimTopic(TOPIC_KYC);
    }

    /**
     * @notice Full lifecycle test as specified in PRD
     * Steps:
     * 1. Deploy token with EAS bridge configured ✓ (done in setUp)
     * 2. Register investor identity in EASIdentityProxy
     * 3. Register KYC provider as trusted attester ✓ (done in setUp)
     * 4. KYC provider creates EAS attestation for investor
     * 5. Mint tokens to issuer (simulated via verification check)
     * 6. Transfer tokens from issuer to investor → succeeds
     * 7. Transfer tokens from investor to non-attested wallet → fails
     * 8. Revoke investor attestation → transfer from investor fails
     * 9. Re-attest investor → transfer succeeds again
     */
    function test_fullTransferLifecycle() public {
        // ============ Step 2: Register investor identity ============
        vm.prank(tokenIssuer);
        identityProxy.registerWallet(investor1, investor1);

        // Investor is not yet verified (no attestation)
        assertFalse(verifier.isVerified(investor1));

        // ============ Step 4: KYC provider creates attestation ============
        bytes32 attestationUID = kycProvider.attestInvestorEligibility(
            SCHEMA_KYC,
            investor1,
            investor1,
            1, // VERIFIED
            0, // NONE
            840, // US
            0 // No expiration
        );

        // Register the attestation
        verifier.registerAttestation(investor1, TOPIC_KYC, attestationUID);

        // ============ Step 5-6: Verify issuer can transfer to investor ============
        // (In real scenario: token.transfer(issuer, investor1, amount) would call isVerified)
        assertTrue(verifier.isVerified(investor1));

        // ============ Step 7: Transfer to non-attested wallet fails ============
        assertFalse(verifier.isVerified(nonVerifiedWallet));

        // ============ Step 8: Revoke attestation ============
        vm.prank(kycProviderAddr);
        mockEAS.revoke(
            RevocationRequest({
                schema: SCHEMA_KYC,
                data: RevocationRequestData({uid: attestationUID, value: 0})
            })
        );

        // Investor can no longer receive transfers
        assertFalse(verifier.isVerified(investor1));

        // ============ Step 9: Re-attest investor ============
        bytes32 newAttestationUID = kycProvider.attestInvestorEligibility(
            SCHEMA_KYC,
            investor1,
            investor1,
            1, // VERIFIED
            0, // NONE
            840, // US
            0 // No expiration
        );

        verifier.registerAttestation(investor1, TOPIC_KYC, newAttestationUID);

        // Investor is verified again
        assertTrue(verifier.isVerified(investor1));
    }

    /**
     * @notice Test multiple investors in the lifecycle
     */
    function test_multipleInvestorsLifecycle() public {
        // Register both investors
        vm.startPrank(tokenIssuer);
        identityProxy.registerWallet(investor1, investor1);
        identityProxy.registerWallet(investor2, investor2);
        vm.stopPrank();

        // Neither is verified initially
        assertFalse(verifier.isVerified(investor1));
        assertFalse(verifier.isVerified(investor2));

        // Attest investor1
        bytes32 uid1 = kycProvider.attestInvestorEligibility(
            SCHEMA_KYC, investor1, investor1, 1, 0, 840, 0
        );
        verifier.registerAttestation(investor1, TOPIC_KYC, uid1);

        // Only investor1 is verified
        assertTrue(verifier.isVerified(investor1));
        assertFalse(verifier.isVerified(investor2));

        // Attest investor2
        bytes32 uid2 = kycProvider.attestInvestorEligibility(
            SCHEMA_KYC, investor2, investor2, 1, 0, 826, 0 // UK
        );
        verifier.registerAttestation(investor2, TOPIC_KYC, uid2);

        // Both are verified
        assertTrue(verifier.isVerified(investor1));
        assertTrue(verifier.isVerified(investor2));
    }

    /**
     * @notice Test lifecycle with multi-wallet identity
     */
    function test_multiWalletIdentityLifecycle() public {
        address identity1 = makeAddr("identity1");
        address wallet1a = makeAddr("wallet1a");
        address wallet1b = makeAddr("wallet1b");

        // Register multiple wallets under same identity
        vm.startPrank(tokenIssuer);
        identityProxy.registerWallet(wallet1a, identity1);
        identityProxy.registerWallet(wallet1b, identity1);
        vm.stopPrank();

        // No wallets are verified
        assertFalse(verifier.isVerified(wallet1a));
        assertFalse(verifier.isVerified(wallet1b));
        assertFalse(verifier.isVerified(identity1));

        // Attest the identity (not the individual wallets)
        bytes32 uid = kycProvider.attestInvestorEligibility(
            SCHEMA_KYC, identity1, identity1, 1, 0, 840, 0
        );
        verifier.registerAttestation(identity1, TOPIC_KYC, uid);

        // All wallets and identity are verified
        assertTrue(verifier.isVerified(identity1));
        assertTrue(verifier.isVerified(wallet1a));
        assertTrue(verifier.isVerified(wallet1b));

        // Remove one wallet
        vm.prank(tokenIssuer);
        identityProxy.removeWallet(wallet1a);

        // Removed wallet is no longer verified, others still are
        assertFalse(verifier.isVerified(wallet1a));
        assertTrue(verifier.isVerified(wallet1b));
        assertTrue(verifier.isVerified(identity1));
    }
}
