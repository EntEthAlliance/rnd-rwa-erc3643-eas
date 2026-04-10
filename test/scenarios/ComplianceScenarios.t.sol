// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {EASClaimVerifier} from "../../contracts/EASClaimVerifier.sol";
import {EASTrustedIssuersAdapter} from "../../contracts/EASTrustedIssuersAdapter.sol";
import {EASIdentityProxy} from "../../contracts/EASIdentityProxy.sol";
import {MockEAS} from "../../contracts/mocks/MockEAS.sol";
import {MockClaimTopicsRegistry} from "../../contracts/mocks/MockClaimTopicsRegistry.sol";
import {MockAttester} from "../../contracts/mocks/MockAttester.sol";

/**
 * @title ComplianceScenariosTest
 * @notice Real-world compliance scenarios for the EAS-to-ERC-3643 bridge
 */
contract ComplianceScenariosTest is Test {
    // Contracts
    EASClaimVerifier public verifier;
    MockEAS public eas;
    EASTrustedIssuersAdapter public adapter;
    EASIdentityProxy public identityProxy;
    MockClaimTopicsRegistry public topicsRegistry;
    MockAttester public kycProvider;

    // Addresses
    address public owner = address(this);

    // Constants
    uint256 public constant TOPIC_KYC = 1;
    uint256 public constant TOPIC_ACCREDITATION = 7;
    uint256 public constant TOPIC_COUNTRY = 3;

    bytes32 public schemaUID = keccak256("InvestorEligibility");

    function setUp() public {
        // Deploy and configure
        eas = new MockEAS();
        adapter = new EASTrustedIssuersAdapter(owner);
        identityProxy = new EASIdentityProxy(owner);
        topicsRegistry = new MockClaimTopicsRegistry();
        verifier = new EASClaimVerifier(owner);
        kycProvider = new MockAttester(address(eas), "GlobalKYC");

        verifier.setEASAddress(address(eas));
        verifier.setTrustedIssuersAdapter(address(adapter));
        verifier.setIdentityProxy(address(identityProxy));
        verifier.setClaimTopicsRegistry(address(topicsRegistry));
        verifier.setTopicSchemaMapping(TOPIC_KYC, schemaUID);
        verifier.setTopicSchemaMapping(TOPIC_ACCREDITATION, schemaUID);

        uint256[] memory topics = new uint256[](2);
        topics[0] = TOPIC_KYC;
        topics[1] = TOPIC_ACCREDITATION;
        adapter.addTrustedAttester(address(kycProvider), topics);

        // Authorize test contract as agent for registerAttestation calls
        identityProxy.addAgent(address(this));
    }

    // ============ Scenario 1: US Accredited Investor ============

    function test_scenario_usAccreditedInvestor() public {
        address investor = makeAddr("usAccreditedInvestor");

        // Token requires KYC and accreditation
        topicsRegistry.addClaimTopic(TOPIC_KYC);
        topicsRegistry.addClaimTopic(TOPIC_ACCREDITATION);

        // Investor is not verified initially
        assertFalse(verifier.isVerified(investor));

        // KYC provider verifies investor and issues attestation
        // kycStatus=1 (VERIFIED), accreditationType=2 (ACCREDITED), countryCode=840 (US)
        bytes32 uid = kycProvider.attestInvestorEligibility(
            schemaUID,
            investor,
            investor,
            1, // VERIFIED
            2, // ACCREDITED
            840, // US
            uint64(block.timestamp + 365 days)
        );

        // Register for both topics (same attestation covers both)
        verifier.registerAttestation(investor, TOPIC_KYC, uid);
        verifier.registerAttestation(investor, TOPIC_ACCREDITATION, uid);

        // Now verified
        assertTrue(verifier.isVerified(investor));

        // After 1 year, attestation expires
        vm.warp(block.timestamp + 366 days);
        assertFalse(verifier.isVerified(investor));
    }

    // ============ Scenario 2: EU Professional Investor ============

    function test_scenario_euProfessionalInvestor() public {
        address investor = makeAddr("euProfessionalInvestor");

        topicsRegistry.addClaimTopic(TOPIC_KYC);
        topicsRegistry.addClaimTopic(TOPIC_ACCREDITATION);

        // accreditationType=5 (PROFESSIONAL), countryCode=276 (Germany)
        bytes32 uid = kycProvider.attestInvestorEligibility(
            schemaUID,
            investor,
            investor,
            1, // VERIFIED
            5, // PROFESSIONAL
            276, // Germany
            0 // No expiration
        );

        verifier.registerAttestation(investor, TOPIC_KYC, uid);
        verifier.registerAttestation(investor, TOPIC_ACCREDITATION, uid);

        assertTrue(verifier.isVerified(investor));
    }

    // ============ Scenario 3: Multi-Wallet Institutional Investor ============

    function test_scenario_institutionalMultiWallet() public {
        address institution = makeAddr("hedgeFund");
        address tradingWallet = makeAddr("tradingDesk");
        address custodyWallet = makeAddr("custodian");
        address settleWallet = makeAddr("settlement");

        topicsRegistry.addClaimTopic(TOPIC_KYC);
        topicsRegistry.addClaimTopic(TOPIC_ACCREDITATION);

        // Register all wallets under institution identity
        identityProxy.registerWallet(tradingWallet, institution);
        identityProxy.registerWallet(custodyWallet, institution);
        identityProxy.registerWallet(settleWallet, institution);

        // Single attestation for the institution
        bytes32 uid = kycProvider.attestInvestorEligibility(
            schemaUID,
            institution,
            institution,
            1, // VERIFIED
            4, // INSTITUTIONAL
            136, // Cayman Islands
            0
        );

        verifier.registerAttestation(institution, TOPIC_KYC, uid);
        verifier.registerAttestation(institution, TOPIC_ACCREDITATION, uid);

        // All wallets are verified
        assertTrue(verifier.isVerified(tradingWallet));
        assertTrue(verifier.isVerified(custodyWallet));
        assertTrue(verifier.isVerified(settleWallet));
        assertTrue(verifier.isVerified(institution));
    }

    // ============ Scenario 4: KYC Expiration and Renewal ============

    function test_scenario_kycRenewal() public {
        address investor = makeAddr("retailInvestor");

        topicsRegistry.addClaimTopic(TOPIC_KYC);

        // Initial KYC valid for 1 year
        uint64 expiration1 = uint64(block.timestamp + 365 days);
        bytes32 uid1 = kycProvider.attestInvestorEligibility(schemaUID, investor, investor, 1, 0, 840, expiration1);
        verifier.registerAttestation(investor, TOPIC_KYC, uid1);

        assertTrue(verifier.isVerified(investor));

        // Time passes, KYC expires
        vm.warp(block.timestamp + 366 days);
        assertFalse(verifier.isVerified(investor));

        // Investor renews KYC
        uint64 expiration2 = uint64(block.timestamp + 365 days);
        bytes32 uid2 = kycProvider.attestInvestorEligibility(schemaUID, investor, investor, 1, 0, 840, expiration2);
        verifier.registerAttestation(investor, TOPIC_KYC, uid2);

        // Verified again
        assertTrue(verifier.isVerified(investor));
    }

    // ============ Scenario 5: Compliance Violation Revocation ============

    function test_scenario_complianceViolation() public {
        address investor = makeAddr("badActor");

        topicsRegistry.addClaimTopic(TOPIC_KYC);

        bytes32 uid = kycProvider.attestInvestorEligibility(schemaUID, investor, investor, 1, 2, 840, 0);
        verifier.registerAttestation(investor, TOPIC_KYC, uid);

        assertTrue(verifier.isVerified(investor));

        // Compliance violation detected - revoke attestation
        eas.forceRevoke(uid);

        // Immediately no longer verified
        assertFalse(verifier.isVerified(investor));
    }

    // ============ Scenario 6: Multiple KYC Providers ============

    function test_scenario_multipleKycProviders() public {
        address investor1 = makeAddr("investor1");
        address investor2 = makeAddr("investor2");

        MockAttester provider1 = new MockAttester(address(eas), "LocalKYC");
        MockAttester provider2 = new MockAttester(address(eas), "GlobalKYC");

        // Register both providers
        uint256[] memory topics = new uint256[](1);
        topics[0] = TOPIC_KYC;
        adapter.addTrustedAttester(address(provider1), topics);
        adapter.addTrustedAttester(address(provider2), topics);

        topicsRegistry.addClaimTopic(TOPIC_KYC);

        // Different investors use different providers
        bytes32 uid1 = provider1.attestInvestorEligibility(schemaUID, investor1, investor1, 1, 0, 840, 0);
        bytes32 uid2 = provider2.attestInvestorEligibility(schemaUID, investor2, investor2, 1, 0, 826, 0);

        verifier.registerAttestation(investor1, TOPIC_KYC, uid1);
        verifier.registerAttestation(investor2, TOPIC_KYC, uid2);

        assertTrue(verifier.isVerified(investor1));
        assertTrue(verifier.isVerified(investor2));

        // Provider1 loses license - removed from trusted list
        adapter.removeTrustedAttester(address(provider1));

        // investor1's attestation no longer valid (provider not trusted)
        assertFalse(verifier.isVerified(investor1));

        // investor2 still valid (different provider)
        assertTrue(verifier.isVerified(investor2));
    }

    // ============ Scenario 7: Token with No Requirements ============

    function test_scenario_noRequirements() public {
        address investor = makeAddr("anyInvestor");

        // No topics in registry = no requirements
        assertTrue(verifier.isVerified(investor));
    }

    // ============ Scenario 8: Token Adds New Requirement ============

    function test_scenario_newRequirementAdded() public {
        address investor = makeAddr("existingInvestor");

        // Initially only KYC required
        topicsRegistry.addClaimTopic(TOPIC_KYC);

        bytes32 uid = kycProvider.attestInvestorEligibility(schemaUID, investor, investor, 1, 0, 840, 0);
        verifier.registerAttestation(investor, TOPIC_KYC, uid);

        assertTrue(verifier.isVerified(investor));

        // Token issuer adds accreditation requirement
        topicsRegistry.addClaimTopic(TOPIC_ACCREDITATION);

        // Existing investor no longer compliant
        assertFalse(verifier.isVerified(investor));

        // Investor gets accredited attestation
        verifier.registerAttestation(investor, TOPIC_ACCREDITATION, uid);

        // Now compliant again
        assertTrue(verifier.isVerified(investor));
    }

    // ============ Scenario 9: Direct Wallet Mode (No Identity Proxy) ============

    function test_scenario_directWalletMode() public {
        address wallet = makeAddr("simpleWallet");

        // Disable identity proxy
        verifier.setIdentityProxy(address(0));

        topicsRegistry.addClaimTopic(TOPIC_KYC);

        bytes32 uid = kycProvider.attestInvestorEligibility(schemaUID, wallet, wallet, 1, 0, 840, 0);
        // In direct wallet mode (no identity proxy), caller must be attester or identity itself
        vm.prank(address(kycProvider));
        verifier.registerAttestation(wallet, TOPIC_KYC, uid);

        assertTrue(verifier.isVerified(wallet));
    }

    // ============ Scenario 10: Attestation for Future Date ============

    function test_scenario_scheduledAttestation() public {
        address investor = makeAddr("scheduledInvestor");

        topicsRegistry.addClaimTopic(TOPIC_KYC);

        // Create attestation now, but data expiration is far in future
        bytes32 uid = kycProvider.attestInvestorEligibility(
            schemaUID,
            investor,
            investor,
            1, // VERIFIED
            0,
            840,
            uint64(block.timestamp + 10 * 365 days) // 10 year validity
        );
        verifier.registerAttestation(investor, TOPIC_KYC, uid);

        // Verified now
        assertTrue(verifier.isVerified(investor));

        // Still verified after 5 years
        vm.warp(block.timestamp + 5 * 365 days);
        assertTrue(verifier.isVerified(investor));

        // Not verified after 10 years
        vm.warp(block.timestamp + 5 * 365 days + 1 days);
        assertFalse(verifier.isVerified(investor));
    }
}
