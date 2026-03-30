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
 * @title AttestationRevocationTest
 * @notice Integration tests for all revocation scenarios
 * @dev Tests as specified in PRD:
 * 1. Attester revokes attestation → immediate effect on transfer eligibility
 * 2. Attestation expires by timestamp → effect on transfer eligibility
 * 3. Trusted attester is removed from adapter → all their attestations become invalid
 * 4. Attester is re-added → attestations become valid again
 */
contract AttestationRevocationTest is Test {
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
    address public investor3;

    // ============ Constants ============
    uint256 public constant TOPIC_KYC = 1;
    bytes32 public constant SCHEMA_KYC = keccak256("KYC_SCHEMA");

    function setUp() public {
        tokenIssuer = makeAddr("tokenIssuer");
        investor1 = makeAddr("investor1");
        investor2 = makeAddr("investor2");
        investor3 = makeAddr("investor3");

        mockEAS = new MockEAS();
        claimTopicsRegistry = new MockClaimTopicsRegistry();
        kycProvider = new MockAttester(address(mockEAS), "Acme KYC");
        kycProviderAddr = address(kycProvider);

        vm.startPrank(tokenIssuer);

        trustedIssuers = new EASTrustedIssuersAdapter(tokenIssuer);
        identityProxy = new EASIdentityProxy(tokenIssuer);
        verifier = new EASClaimVerifier(tokenIssuer);

        verifier.setEASAddress(address(mockEAS));
        verifier.setTrustedIssuersAdapter(address(trustedIssuers));
        verifier.setIdentityProxy(address(identityProxy));
        verifier.setClaimTopicsRegistry(address(claimTopicsRegistry));
        verifier.setTopicSchemaMapping(TOPIC_KYC, SCHEMA_KYC);

        uint256[] memory topics = new uint256[](1);
        topics[0] = TOPIC_KYC;
        trustedIssuers.addTrustedAttester(kycProviderAddr, topics);

        vm.stopPrank();

        claimTopicsRegistry.addClaimTopic(TOPIC_KYC);
    }

    /**
     * @notice Test 1: Attester revokes attestation - immediate effect
     */
    function test_attesterRevokesAttestation_immediateEffect() public {
        // Create and register attestation
        bytes32 attestationUID = kycProvider.attestInvestorEligibility(
            SCHEMA_KYC, investor1, investor1, 1, 0, 840, 0
        );
        verifier.registerAttestation(investor1, TOPIC_KYC, attestationUID);

        // Verify investor is eligible
        assertTrue(verifier.isVerified(investor1));

        // Attester revokes the attestation
        vm.prank(kycProviderAddr);
        mockEAS.revoke(
            RevocationRequest({
                schema: SCHEMA_KYC,
                data: RevocationRequestData({uid: attestationUID, value: 0})
            })
        );

        // Immediate effect - investor is no longer eligible
        assertFalse(verifier.isVerified(investor1));
    }

    /**
     * @notice Test 2a: Attestation expires by EAS-level timestamp
     */
    function test_attestationExpiresEASLevel() public {
        // Set a base timestamp
        vm.warp(1000);

        uint64 expirationTime = uint64(block.timestamp + 100);

        // Create attestation with EAS-level expiration
        bytes memory data = abi.encode(investor1, uint8(1), uint8(0), uint16(840), uint64(0));
        bytes32 attestationUID = kycProvider.attestCustom(
            SCHEMA_KYC,
            investor1,
            data,
            expirationTime,
            true
        );
        verifier.registerAttestation(investor1, TOPIC_KYC, attestationUID);

        // Initially verified
        assertTrue(verifier.isVerified(investor1));

        // Warp to just before expiration
        vm.warp(expirationTime - 1);
        assertTrue(verifier.isVerified(investor1));

        // Warp to expiration time
        vm.warp(expirationTime);
        assertFalse(verifier.isVerified(investor1));
    }

    /**
     * @notice Test 2b: Attestation expires by data-level timestamp
     */
    function test_attestationExpiresDataLevel() public {
        vm.warp(1000);

        uint64 dataExpiration = uint64(block.timestamp + 100);

        // Create attestation with data-level expiration (expirationTimestamp in data)
        bytes32 attestationUID = kycProvider.attestInvestorEligibility(
            SCHEMA_KYC,
            investor1,
            investor1,
            1,
            0,
            840,
            dataExpiration
        );
        verifier.registerAttestation(investor1, TOPIC_KYC, attestationUID);

        // Initially verified
        assertTrue(verifier.isVerified(investor1));

        // Warp to just before expiration
        vm.warp(dataExpiration - 1);
        assertTrue(verifier.isVerified(investor1));

        // Warp to expiration time
        vm.warp(dataExpiration);
        assertFalse(verifier.isVerified(investor1));
    }

    /**
     * @notice Test 3: Trusted attester removed - all attestations become invalid
     */
    function test_trustedAttesterRemoved_attestationsInvalid() public {
        // Create attestations for multiple investors from same provider
        bytes32 uid1 = kycProvider.attestInvestorEligibility(
            SCHEMA_KYC, investor1, investor1, 1, 0, 840, 0
        );
        bytes32 uid2 = kycProvider.attestInvestorEligibility(
            SCHEMA_KYC, investor2, investor2, 1, 0, 826, 0
        );
        bytes32 uid3 = kycProvider.attestInvestorEligibility(
            SCHEMA_KYC, investor3, investor3, 1, 0, 276, 0 // Germany
        );

        verifier.registerAttestation(investor1, TOPIC_KYC, uid1);
        verifier.registerAttestation(investor2, TOPIC_KYC, uid2);
        verifier.registerAttestation(investor3, TOPIC_KYC, uid3);

        // All investors are verified
        assertTrue(verifier.isVerified(investor1));
        assertTrue(verifier.isVerified(investor2));
        assertTrue(verifier.isVerified(investor3));

        // Remove the KYC provider from trusted attesters
        vm.prank(tokenIssuer);
        trustedIssuers.removeTrustedAttester(kycProviderAddr);

        // All investors lose verification immediately
        assertFalse(verifier.isVerified(investor1));
        assertFalse(verifier.isVerified(investor2));
        assertFalse(verifier.isVerified(investor3));
    }

    /**
     * @notice Test 4: Attester re-added - attestations become valid again
     */
    function test_attesterReAdded_attestationsValidAgain() public {
        // Create attestations
        bytes32 uid1 = kycProvider.attestInvestorEligibility(
            SCHEMA_KYC, investor1, investor1, 1, 0, 840, 0
        );
        bytes32 uid2 = kycProvider.attestInvestorEligibility(
            SCHEMA_KYC, investor2, investor2, 1, 0, 826, 0
        );

        verifier.registerAttestation(investor1, TOPIC_KYC, uid1);
        verifier.registerAttestation(investor2, TOPIC_KYC, uid2);

        // Both verified
        assertTrue(verifier.isVerified(investor1));
        assertTrue(verifier.isVerified(investor2));

        // Remove attester
        vm.prank(tokenIssuer);
        trustedIssuers.removeTrustedAttester(kycProviderAddr);

        // Both lose verification
        assertFalse(verifier.isVerified(investor1));
        assertFalse(verifier.isVerified(investor2));

        // Re-add the same attester
        vm.prank(tokenIssuer);
        uint256[] memory topics = new uint256[](1);
        topics[0] = TOPIC_KYC;
        trustedIssuers.addTrustedAttester(kycProviderAddr, topics);

        // Attestations are valid again (they were already registered)
        assertTrue(verifier.isVerified(investor1));
        assertTrue(verifier.isVerified(investor2));
    }

    /**
     * @notice Test combined: revocation + expiration + trusted removal
     */
    function test_combinedRevocationScenarios() public {
        vm.warp(1000);

        // Investor1: will be revoked
        bytes32 uid1 = kycProvider.attestInvestorEligibility(
            SCHEMA_KYC, investor1, investor1, 1, 0, 840, 0
        );
        verifier.registerAttestation(investor1, TOPIC_KYC, uid1);

        // Investor2: will expire
        uint64 expiration = uint64(block.timestamp + 100);
        bytes32 uid2 = kycProvider.attestInvestorEligibility(
            SCHEMA_KYC, investor2, investor2, 1, 0, 826, expiration
        );
        verifier.registerAttestation(investor2, TOPIC_KYC, uid2);

        // Investor3: normal attestation
        bytes32 uid3 = kycProvider.attestInvestorEligibility(
            SCHEMA_KYC, investor3, investor3, 1, 0, 276, 0
        );
        verifier.registerAttestation(investor3, TOPIC_KYC, uid3);

        // All verified initially
        assertTrue(verifier.isVerified(investor1));
        assertTrue(verifier.isVerified(investor2));
        assertTrue(verifier.isVerified(investor3));

        // Revoke investor1's attestation
        vm.prank(kycProviderAddr);
        mockEAS.revoke(
            RevocationRequest({
                schema: SCHEMA_KYC,
                data: RevocationRequestData({uid: uid1, value: 0})
            })
        );

        // Investor1 loses verification
        assertFalse(verifier.isVerified(investor1));
        assertTrue(verifier.isVerified(investor2));
        assertTrue(verifier.isVerified(investor3));

        // Warp past investor2's expiration
        vm.warp(expiration);

        // Investor2 loses verification
        assertFalse(verifier.isVerified(investor1));
        assertFalse(verifier.isVerified(investor2));
        assertTrue(verifier.isVerified(investor3));

        // Remove trusted attester
        vm.prank(tokenIssuer);
        trustedIssuers.removeTrustedAttester(kycProviderAddr);

        // All lose verification
        assertFalse(verifier.isVerified(investor1));
        assertFalse(verifier.isVerified(investor2));
        assertFalse(verifier.isVerified(investor3));
    }

    /**
     * @notice Test: partial revocation in multi-attestation scenario
     */
    function test_partialRevocationMultiAttestation() public {
        // Add second provider
        MockAttester secondProvider = new MockAttester(address(mockEAS), "Second KYC");
        vm.prank(tokenIssuer);
        uint256[] memory topics = new uint256[](1);
        topics[0] = TOPIC_KYC;
        trustedIssuers.addTrustedAttester(address(secondProvider), topics);

        // Investor has attestations from both providers
        bytes32 uid1 = kycProvider.attestInvestorEligibility(
            SCHEMA_KYC, investor1, investor1, 1, 0, 840, 0
        );
        bytes32 uid2 = secondProvider.attestInvestorEligibility(
            SCHEMA_KYC, investor1, investor1, 1, 0, 840, 0
        );

        verifier.registerAttestation(investor1, TOPIC_KYC, uid1);
        verifier.registerAttestation(investor1, TOPIC_KYC, uid2);

        assertTrue(verifier.isVerified(investor1));

        // Revoke one attestation
        mockEAS.forceRevoke(uid1);

        // Still verified via second provider
        assertTrue(verifier.isVerified(investor1));

        // Revoke second attestation
        mockEAS.forceRevoke(uid2);

        // Now not verified
        assertFalse(verifier.isVerified(investor1));
    }
}
