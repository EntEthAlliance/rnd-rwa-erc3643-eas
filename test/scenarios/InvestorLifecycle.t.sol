// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {EASClaimVerifier} from "../../contracts/EASClaimVerifier.sol";
import {EASTrustedIssuersAdapter} from "../../contracts/EASTrustedIssuersAdapter.sol";
import {EASIdentityProxy} from "../../contracts/EASIdentityProxy.sol";
import {MockEAS} from "../../contracts/mocks/MockEAS.sol";
import {MockClaimTopicsRegistry} from "../../contracts/mocks/MockClaimTopicsRegistry.sol";
import {MockAttester} from "../../contracts/mocks/MockAttester.sol";
import {RevocationRequest, RevocationRequestData} from "@eas/IEAS.sol";

/**
 * @title InvestorLifecycleTest
 * @notice End-to-end scenario tests simulating complete investor lifecycle flows
 * @dev Tests cover realistic scenarios from initial KYC through revocation and renewal
 */
contract InvestorLifecycleTest is Test {
    // Contracts
    EASClaimVerifier public verifier;
    MockEAS public eas;
    EASTrustedIssuersAdapter public adapter;
    EASIdentityProxy public identityProxy;
    MockClaimTopicsRegistry public topicsRegistry;
    MockAttester public kycProvider;
    MockAttester public accreditationProvider;

    // Addresses - simulating real actors
    address public tokenIssuer = address(0x1000);
    address public complianceOfficer = address(0x2000);

    address public investor1Identity = address(0xABCD0001);
    address public investor1Wallet1 = address(0xABCD0002);
    address public investor1Wallet2 = address(0xABCD0003);

    address public investor2Identity = address(0xDEF00001);

    // Topic IDs
    uint256 public constant TOPIC_KYC = 1;
    uint256 public constant TOPIC_ACCREDITATION = 7;
    uint256 public constant TOPIC_COUNTRY = 3;

    bytes32 public schemaKYC = keccak256("InvestorEligibility");
    bytes32 public schemaAccreditation = keccak256("Accreditation");

    function setUp() public {
        // Deploy infrastructure (as test contract)
        eas = new MockEAS();
        topicsRegistry = new MockClaimTopicsRegistry();
        kycProvider = new MockAttester(address(eas), "Acme KYC Services");
        accreditationProvider = new MockAttester(address(eas), "Accreditation Corp");

        // Deploy and configure as token issuer
        vm.startPrank(tokenIssuer);

        adapter = new EASTrustedIssuersAdapter(tokenIssuer);
        identityProxy = new EASIdentityProxy(tokenIssuer);
        verifier = new EASClaimVerifier(tokenIssuer);

        verifier.setEASAddress(address(eas));
        verifier.setTrustedIssuersAdapter(address(adapter));
        verifier.setIdentityProxy(address(identityProxy));
        verifier.setClaimTopicsRegistry(address(topicsRegistry));

        // Map topics to schemas
        verifier.setTopicSchemaMapping(TOPIC_KYC, schemaKYC);
        verifier.setTopicSchemaMapping(TOPIC_ACCREDITATION, schemaAccreditation);

        // Add attesters as trusted
        uint256[] memory kycTopics = new uint256[](1);
        kycTopics[0] = TOPIC_KYC;
        adapter.addTrustedAttester(address(kycProvider), kycTopics);

        uint256[] memory accredTopics = new uint256[](1);
        accredTopics[0] = TOPIC_ACCREDITATION;
        adapter.addTrustedAttester(address(accreditationProvider), accredTopics);

        vm.stopPrank();

        // Set required topics for the token (test contract is owner of topicsRegistry)
        topicsRegistry.addClaimTopic(TOPIC_KYC);
    }

    // ============ Scenario 1: New Retail Investor Onboarding ============

    function test_scenario_retailInvestorOnboarding() public {
        /*
         * Scenario: A retail investor wants to buy security tokens
         *
         * Steps:
         * 1. Investor submits KYC documents to KYC provider
         * 2. KYC provider verifies and creates attestation
         * 3. Token agent registers investor's wallet
         * 4. Attestation is registered in the verifier
         * 5. Investor can now receive tokens
         */

        // Step 1-2: KYC provider creates attestation after verification
        bytes32 kycAttestation = kycProvider.attestInvestorEligibility(
            schemaKYC,
            investor1Identity,
            investor1Identity,
            1, // VERIFIED
            0, // NONE (retail)
            840, // USA
            uint64(block.timestamp + 365 days) // Valid for 1 year
        );

        // Step 3: Token agent registers investor wallet to identity
        vm.prank(tokenIssuer);
        identityProxy.registerWallet(investor1Wallet1, investor1Identity);

        // Before registration, investor is not verified
        assertFalse(verifier.isVerified(investor1Wallet1));

        // Step 4: Register attestation in verifier
        verifier.registerAttestation(investor1Identity, TOPIC_KYC, kycAttestation);

        // Step 5: Investor is now verified and can receive tokens
        assertTrue(verifier.isVerified(investor1Wallet1));
        assertTrue(verifier.isVerified(investor1Identity));
    }

    // ============ Scenario 2: Accredited Investor with Multi-Wallet Setup ============

    function test_scenario_accreditedInvestorMultiWallet() public {
        /*
         * Scenario: An accredited investor wants to use multiple wallets
         *
         * Steps:
         * 1. Investor completes KYC
         * 2. Investor provides accreditation proof
         * 3. Token issuer adds accreditation requirement
         * 4. Investor registers multiple wallets
         * 5. All wallets share the same verification status
         */

        // Token issuer adds accreditation requirement (test contract owns topicsRegistry)
        topicsRegistry.addClaimTopic(TOPIC_ACCREDITATION);

        // Step 1: KYC attestation
        bytes32 kycAttestation = kycProvider.attestInvestorEligibility(
            schemaKYC,
            investor1Identity,
            investor1Identity,
            1, // VERIFIED
            2, // ACCREDITED
            840,
            uint64(block.timestamp + 365 days)
        );
        verifier.registerAttestation(investor1Identity, TOPIC_KYC, kycAttestation);

        // At this point, investor is NOT verified (missing accreditation)
        assertFalse(verifier.isVerified(investor1Identity));

        // Step 2: Accreditation attestation
        bytes32 accredAttestation = accreditationProvider.attestInvestorEligibility(
            schemaAccreditation,
            investor1Identity,
            investor1Identity,
            1,
            2, // ACCREDITED
            840,
            uint64(block.timestamp + 365 days)
        );
        verifier.registerAttestation(investor1Identity, TOPIC_ACCREDITATION, accredAttestation);

        // Step 3: Register multiple wallets
        vm.startPrank(tokenIssuer);
        identityProxy.registerWallet(investor1Wallet1, investor1Identity);
        identityProxy.registerWallet(investor1Wallet2, investor1Identity);
        vm.stopPrank();

        // Step 4: All wallets are now verified
        assertTrue(verifier.isVerified(investor1Identity));
        assertTrue(verifier.isVerified(investor1Wallet1));
        assertTrue(verifier.isVerified(investor1Wallet2));
    }

    // ============ Scenario 3: KYC Expiration and Renewal ============

    function test_scenario_kycExpirationAndRenewal() public {
        /*
         * Scenario: An investor's KYC expires and they renew it
         *
         * Steps:
         * 1. Investor gets KYC attestation with 1 year validity
         * 2. After 1 year, verification fails
         * 3. Investor renews KYC
         * 4. Verification is restored
         */

        uint64 expirationTime = uint64(block.timestamp + 365 days);

        // Step 1: Initial KYC
        bytes32 initialKyc = kycProvider.attestInvestorEligibility(
            schemaKYC,
            investor1Identity,
            investor1Identity,
            1,
            0,
            840,
            expirationTime
        );
        verifier.registerAttestation(investor1Identity, TOPIC_KYC, initialKyc);

        assertTrue(verifier.isVerified(investor1Identity));

        // Step 2: Time passes, KYC expires
        vm.warp(expirationTime + 1);
        assertFalse(verifier.isVerified(investor1Identity));

        // Step 3: Investor renews KYC - new attestation created
        uint64 newExpirationTime = uint64(block.timestamp + 365 days);
        bytes32 renewedKyc = kycProvider.attestInvestorEligibility(
            schemaKYC,
            investor1Identity,
            investor1Identity,
            1,
            0,
            840,
            newExpirationTime
        );
        verifier.registerAttestation(investor1Identity, TOPIC_KYC, renewedKyc);

        // Step 4: Verification restored
        assertTrue(verifier.isVerified(investor1Identity));
    }

    // ============ Scenario 4: KYC Provider Compromise and Revocation ============

    function test_scenario_kycProviderCompromiseRevocation() public {
        /*
         * Scenario: A KYC provider is compromised and all their attestations must be invalidated
         *
         * Steps:
         * 1. Multiple investors verified by same KYC provider
         * 2. KYC provider is removed from trusted list
         * 3. All their attestations become invalid
         * 4. Investors must re-verify with different provider
         */

        // Add second KYC provider
        MockAttester backupKycProvider = new MockAttester(address(eas), "Backup KYC");
        vm.prank(tokenIssuer);
        uint256[] memory kycTopics = new uint256[](1);
        kycTopics[0] = TOPIC_KYC;
        adapter.addTrustedAttester(address(backupKycProvider), kycTopics);

        // Step 1: Both investors verified by primary KYC provider
        bytes32 kyc1 = kycProvider.attestInvestorEligibility(
            schemaKYC, investor1Identity, investor1Identity, 1, 0, 840, 0
        );
        verifier.registerAttestation(investor1Identity, TOPIC_KYC, kyc1);

        bytes32 kyc2 = kycProvider.attestInvestorEligibility(
            schemaKYC, investor2Identity, investor2Identity, 1, 0, 826, 0
        );
        verifier.registerAttestation(investor2Identity, TOPIC_KYC, kyc2);

        assertTrue(verifier.isVerified(investor1Identity));
        assertTrue(verifier.isVerified(investor2Identity));

        // Step 2: Primary KYC provider is compromised and removed
        vm.prank(tokenIssuer);
        adapter.removeTrustedAttester(address(kycProvider));

        // Step 3: All attestations from compromised provider are invalid
        assertFalse(verifier.isVerified(investor1Identity));
        assertFalse(verifier.isVerified(investor2Identity));

        // Step 4: Investors re-verify with backup provider
        bytes32 newKyc1 = backupKycProvider.attestInvestorEligibility(
            schemaKYC, investor1Identity, investor1Identity, 1, 0, 840, 0
        );
        verifier.registerAttestation(investor1Identity, TOPIC_KYC, newKyc1);

        assertTrue(verifier.isVerified(investor1Identity));
        assertFalse(verifier.isVerified(investor2Identity)); // Still invalid until re-verified
    }

    // ============ Scenario 5: Individual Attestation Revocation ============

    function test_scenario_individualRevocation() public {
        /*
         * Scenario: A specific investor's attestation is revoked due to fraud
         *
         * Steps:
         * 1. Two investors are verified
         * 2. One investor is found to have committed fraud
         * 3. Their attestation is revoked
         * 4. Other investor remains verified
         */

        // Step 1: Both investors verified
        bytes32 kyc1 = kycProvider.attestInvestorEligibility(
            schemaKYC, investor1Identity, investor1Identity, 1, 0, 840, 0
        );
        verifier.registerAttestation(investor1Identity, TOPIC_KYC, kyc1);

        bytes32 kyc2 = kycProvider.attestInvestorEligibility(
            schemaKYC, investor2Identity, investor2Identity, 1, 0, 826, 0
        );
        verifier.registerAttestation(investor2Identity, TOPIC_KYC, kyc2);

        assertTrue(verifier.isVerified(investor1Identity));
        assertTrue(verifier.isVerified(investor2Identity));

        // Step 2-3: Investor1's attestation is revoked due to fraud
        vm.prank(address(kycProvider));
        eas.revoke(
            RevocationRequest({
                schema: schemaKYC,
                data: RevocationRequestData({
                    uid: kyc1,
                    value: 0
                })
            })
        );

        // Step 4: Only the fraudulent investor is affected
        assertFalse(verifier.isVerified(investor1Identity));
        assertTrue(verifier.isVerified(investor2Identity));
    }

    // ============ Scenario 6: Regulatory Requirement Change ============

    function test_scenario_regulatoryRequirementChange() public {
        /*
         * Scenario: Token issuer must add new compliance requirement mid-lifecycle
         *
         * Steps:
         * 1. Token only requires KYC
         * 2. Investors are verified
         * 3. Regulation changes - accreditation now required
         * 4. Existing investors must obtain accreditation
         */

        // Step 1-2: Investors verified with KYC only
        bytes32 kyc1 = kycProvider.attestInvestorEligibility(
            schemaKYC, investor1Identity, investor1Identity, 1, 0, 840, 0
        );
        verifier.registerAttestation(investor1Identity, TOPIC_KYC, kyc1);

        bytes32 kyc2 = kycProvider.attestInvestorEligibility(
            schemaKYC, investor2Identity, investor2Identity, 1, 0, 826, 0
        );
        verifier.registerAttestation(investor2Identity, TOPIC_KYC, kyc2);

        assertTrue(verifier.isVerified(investor1Identity));
        assertTrue(verifier.isVerified(investor2Identity));

        // Step 3: Regulatory change - accreditation now required (test contract owns topicsRegistry)
        topicsRegistry.addClaimTopic(TOPIC_ACCREDITATION);

        // All investors now fail verification (missing accreditation)
        assertFalse(verifier.isVerified(investor1Identity));
        assertFalse(verifier.isVerified(investor2Identity));

        // Step 4: Investor1 obtains accreditation
        bytes32 accred1 = accreditationProvider.attestInvestorEligibility(
            schemaAccreditation, investor1Identity, investor1Identity, 1, 2, 840, 0
        );
        verifier.registerAttestation(investor1Identity, TOPIC_ACCREDITATION, accred1);

        // Now investor1 is verified, investor2 still not
        assertTrue(verifier.isVerified(investor1Identity));
        assertFalse(verifier.isVerified(investor2Identity));
    }

    // ============ Scenario 7: Wallet Lost and Recovery ============

    function test_scenario_walletLostAndRecovery() public {
        /*
         * Scenario: Investor loses access to a wallet and needs to use a new one
         *
         * Steps:
         * 1. Investor has verified identity with one wallet
         * 2. Wallet is compromised/lost
         * 3. Old wallet is removed
         * 4. New wallet is added to same identity
         * 5. Verification continues with new wallet
         */

        // Step 1: Initial setup with one wallet
        bytes32 kyc = kycProvider.attestInvestorEligibility(
            schemaKYC, investor1Identity, investor1Identity, 1, 0, 840, 0
        );
        verifier.registerAttestation(investor1Identity, TOPIC_KYC, kyc);

        vm.prank(tokenIssuer);
        identityProxy.registerWallet(investor1Wallet1, investor1Identity);

        assertTrue(verifier.isVerified(investor1Wallet1));

        // Step 2-3: Wallet1 is compromised and removed
        vm.prank(tokenIssuer);
        identityProxy.removeWallet(investor1Wallet1);

        // Old wallet can no longer use identity's attestations
        assertFalse(verifier.isVerified(investor1Wallet1));

        // Identity itself is still verified
        assertTrue(verifier.isVerified(investor1Identity));

        // Step 4-5: New wallet is added
        vm.prank(tokenIssuer);
        identityProxy.registerWallet(investor1Wallet2, investor1Identity);

        // New wallet inherits verification
        assertTrue(verifier.isVerified(investor1Wallet2));

        // Old wallet still cannot access
        assertFalse(verifier.isVerified(investor1Wallet1));
    }
}
