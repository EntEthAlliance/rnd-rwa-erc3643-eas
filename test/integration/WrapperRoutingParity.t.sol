// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {EASClaimVerifier} from "../../contracts/EASClaimVerifier.sol";
import {EASClaimVerifierIdentityWrapper} from "../../contracts/EASClaimVerifierIdentityWrapper.sol";
import {EASTrustedIssuersAdapter} from "../../contracts/EASTrustedIssuersAdapter.sol";
import {MockEAS} from "../../contracts/mocks/MockEAS.sol";
import {MockClaimTopicsRegistry} from "../../contracts/mocks/MockClaimTopicsRegistry.sol";
import {MockAttester} from "../../contracts/mocks/MockAttester.sol";
import {ValenceEASKernelAdapter} from "../../contracts/valence/ValenceEASKernelAdapter.sol";
import {CompatibilityWrapperOrbital} from "../../contracts/valence/modules/CompatibilityWrapperOrbital.sol";
import {IIdentity} from "../../contracts/interfaces/IIdentity.sol";

/**
 * @title WrapperRoutingParityTest
 * @notice Integration tests ensuring parity between legacy EASClaimVerifierIdentityWrapper
 *         and the new Valence-based CompatibilityWrapperOrbital (Path B parity)
 * @dev These tests verify that the Valence path produces identical IIdentity behavior
 *      to the legacy production path, ensuring zero regression for Path B integrations.
 */
contract WrapperRoutingParityTest is Test {
    // ============ Constants ============

    uint256 internal constant TOPIC_KYC = 1;
    uint256 internal constant TOPIC_ACCREDITATION = 2;
    bytes32 internal constant SCHEMA_KYC = keccak256("KYC_SCHEMA");
    bytes32 internal constant SCHEMA_ACCREDITATION = keccak256("ACCREDITATION_SCHEMA");

    // ============ Core Infrastructure ============

    address internal owner = address(this);
    address internal identityAddress = address(0xB0B);

    MockEAS internal eas;
    MockClaimTopicsRegistry internal claimTopics;
    MockAttester internal kycAttester;
    MockAttester internal accreditationAttester;

    // ============ Legacy Path (Production) ============

    EASClaimVerifier internal legacyVerifier;
    EASTrustedIssuersAdapter internal trustedIssuers;
    EASClaimVerifierIdentityWrapper internal legacyWrapper;

    // ============ Valence Path ============

    ValenceEASKernelAdapter internal valence;
    CompatibilityWrapperOrbital internal valenceWrapper;

    // ============ Setup ============

    function setUp() public {
        // Deploy shared infrastructure
        eas = new MockEAS();
        claimTopics = new MockClaimTopicsRegistry();
        kycAttester = new MockAttester(address(eas), "KYC");
        accreditationAttester = new MockAttester(address(eas), "Accreditation");

        // === Setup Legacy Path ===
        legacyVerifier = new EASClaimVerifier(owner);
        trustedIssuers = new EASTrustedIssuersAdapter(owner);

        legacyVerifier.setEASAddress(address(eas));
        legacyVerifier.setTrustedIssuersAdapter(address(trustedIssuers));
        legacyVerifier.setClaimTopicsRegistry(address(claimTopics));
        legacyVerifier.setTopicSchemaMapping(TOPIC_KYC, SCHEMA_KYC);
        legacyVerifier.setTopicSchemaMapping(TOPIC_ACCREDITATION, SCHEMA_ACCREDITATION);

        uint256[] memory kycTopic = new uint256[](1);
        kycTopic[0] = TOPIC_KYC;
        trustedIssuers.addTrustedAttester(address(kycAttester), kycTopic);

        uint256[] memory accTopic = new uint256[](1);
        accTopic[0] = TOPIC_ACCREDITATION;
        trustedIssuers.addTrustedAttester(address(accreditationAttester), accTopic);

        // Deploy legacy wrapper for identity
        legacyWrapper = new EASClaimVerifierIdentityWrapper(
            identityAddress, address(eas), address(legacyVerifier), address(trustedIssuers)
        );

        // === Setup Valence Path ===
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

        uint256[] memory requiredTopics = new uint256[](1);
        requiredTopics[0] = TOPIC_KYC;
        claimTopics.setClaimTopics(requiredTopics);
        valence.verificationOrbital().setRequiredClaimTopics(requiredTopics);

        // Deploy Valence wrapper for identity
        valenceWrapper = new CompatibilityWrapperOrbital(
            owner,
            identityAddress,
            address(eas),
            address(valence.registryOrbital()),
            address(valence.trustedAttestersOrbital()),
            address(valence.verificationOrbital())
        );
    }

    // ============ Helper Functions ============

    function _registerAttestationBothPaths(bytes32 uid, uint256 topic, address attester) internal {
        legacyVerifier.registerAttestation(identityAddress, topic, uid);
        valence.registryOrbital().registerAttestation(identityAddress, topic, attester, uid);
    }

    function _assertClaimParity(bytes32 claimId) internal view {
        (
            uint256 legacyTopic,
            uint256 legacyScheme,
            address legacyIssuer,
            bytes memory legacySig,
            bytes memory legacyData,
            string memory legacyUri
        ) = legacyWrapper.getClaim(claimId);

        (
            uint256 valenceTopic,
            uint256 valenceScheme,
            address valenceIssuer,
            bytes memory valenceSig,
            bytes memory valenceData,
            string memory valenceUri
        ) = valenceWrapper.getClaim(claimId);

        assertEq(legacyTopic, valenceTopic, "topic mismatch");
        assertEq(legacyScheme, valenceScheme, "scheme mismatch");
        assertEq(legacyIssuer, valenceIssuer, "issuer mismatch");
        assertEq(keccak256(legacySig), keccak256(valenceSig), "signature mismatch");
        assertEq(keccak256(legacyData), keccak256(valenceData), "data mismatch");
        assertEq(keccak256(bytes(legacyUri)), keccak256(bytes(valenceUri)), "uri mismatch");
    }

    function _assertIsClaimValidParity(uint256 topic, bool expected) internal view {
        bool legacyResult = legacyWrapper.isClaimValid(IIdentity(address(legacyWrapper)), topic, "", "");
        bool valenceResult = valenceWrapper.isClaimValid(IIdentity(address(valenceWrapper)), topic, "", "");

        assertEq(legacyResult, expected, "legacy isClaimValid mismatch");
        assertEq(valenceResult, expected, "valence isClaimValid mismatch");
    }

    // ============ Parity Tests: getClaim ============

    function test_wrapperParity_getClaim_validAttestation() public {
        bytes32 uid = kycAttester.attestInvestorEligibility(SCHEMA_KYC, identityAddress, identityAddress, 1, 0, 840, 0);
        _registerAttestationBothPaths(uid, TOPIC_KYC, address(kycAttester));

        bytes32 claimId = keccak256(abi.encode(address(kycAttester), TOPIC_KYC));
        _assertClaimParity(claimId);

        // Verify non-empty result
        (uint256 topic,,,,,) = valenceWrapper.getClaim(claimId);
        assertEq(topic, TOPIC_KYC, "should return valid claim");
    }

    function test_wrapperParity_getClaim_unknownClaimId() public view {
        bytes32 unknownClaimId = keccak256(abi.encode(address(0xDEAD), uint256(999)));
        _assertClaimParity(unknownClaimId);

        // Both should return empty
        (uint256 legacyTopic,,,,,) = legacyWrapper.getClaim(unknownClaimId);
        (uint256 valenceTopic,,,,,) = valenceWrapper.getClaim(unknownClaimId);

        assertEq(legacyTopic, 0, "legacy should return empty");
        assertEq(valenceTopic, 0, "valence should return empty");
    }

    function test_wrapperParity_getClaim_noRegisteredAttestation() public view {
        // Claim ID format is valid but no attestation registered
        bytes32 claimId = keccak256(abi.encode(address(kycAttester), TOPIC_KYC));
        _assertClaimParity(claimId);

        (uint256 topic,,,,,) = valenceWrapper.getClaim(claimId);
        assertEq(topic, 0, "should return empty when no attestation registered");
    }

    // ============ Parity Tests: getClaimIdsByTopic ============

    function test_wrapperParity_getClaimIdsByTopic_withValidAttestations() public {
        bytes32 uid = kycAttester.attestInvestorEligibility(SCHEMA_KYC, identityAddress, identityAddress, 1, 0, 840, 0);
        _registerAttestationBothPaths(uid, TOPIC_KYC, address(kycAttester));

        bytes32[] memory legacyIds = legacyWrapper.getClaimIdsByTopic(TOPIC_KYC);
        bytes32[] memory valenceIds = valenceWrapper.getClaimIdsByTopic(TOPIC_KYC);

        assertEq(legacyIds.length, valenceIds.length, "claim count mismatch");
        assertEq(legacyIds.length, 1, "should have one claim");

        // Note: Order might differ but contents should match
        assertEq(legacyIds[0], valenceIds[0], "claim ID mismatch");
    }

    function test_wrapperParity_getClaimIdsByTopic_emptyForNoAttestations() public view {
        bytes32[] memory legacyIds = legacyWrapper.getClaimIdsByTopic(TOPIC_KYC);
        bytes32[] memory valenceIds = valenceWrapper.getClaimIdsByTopic(TOPIC_KYC);

        assertEq(legacyIds.length, 0, "legacy should be empty");
        assertEq(valenceIds.length, 0, "valence should be empty");
    }

    function test_wrapperParity_getClaimIdsByTopic_multipleAttesters() public {
        // Add second attester
        MockAttester kycAttester2 = new MockAttester(address(eas), "KYC2");
        uint256[] memory kycTopic = new uint256[](1);
        kycTopic[0] = TOPIC_KYC;
        trustedIssuers.addTrustedAttester(address(kycAttester2), kycTopic);
        valence.trustedAttestersOrbital().setTrustedAttester(TOPIC_KYC, address(kycAttester2), true);

        // Create attestations from both
        bytes32 uid1 = kycAttester.attestInvestorEligibility(SCHEMA_KYC, identityAddress, identityAddress, 1, 0, 840, 0);
        bytes32 uid2 =
            kycAttester2.attestInvestorEligibility(SCHEMA_KYC, identityAddress, identityAddress, 1, 0, 826, 0);

        _registerAttestationBothPaths(uid1, TOPIC_KYC, address(kycAttester));
        legacyVerifier.registerAttestation(identityAddress, TOPIC_KYC, uid2);
        valence.registryOrbital().registerAttestation(identityAddress, TOPIC_KYC, address(kycAttester2), uid2);

        bytes32[] memory legacyIds = legacyWrapper.getClaimIdsByTopic(TOPIC_KYC);
        bytes32[] memory valenceIds = valenceWrapper.getClaimIdsByTopic(TOPIC_KYC);

        assertEq(legacyIds.length, valenceIds.length, "claim count mismatch");
        assertEq(legacyIds.length, 2, "should have two claims");
    }

    // ============ Parity Tests: isClaimValid ============

    function test_wrapperParity_isClaimValid_validAttestation() public {
        bytes32 uid = kycAttester.attestInvestorEligibility(SCHEMA_KYC, identityAddress, identityAddress, 1, 0, 840, 0);
        _registerAttestationBothPaths(uid, TOPIC_KYC, address(kycAttester));

        _assertIsClaimValidParity(TOPIC_KYC, true);
    }

    function test_wrapperParity_isClaimValid_noAttestation() public view {
        _assertIsClaimValidParity(TOPIC_KYC, false);
    }

    function test_wrapperParity_isClaimValid_revokedAttestation() public {
        bytes32 uid = kycAttester.attestInvestorEligibility(SCHEMA_KYC, identityAddress, identityAddress, 1, 0, 840, 0);
        _registerAttestationBothPaths(uid, TOPIC_KYC, address(kycAttester));

        _assertIsClaimValidParity(TOPIC_KYC, true);

        eas.forceRevoke(uid);

        _assertIsClaimValidParity(TOPIC_KYC, false);
    }

    function test_wrapperParity_isClaimValid_expiredAttestation() public {
        // Use EAS-level expiration (not data-level) for parity test
        // Note: The legacy wrapper only checks EAS-level expiration in isClaimValid,
        // while the Valence path also checks data-level expiration via verifyTopic
        bytes memory data = abi.encode(identityAddress, uint8(1), uint8(0), uint16(840), uint64(0));
        bytes32 uid = kycAttester.attestCustom(SCHEMA_KYC, identityAddress, data, uint64(block.timestamp + 100), true);
        _registerAttestationBothPaths(uid, TOPIC_KYC, address(kycAttester));

        _assertIsClaimValidParity(TOPIC_KYC, true);

        vm.warp(block.timestamp + 101);

        _assertIsClaimValidParity(TOPIC_KYC, false);
    }

    // ============ Parity Tests: Trust Drift ============

    function test_wrapperParity_isClaimValid_attesterRemovedAfterAttestation() public {
        bytes32 uid = kycAttester.attestInvestorEligibility(SCHEMA_KYC, identityAddress, identityAddress, 1, 0, 840, 0);
        _registerAttestationBothPaths(uid, TOPIC_KYC, address(kycAttester));

        _assertIsClaimValidParity(TOPIC_KYC, true);

        // Remove attester
        trustedIssuers.removeTrustedAttester(address(kycAttester));
        valence.trustedAttestersOrbital().setTrustedAttester(TOPIC_KYC, address(kycAttester), false);

        _assertIsClaimValidParity(TOPIC_KYC, false);
    }

    // ============ Parity Tests: ERC-734 Key Functions ============

    function test_wrapperParity_getKey_managementKey() public view {
        bytes32 keyHash = keccak256(abi.encode(identityAddress));

        (uint256[] memory legacyPurposes, uint256 legacyKeyType, bytes32 legacyKey) = legacyWrapper.getKey(keyHash);
        (uint256[] memory valencePurposes, uint256 valenceKeyType, bytes32 valenceKey) = valenceWrapper.getKey(keyHash);

        assertEq(legacyPurposes.length, valencePurposes.length, "purposes length mismatch");
        assertEq(legacyPurposes[0], valencePurposes[0], "purpose mismatch");
        assertEq(legacyKeyType, valenceKeyType, "keyType mismatch");
        assertEq(legacyKey, valenceKey, "key mismatch");
    }

    function test_wrapperParity_getKey_unknownKey() public view {
        bytes32 unknownKey = bytes32(uint256(999));

        (uint256[] memory legacyPurposes, uint256 legacyKeyType, bytes32 legacyKey) = legacyWrapper.getKey(unknownKey);
        (uint256[] memory valencePurposes, uint256 valenceKeyType, bytes32 valenceKey) =
            valenceWrapper.getKey(unknownKey);

        assertEq(legacyPurposes.length, valencePurposes.length, "purposes length mismatch");
        assertEq(legacyPurposes.length, 0, "should be empty");
        assertEq(legacyKeyType, valenceKeyType, "keyType mismatch");
        assertEq(legacyKey, valenceKey, "key mismatch");
    }

    function test_wrapperParity_keyHasPurpose() public view {
        bytes32 keyHash = keccak256(abi.encode(identityAddress));

        bool legacyHasManagement = legacyWrapper.keyHasPurpose(keyHash, 1);
        bool valenceHasManagement = valenceWrapper.keyHasPurpose(keyHash, 1);
        assertEq(legacyHasManagement, valenceHasManagement, "management purpose mismatch");
        assertTrue(valenceHasManagement, "should have management purpose");

        bool legacyHasAction = legacyWrapper.keyHasPurpose(keyHash, 2);
        bool valenceHasAction = valenceWrapper.keyHasPurpose(keyHash, 2);
        assertEq(legacyHasAction, valenceHasAction, "action purpose mismatch");
        assertFalse(valenceHasAction, "should not have action purpose");
    }

    function test_wrapperParity_getKeysByPurpose() public view {
        bytes32[] memory legacyKeys = legacyWrapper.getKeysByPurpose(1);
        bytes32[] memory valenceKeys = valenceWrapper.getKeysByPurpose(1);

        assertEq(legacyKeys.length, valenceKeys.length, "keys length mismatch");
        assertEq(legacyKeys[0], valenceKeys[0], "key mismatch");
    }

    // ============ Parity Tests: Mutation Reverts ============

    function test_wrapperParity_addClaim_reverts() public {
        vm.expectRevert("Use EAS to create attestations");
        legacyWrapper.addClaim(TOPIC_KYC, 1, address(kycAttester), "", "", "");

        vm.expectRevert("Use EAS to create attestations");
        valenceWrapper.addClaim(TOPIC_KYC, 1, address(kycAttester), "", "", "");
    }

    function test_wrapperParity_removeClaim_reverts() public {
        vm.expectRevert("Use EAS to revoke attestations");
        legacyWrapper.removeClaim(bytes32(uint256(1)));

        vm.expectRevert("Use EAS to revoke attestations");
        valenceWrapper.removeClaim(bytes32(uint256(1)));
    }

    function test_wrapperParity_addKey_reverts() public {
        vm.expectRevert("Key management not supported");
        legacyWrapper.addKey(bytes32(uint256(1)), 1, 1);

        vm.expectRevert("Key management not supported");
        valenceWrapper.addKey(bytes32(uint256(1)), 1, 1);
    }

    function test_wrapperParity_removeKey_reverts() public {
        vm.expectRevert("Key management not supported");
        legacyWrapper.removeKey(bytes32(uint256(1)), 1);

        vm.expectRevert("Key management not supported");
        valenceWrapper.removeKey(bytes32(uint256(1)), 1);
    }

    function test_wrapperParity_approve_reverts() public {
        vm.expectRevert("Execution not supported");
        legacyWrapper.approve(1, true);

        vm.expectRevert("Execution not supported");
        valenceWrapper.approve(1, true);
    }

    function test_wrapperParity_execute_reverts() public {
        vm.expectRevert("Execution not supported");
        legacyWrapper.execute(address(0), 0, "");

        vm.expectRevert("Execution not supported");
        valenceWrapper.execute(address(0), 0, "");
    }

    // ============ Module Metadata Tests ============

    function test_valenceWrapper_moduleMetadata() public view {
        CompatibilityWrapperOrbital.ModuleMetadata memory meta = valenceWrapper.moduleMetadata();

        assertEq(meta.id, "compatibility-wrapper");
        assertEq(meta.version, "0.1.0-phase2");
        assertEq(meta.storageSlot, keccak256("eea.valence.orbital.compatibility-wrapper.storage.v1"));
    }

    function test_valenceWrapper_exportedSelectors() public view {
        bytes4[] memory selectors = valenceWrapper.exportedSelectors();

        assertEq(selectors.length, 4);
        assertEq(selectors[0], valenceWrapper.getClaim.selector);
        assertEq(selectors[1], valenceWrapper.getClaimIdsByTopic.selector);
        assertEq(selectors[2], valenceWrapper.isClaimValid.selector);
        assertEq(selectors[3], valenceWrapper.getIdentityAddress.selector);
    }

    function test_valenceWrapper_getIdentityAddress() public view {
        assertEq(valenceWrapper.getIdentityAddress(), identityAddress);
    }

    // ============ Constructor Validation ============

    function test_valenceWrapper_constructor_rejectsZeroIdentity() public {
        // Cache addresses before expectRevert (calls are not allowed between expectRevert and revert)
        address registryAddr = address(valence.registryOrbital());
        address trustedAttestersAddr = address(valence.trustedAttestersOrbital());
        address verificationAddr = address(valence.verificationOrbital());

        vm.expectRevert("identity=0");
        new CompatibilityWrapperOrbital(
            owner, address(0), address(eas), registryAddr, trustedAttestersAddr, verificationAddr
        );
    }

    function test_valenceWrapper_constructor_rejectsZeroEAS() public {
        address registryAddr = address(valence.registryOrbital());
        address trustedAttestersAddr = address(valence.trustedAttestersOrbital());
        address verificationAddr = address(valence.verificationOrbital());

        vm.expectRevert("eas=0");
        new CompatibilityWrapperOrbital(
            owner, identityAddress, address(0), registryAddr, trustedAttestersAddr, verificationAddr
        );
    }

    function test_valenceWrapper_constructor_rejectsZeroRegistry() public {
        address trustedAttestersAddr = address(valence.trustedAttestersOrbital());
        address verificationAddr = address(valence.verificationOrbital());

        vm.expectRevert("registry=0");
        new CompatibilityWrapperOrbital(
            owner, identityAddress, address(eas), address(0), trustedAttestersAddr, verificationAddr
        );
    }

    function test_valenceWrapper_constructor_rejectsZeroTrustedAttesters() public {
        address registryAddr = address(valence.registryOrbital());
        address verificationAddr = address(valence.verificationOrbital());

        vm.expectRevert("trustedAttesters=0");
        new CompatibilityWrapperOrbital(
            owner, identityAddress, address(eas), registryAddr, address(0), verificationAddr
        );
    }

    function test_valenceWrapper_constructor_rejectsZeroVerification() public {
        address registryAddr = address(valence.registryOrbital());
        address trustedAttestersAddr = address(valence.trustedAttestersOrbital());

        vm.expectRevert("verification=0");
        new CompatibilityWrapperOrbital(
            owner, identityAddress, address(eas), registryAddr, trustedAttestersAddr, address(0)
        );
    }
}
