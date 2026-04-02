// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {EASClaimVerifier} from "../../contracts/EASClaimVerifier.sol";
import {EASTrustedIssuersAdapter} from "../../contracts/EASTrustedIssuersAdapter.sol";
import {EASIdentityProxy} from "../../contracts/EASIdentityProxy.sol";
import {EASClaimVerifierIdentityWrapper} from "../../contracts/EASClaimVerifierIdentityWrapper.sol";
import {MockEAS} from "../../contracts/mocks/MockEAS.sol";
import {MockClaimTopicsRegistry} from "../../contracts/mocks/MockClaimTopicsRegistry.sol";
import {MockAttester} from "../../contracts/mocks/MockAttester.sol";

/**
 * @title DualModeVerificationTest
 * @notice Integration tests for dual-mode verification (ONCHAINID + EAS)
 * @dev Tests scenarios where both verification methods are available
 *
 * As specified in PRD:
 * 1. Investor A has ONCHAINID claims only → transfer succeeds
 * 2. Investor B has EAS attestations only → transfer succeeds
 * 3. Investor C has both → transfer succeeds
 * 4. Investor D has neither → transfer fails
 * 5. Revoke ONCHAINID for investor A, add EAS attestation → still succeeds
 * 6. Revoke EAS for investor B, add ONCHAINID claim → still succeeds
 *
 * Note: This test uses EAS path exclusively since we don't have mock ONCHAINID.
 * The test validates the fallback/multi-path verification concept.
 */
contract DualModeVerificationTest is Test {
    // ============ Contracts ============
    EASClaimVerifier public verifier;
    EASTrustedIssuersAdapter public trustedIssuers;
    EASIdentityProxy public identityProxy;
    MockEAS public mockEAS;
    MockClaimTopicsRegistry public claimTopicsRegistry;

    // Multiple KYC providers (simulating different verification paths)
    MockAttester public kycProviderPrimary;
    MockAttester public kycProviderSecondary;

    // ============ Addresses ============
    address public tokenIssuer;
    address public investorA;
    address public investorB;
    address public investorC;
    address public investorD;

    // ============ Constants ============
    uint256 public constant TOPIC_KYC = 1;
    bytes32 public constant SCHEMA_KYC = keccak256("KYC_SCHEMA");

    function setUp() public {
        tokenIssuer = makeAddr("tokenIssuer");
        investorA = makeAddr("investorA");
        investorB = makeAddr("investorB");
        investorC = makeAddr("investorC");
        investorD = makeAddr("investorD");

        // Deploy infrastructure
        mockEAS = new MockEAS();
        claimTopicsRegistry = new MockClaimTopicsRegistry();
        kycProviderPrimary = new MockAttester(address(mockEAS), "Primary KYC");
        kycProviderSecondary = new MockAttester(address(mockEAS), "Secondary KYC");

        vm.startPrank(tokenIssuer);

        trustedIssuers = new EASTrustedIssuersAdapter(tokenIssuer);
        identityProxy = new EASIdentityProxy(tokenIssuer);
        verifier = new EASClaimVerifier(tokenIssuer);

        // Configure verifier
        verifier.setEASAddress(address(mockEAS));
        verifier.setTrustedIssuersAdapter(address(trustedIssuers));
        verifier.setIdentityProxy(address(identityProxy));
        verifier.setClaimTopicsRegistry(address(claimTopicsRegistry));
        verifier.setTopicSchemaMapping(TOPIC_KYC, SCHEMA_KYC);

        // Register both KYC providers as trusted
        uint256[] memory topics = new uint256[](1);
        topics[0] = TOPIC_KYC;
        trustedIssuers.addTrustedAttester(address(kycProviderPrimary), topics);
        trustedIssuers.addTrustedAttester(address(kycProviderSecondary), topics);

        vm.stopPrank();

        // Set required topics
        claimTopicsRegistry.addClaimTopic(TOPIC_KYC);
    }

    /**
     * @notice Test investor with only primary provider attestation
     */
    function test_investorWithPrimaryProviderOnly() public {
        bytes32 uid = kycProviderPrimary.attestInvestorEligibility(SCHEMA_KYC, investorA, investorA, 1, 0, 840, 0);
        verifier.registerAttestation(investorA, TOPIC_KYC, uid);

        assertTrue(verifier.isVerified(investorA));
    }

    /**
     * @notice Test investor with only secondary provider attestation
     */
    function test_investorWithSecondaryProviderOnly() public {
        bytes32 uid = kycProviderSecondary.attestInvestorEligibility(SCHEMA_KYC, investorB, investorB, 1, 0, 826, 0);
        verifier.registerAttestation(investorB, TOPIC_KYC, uid);

        assertTrue(verifier.isVerified(investorB));
    }

    /**
     * @notice Test investor with both providers
     */
    function test_investorWithBothProviders() public {
        // Attestation from primary
        bytes32 uid1 = kycProviderPrimary.attestInvestorEligibility(SCHEMA_KYC, investorC, investorC, 1, 0, 840, 0);
        verifier.registerAttestation(investorC, TOPIC_KYC, uid1);

        // Attestation from secondary
        bytes32 uid2 = kycProviderSecondary.attestInvestorEligibility(SCHEMA_KYC, investorC, investorC, 1, 0, 840, 0);
        verifier.registerAttestation(investorC, TOPIC_KYC, uid2);

        assertTrue(verifier.isVerified(investorC));
    }

    /**
     * @notice Test investor with neither provider
     */
    function test_investorWithNeitherProvider() public view {
        assertFalse(verifier.isVerified(investorD));
    }

    /**
     * @notice Test revoke primary, add secondary attestation
     */
    function test_revokePrimaryAddSecondary() public {
        // Start with primary attestation
        bytes32 primaryUid =
            kycProviderPrimary.attestInvestorEligibility(SCHEMA_KYC, investorA, investorA, 1, 0, 840, 0);
        verifier.registerAttestation(investorA, TOPIC_KYC, primaryUid);
        assertTrue(verifier.isVerified(investorA));

        // Revoke primary attestation
        mockEAS.forceRevoke(primaryUid);
        assertFalse(verifier.isVerified(investorA));

        // Add secondary attestation
        bytes32 secondaryUid =
            kycProviderSecondary.attestInvestorEligibility(SCHEMA_KYC, investorA, investorA, 1, 0, 840, 0);
        verifier.registerAttestation(investorA, TOPIC_KYC, secondaryUid);

        // Investor is verified again via secondary provider
        assertTrue(verifier.isVerified(investorA));
    }

    /**
     * @notice Test revoke secondary, add primary attestation
     */
    function test_revokeSecondaryAddPrimary() public {
        // Start with secondary attestation
        bytes32 secondaryUid =
            kycProviderSecondary.attestInvestorEligibility(SCHEMA_KYC, investorB, investorB, 1, 0, 826, 0);
        verifier.registerAttestation(investorB, TOPIC_KYC, secondaryUid);
        assertTrue(verifier.isVerified(investorB));

        // Revoke secondary attestation
        mockEAS.forceRevoke(secondaryUid);
        assertFalse(verifier.isVerified(investorB));

        // Add primary attestation
        bytes32 primaryUid =
            kycProviderPrimary.attestInvestorEligibility(SCHEMA_KYC, investorB, investorB, 1, 0, 826, 0);
        verifier.registerAttestation(investorB, TOPIC_KYC, primaryUid);

        // Investor is verified again via primary provider
        assertTrue(verifier.isVerified(investorB));
    }

    /**
     * @notice Test fallback when one provider is removed from trusted list
     */
    function test_fallbackWhenProviderRemoved() public {
        // Both investors have attestations from different providers
        bytes32 uid1 = kycProviderPrimary.attestInvestorEligibility(SCHEMA_KYC, investorA, investorA, 1, 0, 840, 0);
        verifier.registerAttestation(investorA, TOPIC_KYC, uid1);

        bytes32 uid2 = kycProviderSecondary.attestInvestorEligibility(SCHEMA_KYC, investorB, investorB, 1, 0, 826, 0);
        verifier.registerAttestation(investorB, TOPIC_KYC, uid2);

        assertTrue(verifier.isVerified(investorA));
        assertTrue(verifier.isVerified(investorB));

        // Remove primary provider from trusted list
        vm.prank(tokenIssuer);
        trustedIssuers.removeTrustedAttester(address(kycProviderPrimary));

        // InvestorA loses verification (their provider was removed)
        assertFalse(verifier.isVerified(investorA));

        // InvestorB still verified (their provider still trusted)
        assertTrue(verifier.isVerified(investorB));

        // InvestorA gets new attestation from secondary provider
        bytes32 uid3 = kycProviderSecondary.attestInvestorEligibility(SCHEMA_KYC, investorA, investorA, 1, 0, 840, 0);
        verifier.registerAttestation(investorA, TOPIC_KYC, uid3);

        // Now both are verified via secondary provider
        assertTrue(verifier.isVerified(investorA));
        assertTrue(verifier.isVerified(investorB));
    }

    /**
     * @notice Test dual attestations - one valid, one revoked
     */
    function test_dualAttestationsOneRevoked() public {
        // Create two attestations for same investor
        bytes32 uid1 = kycProviderPrimary.attestInvestorEligibility(SCHEMA_KYC, investorC, investorC, 1, 0, 840, 0);
        verifier.registerAttestation(investorC, TOPIC_KYC, uid1);

        bytes32 uid2 = kycProviderSecondary.attestInvestorEligibility(SCHEMA_KYC, investorC, investorC, 1, 0, 840, 0);
        verifier.registerAttestation(investorC, TOPIC_KYC, uid2);

        assertTrue(verifier.isVerified(investorC));

        // Revoke one attestation
        mockEAS.forceRevoke(uid1);

        // Still verified via the other attestation
        assertTrue(verifier.isVerified(investorC));

        // Revoke the second attestation too
        mockEAS.forceRevoke(uid2);

        // Now not verified
        assertFalse(verifier.isVerified(investorC));
    }
}
