// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {EASClaimVerifier} from "../../contracts/EASClaimVerifier.sol";
import {EASTrustedIssuersAdapter} from "../../contracts/EASTrustedIssuersAdapter.sol";
import {EASIdentityProxy} from "../../contracts/EASIdentityProxy.sol";
import {MockEAS} from "../../contracts/mocks/MockEAS.sol";
import {MockClaimTopicsRegistry} from "../../contracts/mocks/MockClaimTopicsRegistry.sol";
import {MockAttester} from "../../contracts/mocks/MockAttester.sol";
import {ValenceEASKernelAdapter} from "../../contracts/valence/ValenceEASKernelAdapter.sol";

contract LegacyValenceParityTest is Test {
    uint256 internal constant TOPIC_KYC = 1;
    uint256 internal constant TOPIC_ACCREDITATION = 2;
    bytes32 internal constant SCHEMA_KYC = keccak256("KYC_SCHEMA");
    bytes32 internal constant SCHEMA_ACCREDITATION = keccak256("ACCREDITATION_SCHEMA");

    address internal owner = address(this);
    address internal wallet = address(0xA11CE);
    address internal identity = address(0xB0B);

    MockEAS internal eas;
    MockClaimTopicsRegistry internal claimTopics;
    MockAttester internal kycAttester;
    MockAttester internal accreditationAttester;

    EASClaimVerifier internal legacy;
    EASTrustedIssuersAdapter internal trustedIssuers;
    EASIdentityProxy internal identityProxy;

    ValenceEASKernelAdapter internal valence;

    function setUp() public {
        eas = new MockEAS();
        claimTopics = new MockClaimTopicsRegistry();
        kycAttester = new MockAttester(address(eas), "KYC");
        accreditationAttester = new MockAttester(address(eas), "Accreditation");

        legacy = new EASClaimVerifier(owner);
        trustedIssuers = new EASTrustedIssuersAdapter(owner);
        identityProxy = new EASIdentityProxy(owner);

        legacy.setEASAddress(address(eas));
        legacy.setTrustedIssuersAdapter(address(trustedIssuers));
        legacy.setIdentityProxy(address(identityProxy));
        legacy.setClaimTopicsRegistry(address(claimTopics));
        legacy.setTopicSchemaMapping(TOPIC_KYC, SCHEMA_KYC);
        legacy.setTopicSchemaMapping(TOPIC_ACCREDITATION, SCHEMA_ACCREDITATION);

        uint256[] memory kycTopic = new uint256[](1);
        kycTopic[0] = TOPIC_KYC;
        trustedIssuers.addTrustedAttester(address(kycAttester), kycTopic);

        uint256[] memory accTopic = new uint256[](1);
        accTopic[0] = TOPIC_ACCREDITATION;
        trustedIssuers.addTrustedAttester(address(accreditationAttester), accTopic);

        identityProxy.registerWallet(wallet, identity);

        ValenceEASKernelAdapter.GovernanceProfile memory profile = ValenceEASKernelAdapter.GovernanceProfile({
            cutMultisig: address(0xA11CE), minApprovals: 2, standardCutTimelock: 24 hours, emergencyCutTimelock: 1 hours
        });
        valence = new ValenceEASKernelAdapter(owner, profile);

        valence.verificationOrbital()
            .setDependencies(
                address(eas),
                address(valence.registryOrbital()),
                address(valence.trustedAttestersOrbital()),
                address(valence.identityMappingOrbital())
            );
        valence.registryOrbital().setTopicSchemaMapping(TOPIC_KYC, SCHEMA_KYC);
        valence.registryOrbital().setTopicSchemaMapping(TOPIC_ACCREDITATION, SCHEMA_ACCREDITATION);
        valence.trustedAttestersOrbital().setTrustedAttester(TOPIC_KYC, address(kycAttester), true);
        valence.trustedAttestersOrbital().setTrustedAttester(TOPIC_ACCREDITATION, address(accreditationAttester), true);
        valence.identityMappingOrbital().setIdentity(wallet, identity);

        uint256[] memory requiredTopics = new uint256[](1);
        requiredTopics[0] = TOPIC_KYC;
        claimTopics.setClaimTopics(requiredTopics);
        valence.verificationOrbital().setRequiredClaimTopics(requiredTopics);
    }

    function test_parity_validAttestation() public {
        bytes32 uid = kycAttester.attestInvestorEligibility(SCHEMA_KYC, identity, identity, 1, 0, 840, 0);
        legacy.registerAttestation(identity, TOPIC_KYC, uid);
        valence.registryOrbital().registerAttestation(identity, TOPIC_KYC, address(kycAttester), uid);

        _assertParity(wallet, true);
    }

    function test_parity_revokedAttestation() public {
        bytes32 uid = kycAttester.attestInvestorEligibility(SCHEMA_KYC, identity, identity, 1, 0, 840, 0);
        legacy.registerAttestation(identity, TOPIC_KYC, uid);
        valence.registryOrbital().registerAttestation(identity, TOPIC_KYC, address(kycAttester), uid);

        eas.forceRevoke(uid);
        _assertParity(wallet, false);
    }

    function test_parity_expiredAttestation() public {
        bytes32 uid = kycAttester.attestInvestorEligibility(
            SCHEMA_KYC, identity, identity, 1, 0, 840, uint64(block.timestamp + 1)
        );
        legacy.registerAttestation(identity, TOPIC_KYC, uid);
        valence.registryOrbital().registerAttestation(identity, TOPIC_KYC, address(kycAttester), uid);

        vm.warp(block.timestamp + 2);
        _assertParity(wallet, false);
    }

    function test_parity_multiTopicRequirement() public {
        uint256[] memory requiredTopics = new uint256[](2);
        requiredTopics[0] = TOPIC_KYC;
        requiredTopics[1] = TOPIC_ACCREDITATION;
        claimTopics.setClaimTopics(requiredTopics);
        valence.verificationOrbital().setRequiredClaimTopics(requiredTopics);

        bytes32 kycUid = kycAttester.attestInvestorEligibility(SCHEMA_KYC, identity, identity, 1, 0, 840, 0);
        legacy.registerAttestation(identity, TOPIC_KYC, kycUid);
        valence.registryOrbital().registerAttestation(identity, TOPIC_KYC, address(kycAttester), kycUid);

        _assertParity(wallet, false);

        bytes32 accUid =
            accreditationAttester.attestInvestorEligibility(SCHEMA_ACCREDITATION, identity, identity, 1, 0, 840, 0);
        legacy.registerAttestation(identity, TOPIC_ACCREDITATION, accUid);
        valence.registryOrbital()
            .registerAttestation(identity, TOPIC_ACCREDITATION, address(accreditationAttester), accUid);

        _assertParity(wallet, true);
    }

    function test_parity_identityRemap() public {
        address remappedIdentity = address(0xD00D);
        identityProxy.removeWallet(wallet);
        identityProxy.registerWallet(wallet, remappedIdentity);
        valence.identityMappingOrbital().setIdentity(wallet, remappedIdentity);

        bytes32 uid =
            kycAttester.attestInvestorEligibility(SCHEMA_KYC, remappedIdentity, remappedIdentity, 1, 0, 840, 0);
        legacy.registerAttestation(remappedIdentity, TOPIC_KYC, uid);
        valence.registryOrbital().registerAttestation(remappedIdentity, TOPIC_KYC, address(kycAttester), uid);

        _assertParity(wallet, true);
    }

    function _assertParity(address subject, bool expected) internal view {
        bool legacyResult = legacy.isVerified(subject);
        bool valenceResult = valence.verificationOrbital().isVerified(subject);

        assertEq(legacyResult, expected, "legacy mismatch");
        assertEq(valenceResult, expected, "valence mismatch");
    }

    // ============ Edge-case Negative Parity Tests ============

    /**
     * @notice Test parity: schema mismatch rejection
     * @dev Both paths should reject attestations registered against the wrong schema
     */
    function test_parity_schemaMismatch() public {
        bytes32 WRONG_SCHEMA = keccak256("WRONG_SCHEMA");

        // Create attestation with wrong schema
        bytes32 uid = kycAttester.attestInvestorEligibility(WRONG_SCHEMA, identity, identity, 1, 0, 840, 0);

        // Attempting to register with wrong schema should fail on legacy
        vm.expectRevert("Schema mismatch");
        legacy.registerAttestation(identity, TOPIC_KYC, uid);

        // For Valence, registry doesn't validate schema at registration time,
        // but verification will fail because the attestation schema doesn't match
        valence.registryOrbital().registerAttestation(identity, TOPIC_KYC, address(kycAttester), uid);

        // Legacy has no registered attestation, Valence has one but it's invalid
        // Both should return false for verification
        assertFalse(legacy.isVerified(wallet), "legacy should reject schema mismatch");
        assertFalse(valence.verificationOrbital().isVerified(wallet), "valence should reject schema mismatch");
    }

    /**
     * @notice Test parity: trust drift (attester removed after attesting)
     * @dev Both paths should reject attestations from attesters no longer trusted
     */
    function test_parity_trustDrift_attesterRemoved() public {
        // Create and register valid attestation
        bytes32 uid = kycAttester.attestInvestorEligibility(SCHEMA_KYC, identity, identity, 1, 0, 840, 0);
        legacy.registerAttestation(identity, TOPIC_KYC, uid);
        valence.registryOrbital().registerAttestation(identity, TOPIC_KYC, address(kycAttester), uid);

        // Verify initially passes
        _assertParity(wallet, true);

        // Remove the attester from trusted list
        trustedIssuers.removeTrustedAttester(address(kycAttester));
        valence.trustedAttestersOrbital().setTrustedAttester(TOPIC_KYC, address(kycAttester), false);

        // Both should now reject - attester is no longer trusted
        _assertParity(wallet, false);
    }

    /**
     * @notice Test parity: trust drift with re-trust
     * @dev Both paths should accept attestations again once attester is re-trusted
     */
    function test_parity_trustDrift_attesterRetrused() public {
        // Create and register valid attestation
        bytes32 uid = kycAttester.attestInvestorEligibility(SCHEMA_KYC, identity, identity, 1, 0, 840, 0);
        legacy.registerAttestation(identity, TOPIC_KYC, uid);
        valence.registryOrbital().registerAttestation(identity, TOPIC_KYC, address(kycAttester), uid);

        _assertParity(wallet, true);

        // Remove attester
        trustedIssuers.removeTrustedAttester(address(kycAttester));
        valence.trustedAttestersOrbital().setTrustedAttester(TOPIC_KYC, address(kycAttester), false);

        _assertParity(wallet, false);

        // Re-add attester
        uint256[] memory kycTopic = new uint256[](1);
        kycTopic[0] = TOPIC_KYC;
        trustedIssuers.addTrustedAttester(address(kycAttester), kycTopic);
        valence.trustedAttestersOrbital().setTrustedAttester(TOPIC_KYC, address(kycAttester), true);

        // Both should pass again
        _assertParity(wallet, true);
    }

    /**
     * @notice Test parity: mixed-validity attestations for same identity (one valid, one revoked)
     * @dev Both paths should pass if at least one attestation from a trusted attester is valid
     */
    function test_parity_mixedValidity_oneValidOneRevoked() public {
        // Create second attester
        MockAttester kycAttester2 = new MockAttester(address(eas), "KYC2");

        // Add second attester as trusted for KYC topic
        uint256[] memory kycTopic = new uint256[](1);
        kycTopic[0] = TOPIC_KYC;
        trustedIssuers.addTrustedAttester(address(kycAttester2), kycTopic);
        valence.trustedAttestersOrbital().setTrustedAttester(TOPIC_KYC, address(kycAttester2), true);

        // Create attestations from both attesters
        bytes32 uid1 = kycAttester.attestInvestorEligibility(SCHEMA_KYC, identity, identity, 1, 0, 840, 0);
        bytes32 uid2 = kycAttester2.attestInvestorEligibility(SCHEMA_KYC, identity, identity, 1, 0, 840, 0);

        // Register both
        legacy.registerAttestation(identity, TOPIC_KYC, uid1);
        legacy.registerAttestation(identity, TOPIC_KYC, uid2);
        valence.registryOrbital().registerAttestation(identity, TOPIC_KYC, address(kycAttester), uid1);
        valence.registryOrbital().registerAttestation(identity, TOPIC_KYC, address(kycAttester2), uid2);

        // Both should pass with two valid attestations
        _assertParity(wallet, true);

        // Revoke first attestation
        eas.forceRevoke(uid1);

        // Should still pass - second attestation is valid
        _assertParity(wallet, true);

        // Revoke second attestation
        eas.forceRevoke(uid2);

        // Now both should fail - no valid attestations
        _assertParity(wallet, false);
    }

    /**
     * @notice Test parity: mixed-validity with one expired attestation
     * @dev Both paths should pass if at least one attestation is not expired
     */
    function test_parity_mixedValidity_oneValidOneExpired() public {
        // Create second attester
        MockAttester kycAttester2 = new MockAttester(address(eas), "KYC2");

        uint256[] memory kycTopic = new uint256[](1);
        kycTopic[0] = TOPIC_KYC;
        trustedIssuers.addTrustedAttester(address(kycAttester2), kycTopic);
        valence.trustedAttestersOrbital().setTrustedAttester(TOPIC_KYC, address(kycAttester2), true);

        // Create attestation with expiration
        bytes32 uid1 = kycAttester.attestInvestorEligibility(
            SCHEMA_KYC, identity, identity, 1, 0, 840, uint64(block.timestamp + 100)
        );
        // Create attestation without expiration
        bytes32 uid2 = kycAttester2.attestInvestorEligibility(SCHEMA_KYC, identity, identity, 1, 0, 840, 0);

        legacy.registerAttestation(identity, TOPIC_KYC, uid1);
        legacy.registerAttestation(identity, TOPIC_KYC, uid2);
        valence.registryOrbital().registerAttestation(identity, TOPIC_KYC, address(kycAttester), uid1);
        valence.registryOrbital().registerAttestation(identity, TOPIC_KYC, address(kycAttester2), uid2);

        _assertParity(wallet, true);

        // Expire the first attestation
        vm.warp(block.timestamp + 101);

        // Should still pass - second attestation has no expiration
        _assertParity(wallet, true);
    }

    /**
     * @notice Test parity: all attestations from multiple attesters are invalid
     * @dev Both paths should fail when all attestations are invalid (mixed reasons)
     */
    function test_parity_mixedValidity_allInvalid() public {
        MockAttester kycAttester2 = new MockAttester(address(eas), "KYC2");

        uint256[] memory kycTopic = new uint256[](1);
        kycTopic[0] = TOPIC_KYC;
        trustedIssuers.addTrustedAttester(address(kycAttester2), kycTopic);
        valence.trustedAttestersOrbital().setTrustedAttester(TOPIC_KYC, address(kycAttester2), true);

        // First attestation will be revoked
        bytes32 uid1 = kycAttester.attestInvestorEligibility(SCHEMA_KYC, identity, identity, 1, 0, 840, 0);
        // Second attestation will expire
        bytes32 uid2 = kycAttester2.attestInvestorEligibility(
            SCHEMA_KYC, identity, identity, 1, 0, 840, uint64(block.timestamp + 50)
        );

        legacy.registerAttestation(identity, TOPIC_KYC, uid1);
        legacy.registerAttestation(identity, TOPIC_KYC, uid2);
        valence.registryOrbital().registerAttestation(identity, TOPIC_KYC, address(kycAttester), uid1);
        valence.registryOrbital().registerAttestation(identity, TOPIC_KYC, address(kycAttester2), uid2);

        _assertParity(wallet, true);

        // Revoke first
        eas.forceRevoke(uid1);
        _assertParity(wallet, true); // Second still valid

        // Expire second
        vm.warp(block.timestamp + 51);

        // Now both should fail - one revoked, one expired
        _assertParity(wallet, false);
    }

    /**
     * @notice Test parity: no schema mapped for required topic
     * @dev Both paths should fail when a required topic has no schema mapping
     */
    function test_parity_noSchemaMapped() public {
        uint256 TOPIC_UNMAPPED = 999;

        // Set a new required topic that has no schema mapping
        uint256[] memory requiredTopics = new uint256[](2);
        requiredTopics[0] = TOPIC_KYC;
        requiredTopics[1] = TOPIC_UNMAPPED;
        claimTopics.setClaimTopics(requiredTopics);
        valence.verificationOrbital().setRequiredClaimTopics(requiredTopics);

        // Create valid KYC attestation
        bytes32 uid = kycAttester.attestInvestorEligibility(SCHEMA_KYC, identity, identity, 1, 0, 840, 0);
        legacy.registerAttestation(identity, TOPIC_KYC, uid);
        valence.registryOrbital().registerAttestation(identity, TOPIC_KYC, address(kycAttester), uid);

        // Both should fail - TOPIC_UNMAPPED has no schema
        _assertParity(wallet, false);
    }

    /**
     * @notice Test parity: no trusted attesters for a required topic
     * @dev Both paths should fail when a required topic has no trusted attesters
     */
    function test_parity_noTrustedAttesters() public {
        uint256 TOPIC_NO_ATTESTERS = 888;
        bytes32 SCHEMA_NO_ATTESTERS = keccak256("NO_ATTESTERS_SCHEMA");

        // Map schema but don't add any trusted attesters
        legacy.setTopicSchemaMapping(TOPIC_NO_ATTESTERS, SCHEMA_NO_ATTESTERS);
        valence.registryOrbital().setTopicSchemaMapping(TOPIC_NO_ATTESTERS, SCHEMA_NO_ATTESTERS);

        // Set required topics to include topic with no attesters
        uint256[] memory requiredTopics = new uint256[](2);
        requiredTopics[0] = TOPIC_KYC;
        requiredTopics[1] = TOPIC_NO_ATTESTERS;
        claimTopics.setClaimTopics(requiredTopics);
        valence.verificationOrbital().setRequiredClaimTopics(requiredTopics);

        // Create valid KYC attestation
        bytes32 uid = kycAttester.attestInvestorEligibility(SCHEMA_KYC, identity, identity, 1, 0, 840, 0);
        legacy.registerAttestation(identity, TOPIC_KYC, uid);
        valence.registryOrbital().registerAttestation(identity, TOPIC_KYC, address(kycAttester), uid);

        // Both should fail - no trusted attesters for TOPIC_NO_ATTESTERS
        _assertParity(wallet, false);
    }
}
