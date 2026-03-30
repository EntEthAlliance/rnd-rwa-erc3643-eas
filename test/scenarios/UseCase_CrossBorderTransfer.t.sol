// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {EASClaimVerifier} from "../../contracts/EASClaimVerifier.sol";
import {EASTrustedIssuersAdapter} from "../../contracts/EASTrustedIssuersAdapter.sol";
import {EASIdentityProxy} from "../../contracts/EASIdentityProxy.sol";
import {MockEAS} from "../../contracts/mocks/MockEAS.sol";
import {MockClaimTopicsRegistry} from "../../contracts/mocks/MockClaimTopicsRegistry.sol";
import {MockAttester} from "../../contracts/mocks/MockAttester.sol";

/**
 * @title UseCase_CrossBorderTransfer_Test
 * @notice Cross-border transfer scenario tests
 * @dev Tests as specified in PRD:
 * - Corporate token issuer in jurisdiction A
 * - Investor buyer in jurisdiction B
 * - Requires KYC attestation from issuer's approved list
 * - Requires tax treaty attestation for cross-border
 * - Test transfer succeeds when both attestations present
 * - Test transfer fails when tax treaty attestation missing
 * - Test transfer fails when investor attestation is from non-approved attester
 */
contract UseCase_CrossBorderTransfer_Test is Test {
    // ============ Contracts ============
    EASClaimVerifier public verifier;
    EASTrustedIssuersAdapter public trustedIssuers;
    EASIdentityProxy public identityProxy;
    MockEAS public mockEAS;
    MockClaimTopicsRegistry public claimTopicsRegistry;

    // Approved KYC providers
    MockAttester public approvedKycProviderA; // Jurisdiction A approved
    MockAttester public approvedKycProviderB; // Jurisdiction B approved
    MockAttester public unapprovedKycProvider; // Not on approved list

    // Tax treaty attestation provider
    MockAttester public taxTreatyProvider;

    // ============ Addresses ============
    address public issuer; // Jurisdiction A
    address public investorB1; // Jurisdiction B investor 1
    address public investorB2; // Jurisdiction B investor 2
    address public investorC; // Jurisdiction C (no treaty)

    // ============ Constants ============
    uint256 public constant TOPIC_KYC = 1;
    uint256 public constant TOPIC_TAX_TREATY = 10;

    bytes32 public constant SCHEMA_KYC = keccak256("KYC_CROSSBORDER");
    bytes32 public constant SCHEMA_TAX_TREATY = keccak256("TAX_TREATY");

    // Country codes
    uint16 public constant JURISDICTION_A = 840; // USA
    uint16 public constant JURISDICTION_B = 826; // UK
    uint16 public constant JURISDICTION_C = 643; // Russia (no treaty in this scenario)

    function setUp() public {
        issuer = makeAddr("issuerJurisdictionA");
        investorB1 = makeAddr("investorB1");
        investorB2 = makeAddr("investorB2");
        investorC = makeAddr("investorC");

        // Deploy infrastructure
        mockEAS = new MockEAS();
        claimTopicsRegistry = new MockClaimTopicsRegistry();

        approvedKycProviderA = new MockAttester(address(mockEAS), "Approved KYC A");
        approvedKycProviderB = new MockAttester(address(mockEAS), "Approved KYC B");
        unapprovedKycProvider = new MockAttester(address(mockEAS), "Unapproved KYC");
        taxTreatyProvider = new MockAttester(address(mockEAS), "Tax Treaty Authority");

        vm.startPrank(issuer);

        trustedIssuers = new EASTrustedIssuersAdapter(issuer);
        identityProxy = new EASIdentityProxy(issuer);
        verifier = new EASClaimVerifier(issuer);

        verifier.setEASAddress(address(mockEAS));
        verifier.setTrustedIssuersAdapter(address(trustedIssuers));
        verifier.setIdentityProxy(address(identityProxy));
        verifier.setClaimTopicsRegistry(address(claimTopicsRegistry));

        verifier.setTopicSchemaMapping(TOPIC_KYC, SCHEMA_KYC);
        verifier.setTopicSchemaMapping(TOPIC_TAX_TREATY, SCHEMA_TAX_TREATY);

        // Add ONLY approved KYC providers to trusted list
        uint256[] memory kycTopics = new uint256[](1);
        kycTopics[0] = TOPIC_KYC;
        trustedIssuers.addTrustedAttester(address(approvedKycProviderA), kycTopics);
        trustedIssuers.addTrustedAttester(address(approvedKycProviderB), kycTopics);

        // Add tax treaty provider
        uint256[] memory taxTopics = new uint256[](1);
        taxTopics[0] = TOPIC_TAX_TREATY;
        trustedIssuers.addTrustedAttester(address(taxTreatyProvider), taxTopics);

        vm.stopPrank();

        // Cross-border requires both KYC and tax treaty attestations
        claimTopicsRegistry.addClaimTopic(TOPIC_KYC);
        claimTopicsRegistry.addClaimTopic(TOPIC_TAX_TREATY);
    }

    // ============ Helper Functions ============

    function _attestKYCFromApprovedA(address investor, uint16 country) internal returns (bytes32) {
        bytes32 uid = approvedKycProviderA.attestInvestorEligibility(
            SCHEMA_KYC, investor, investor, 1, 0, country, 0
        );
        verifier.registerAttestation(investor, TOPIC_KYC, uid);
        return uid;
    }

    function _attestKYCFromApprovedB(address investor, uint16 country) internal returns (bytes32) {
        bytes32 uid = approvedKycProviderB.attestInvestorEligibility(
            SCHEMA_KYC, investor, investor, 1, 0, country, 0
        );
        verifier.registerAttestation(investor, TOPIC_KYC, uid);
        return uid;
    }

    function _attestTaxTreaty(address investor) internal returns (bytes32) {
        bytes32 uid = taxTreatyProvider.attestInvestorEligibility(
            SCHEMA_TAX_TREATY, investor, investor, 1, 0, 0, 0
        );
        verifier.registerAttestation(investor, TOPIC_TAX_TREATY, uid);
        return uid;
    }

    // ============ Scenario Tests ============

    /**
     * @notice Test: Transfer succeeds with both KYC and tax treaty attestations
     */
    function test_crossBorder_successWithBothAttestations() public {
        // Investor B1 has KYC from approved provider
        _attestKYCFromApprovedA(investorB1, JURISDICTION_B);

        // Investor B1 has tax treaty attestation
        _attestTaxTreaty(investorB1);

        // Transfer succeeds
        assertTrue(verifier.isVerified(investorB1));
    }

    /**
     * @notice Test: Transfer fails when tax treaty attestation missing
     */
    function test_crossBorder_failsWithoutTaxTreaty() public {
        // Investor B2 has KYC only
        _attestKYCFromApprovedA(investorB2, JURISDICTION_B);

        // No tax treaty attestation
        // Transfer fails
        assertFalse(verifier.isVerified(investorB2));
    }

    /**
     * @notice Test: Transfer fails when KYC from unapproved attester
     */
    function test_crossBorder_failsWithUnapprovedKYC() public {
        // Try to use unapproved KYC provider
        bytes32 uid = unapprovedKycProvider.attestInvestorEligibility(
            SCHEMA_KYC, investorB1, investorB1, 1, 0, JURISDICTION_B, 0
        );

        // Registration should fail because attester not trusted
        vm.expectRevert("Attester not trusted");
        verifier.registerAttestation(investorB1, TOPIC_KYC, uid);

        // Even with tax treaty, investor cannot receive tokens
        _attestTaxTreaty(investorB1);
        assertFalse(verifier.isVerified(investorB1));
    }

    /**
     * @notice Test: Investor from jurisdiction C (no treaty) blocked
     */
    function test_crossBorder_noTreatyJurisdictionBlocked() public {
        // Investor C has valid KYC
        _attestKYCFromApprovedA(investorC, JURISDICTION_C);

        // But jurisdiction C has no tax treaty
        // So no tax treaty attestation can be issued
        // Transfer fails
        assertFalse(verifier.isVerified(investorC));
    }

    /**
     * @notice Test: KYC from either approved provider works
     */
    function test_crossBorder_eitherApprovedProviderWorks() public {
        // Investor B1 uses provider A
        _attestKYCFromApprovedA(investorB1, JURISDICTION_B);
        _attestTaxTreaty(investorB1);
        assertTrue(verifier.isVerified(investorB1));

        // Investor B2 uses provider B
        _attestKYCFromApprovedB(investorB2, JURISDICTION_B);
        _attestTaxTreaty(investorB2);
        assertTrue(verifier.isVerified(investorB2));
    }

    /**
     * @notice Test: Tax treaty expiration blocks transfer
     */
    function test_crossBorder_taxTreatyExpiration() public {
        vm.warp(1000);

        _attestKYCFromApprovedA(investorB1, JURISDICTION_B);

        // Tax treaty with expiration
        uint64 treatyExpiration = uint64(block.timestamp + 100);
        bytes32 uid = taxTreatyProvider.attestInvestorEligibility(
            SCHEMA_TAX_TREATY, investorB1, investorB1, 1, 0, 0, treatyExpiration
        );
        verifier.registerAttestation(investorB1, TOPIC_TAX_TREATY, uid);

        // Transfer succeeds initially
        assertTrue(verifier.isVerified(investorB1));

        // Treaty expires
        vm.warp(treatyExpiration);

        // Transfer fails
        assertFalse(verifier.isVerified(investorB1));
    }

    /**
     * @notice Test: Removing approved KYC provider blocks transfers
     */
    function test_crossBorder_removingApprovedProvider() public {
        // Both investors verified
        _attestKYCFromApprovedA(investorB1, JURISDICTION_B);
        _attestTaxTreaty(investorB1);

        _attestKYCFromApprovedB(investorB2, JURISDICTION_B);
        _attestTaxTreaty(investorB2);

        assertTrue(verifier.isVerified(investorB1));
        assertTrue(verifier.isVerified(investorB2));

        // Remove provider A from approved list
        vm.prank(issuer);
        trustedIssuers.removeTrustedAttester(address(approvedKycProviderA));

        // Investor B1 (KYC from A) blocked
        assertFalse(verifier.isVerified(investorB1));

        // Investor B2 (KYC from B) still verified
        assertTrue(verifier.isVerified(investorB2));
    }

    /**
     * @notice Test: Dual attestation scenario
     */
    function test_crossBorder_dualAttestationScenario() public {
        // Investor has KYC from both approved providers
        _attestKYCFromApprovedA(investorB1, JURISDICTION_B);
        _attestKYCFromApprovedB(investorB1, JURISDICTION_B);
        _attestTaxTreaty(investorB1);

        assertTrue(verifier.isVerified(investorB1));

        // Remove one provider
        vm.prank(issuer);
        trustedIssuers.removeTrustedAttester(address(approvedKycProviderA));

        // Still verified via provider B
        assertTrue(verifier.isVerified(investorB1));
    }

    /**
     * @notice Test: Multi-wallet cross-border investor
     */
    function test_crossBorder_multiWalletInvestor() public {
        address identity = makeAddr("crossBorderIdentity");
        address wallet1 = makeAddr("wallet1");
        address wallet2 = makeAddr("wallet2");

        // Register wallets
        vm.prank(issuer);
        identityProxy.registerWallet(wallet1, identity);
        vm.prank(issuer);
        identityProxy.registerWallet(wallet2, identity);

        // Attest identity
        _attestKYCFromApprovedA(identity, JURISDICTION_B);
        _attestTaxTreaty(identity);

        // Both wallets can receive transfers
        assertTrue(verifier.isVerified(wallet1));
        assertTrue(verifier.isVerified(wallet2));
    }

    /**
     * @notice Test: Sequential attestation (KYC first, then tax treaty)
     */
    function test_crossBorder_sequentialAttestation() public {
        // Step 1: KYC only - not yet verified
        _attestKYCFromApprovedA(investorB1, JURISDICTION_B);
        assertFalse(verifier.isVerified(investorB1));

        // Step 2: Add tax treaty - now verified
        _attestTaxTreaty(investorB1);
        assertTrue(verifier.isVerified(investorB1));
    }

    /**
     * @notice Test: Treaty revocation mid-holding
     */
    function test_crossBorder_treatyRevocationMidHolding() public {
        _attestKYCFromApprovedA(investorB1, JURISDICTION_B);
        bytes32 treatyUid = _attestTaxTreaty(investorB1);

        // Investor is holding tokens (verified)
        assertTrue(verifier.isVerified(investorB1));

        // Political situation changes, treaty revoked
        mockEAS.forceRevoke(treatyUid);

        // Investor can no longer transfer (sell)
        // In real scenario, they'd need to get new treaty attestation
        assertFalse(verifier.isVerified(investorB1));
    }

    /**
     * @notice Test: Same country transfer (no tax treaty needed scenario)
     * Note: This test demonstrates how to configure for domestic transfers
     */
    function test_crossBorder_sameCountryNoTreatyNeeded() public {
        // Create a separate verifier for domestic transfers (only KYC required)
        MockClaimTopicsRegistry domesticRegistry = new MockClaimTopicsRegistry();
        domesticRegistry.addClaimTopic(TOPIC_KYC); // Only KYC, no tax treaty

        vm.startPrank(issuer);
        EASClaimVerifier domesticVerifier = new EASClaimVerifier(issuer);
        domesticVerifier.setEASAddress(address(mockEAS));
        domesticVerifier.setTrustedIssuersAdapter(address(trustedIssuers));
        domesticVerifier.setIdentityProxy(address(identityProxy));
        domesticVerifier.setClaimTopicsRegistry(address(domesticRegistry));
        domesticVerifier.setTopicSchemaMapping(TOPIC_KYC, SCHEMA_KYC);
        vm.stopPrank();

        // Same country investor only needs KYC
        address domesticInvestor = makeAddr("domesticInvestor");
        bytes32 uid = approvedKycProviderA.attestInvestorEligibility(
            SCHEMA_KYC, domesticInvestor, domesticInvestor, 1, 0, JURISDICTION_A, 0
        );
        domesticVerifier.registerAttestation(domesticInvestor, TOPIC_KYC, uid);

        // Verified for domestic transfers (only KYC required)
        assertTrue(domesticVerifier.isVerified(domesticInvestor));

        // Register same attestation in cross-border verifier
        verifier.registerAttestation(domesticInvestor, TOPIC_KYC, uid);

        // NOT verified for cross-border because missing tax treaty
        // (has KYC but not tax treaty)
        assertFalse(verifier.isVerified(domesticInvestor));
    }
}
