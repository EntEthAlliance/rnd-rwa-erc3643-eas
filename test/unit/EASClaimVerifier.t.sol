// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {EASClaimVerifier} from "../../contracts/EASClaimVerifier.sol";
import {EASTrustedIssuersAdapter} from "../../contracts/EASTrustedIssuersAdapter.sol";
import {EASIdentityProxy} from "../../contracts/EASIdentityProxy.sol";
import {MockEAS} from "../../contracts/mocks/MockEAS.sol";
import {MockClaimTopicsRegistry} from "../../contracts/mocks/MockClaimTopicsRegistry.sol";
import {IEASClaimVerifier} from "../../contracts/interfaces/IEASClaimVerifier.sol";
import {AttestationRequest, AttestationRequestData} from "@eas/IEAS.sol";

/**
 * @title EASClaimVerifierTest
 * @notice Unit tests for the EASClaimVerifier contract
 */
contract EASClaimVerifierTest is Test {
    EASClaimVerifier public verifier;
    MockEAS public eas;
    EASTrustedIssuersAdapter public adapter;
    EASIdentityProxy public identityProxy;
    MockClaimTopicsRegistry public topicsRegistry;

    address public owner = address(this);
    address public attester1 = address(0x1111111111111111111111111111111111111111);
    address public attester2 = address(0x2222222222222222222222222222222222222222);
    address public user1 = address(0x3333333333333333333333333333333333333333);
    address public user2 = address(0x4444444444444444444444444444444444444444);
    address public wallet1 = address(0x5555555555555555555555555555555555555555);
    address public identity1 = address(0x6666666666666666666666666666666666666666);

    uint256 public constant TOPIC_KYC = 1;
    uint256 public constant TOPIC_ACCREDITATION = 7;

    bytes32 public schemaKYC = keccak256("InvestorEligibilityKYC");
    bytes32 public schemaAccreditation = keccak256("InvestorEligibilityAccred");

    event TopicSchemaMappingSet(uint256 indexed claimTopic, bytes32 indexed schemaUID);
    event EASAddressSet(address indexed easAddress);
    event TrustedIssuersAdapterSet(address indexed adapterAddress);
    event IdentityProxySet(address indexed proxyAddress);
    event ClaimTopicsRegistrySet(address indexed registryAddress);
    event AttestationRegistered(
        address indexed identity, uint256 indexed claimTopic, address indexed attester, bytes32 attestationUID
    );

    function setUp() public {
        // Deploy mocks and contracts
        eas = new MockEAS();
        adapter = new EASTrustedIssuersAdapter(owner);
        identityProxy = new EASIdentityProxy(owner);
        topicsRegistry = new MockClaimTopicsRegistry();
        verifier = new EASClaimVerifier(owner);

        // Configure verifier
        verifier.setEASAddress(address(eas));
        verifier.setTrustedIssuersAdapter(address(adapter));
        verifier.setIdentityProxy(address(identityProxy));
        verifier.setClaimTopicsRegistry(address(topicsRegistry));

        // Map topics to schemas
        verifier.setTopicSchemaMapping(TOPIC_KYC, schemaKYC);
        verifier.setTopicSchemaMapping(TOPIC_ACCREDITATION, schemaAccreditation);

        // Authorize this test contract as an identity-proxy agent for registration calls
        identityProxy.addAgent(address(this));

        // Add trusted attester
        uint256[] memory topics = new uint256[](2);
        topics[0] = TOPIC_KYC;
        topics[1] = TOPIC_ACCREDITATION;
        adapter.addTrustedAttester(attester1, topics);
    }

    // ============ Configuration Tests ============

    function test_setEASAddress_success() public {
        address newEAS = address(0xEA52);

        vm.expectEmit(true, false, false, false);
        emit EASAddressSet(newEAS);

        verifier.setEASAddress(newEAS);
        assertEq(verifier.getEASAddress(), newEAS);
    }

    function test_setEASAddress_revertsIfZero() public {
        vm.expectRevert(IEASClaimVerifier.ZeroAddressNotAllowed.selector);
        verifier.setEASAddress(address(0));
    }

    function test_setTrustedIssuersAdapter_success() public {
        address newAdapter = address(0xAD72);

        vm.expectEmit(true, false, false, false);
        emit TrustedIssuersAdapterSet(newAdapter);

        verifier.setTrustedIssuersAdapter(newAdapter);
        assertEq(verifier.getTrustedIssuersAdapter(), newAdapter);
    }

    function test_setTrustedIssuersAdapter_revertsIfZero() public {
        vm.expectRevert(IEASClaimVerifier.ZeroAddressNotAllowed.selector);
        verifier.setTrustedIssuersAdapter(address(0));
    }

    function test_setIdentityProxy_success() public {
        address newProxy = address(0x9782);

        vm.expectEmit(true, false, false, false);
        emit IdentityProxySet(newProxy);

        verifier.setIdentityProxy(newProxy);
        assertEq(verifier.getIdentityProxy(), newProxy);
    }

    function test_setIdentityProxy_allowsZero() public {
        // Zero is allowed for identity proxy (direct wallet mode)
        verifier.setIdentityProxy(address(0));
        assertEq(verifier.getIdentityProxy(), address(0));
    }

    function test_setClaimTopicsRegistry_success() public {
        address newRegistry = address(0x8E62);

        vm.expectEmit(true, false, false, false);
        emit ClaimTopicsRegistrySet(newRegistry);

        verifier.setClaimTopicsRegistry(newRegistry);
        assertEq(verifier.getClaimTopicsRegistry(), newRegistry);
    }

    function test_setClaimTopicsRegistry_revertsIfZero() public {
        vm.expectRevert(IEASClaimVerifier.ZeroAddressNotAllowed.selector);
        verifier.setClaimTopicsRegistry(address(0));
    }

    function test_setTopicSchemaMapping_success() public {
        uint256 topic = 99;
        bytes32 schema = keccak256("CustomSchema");

        vm.expectEmit(true, true, false, false);
        emit TopicSchemaMappingSet(topic, schema);

        verifier.setTopicSchemaMapping(topic, schema);
        assertEq(verifier.getSchemaUID(topic), schema);
    }

    // ============ isVerified Tests ============

    function test_isVerified_noTopicsRequired_returnsTrue() public view {
        // No topics in registry
        assertTrue(verifier.isVerified(user1));
    }

    function test_isVerified_withValidAttestation_returnsTrue() public {
        // Setup: Add required topic
        topicsRegistry.addClaimTopic(TOPIC_KYC);

        // Create attestation
        bytes memory data = _encodeInvestorEligibility(
            user1,
            1, // VERIFIED
            0, // NONE
            840, // US
            0 // No expiration
        );

        bytes32 uid = _createAttestation(schemaKYC, user1, attester1, data, 0);

        // Register attestation
        verifier.registerAttestation(user1, TOPIC_KYC, uid);

        // Verify
        assertTrue(verifier.isVerified(user1));
    }

    function test_isVerified_noAttestation_returnsFalse() public {
        topicsRegistry.addClaimTopic(TOPIC_KYC);

        assertFalse(verifier.isVerified(user1));
    }

    function test_isVerified_revokedAttestation_returnsFalse() public {
        topicsRegistry.addClaimTopic(TOPIC_KYC);

        bytes memory data = _encodeInvestorEligibility(user1, 1, 0, 840, 0);
        bytes32 uid = _createAttestation(schemaKYC, user1, attester1, data, 0);
        verifier.registerAttestation(user1, TOPIC_KYC, uid);

        // Revoke attestation
        eas.forceRevoke(uid);

        assertFalse(verifier.isVerified(user1));
    }

    function test_isVerified_expiredAttestation_returnsFalse() public {
        topicsRegistry.addClaimTopic(TOPIC_KYC);

        // Set a known timestamp first
        vm.warp(1000);

        // Create attestation with expiration in the future
        uint64 expirationTime = uint64(block.timestamp + 100);
        bytes memory data = _encodeInvestorEligibility(user1, 1, 0, 840, expirationTime);
        bytes32 uid = _createAttestation(schemaKYC, user1, attester1, data, 0);
        verifier.registerAttestation(user1, TOPIC_KYC, uid);

        // Attestation is valid now
        assertTrue(verifier.isVerified(user1));

        // Warp past expiration
        vm.warp(expirationTime + 1);

        // Now should be expired
        assertFalse(verifier.isVerified(user1));
    }

    function test_isVerified_multipleTopics_allValid_returnsTrue() public {
        topicsRegistry.addClaimTopic(TOPIC_KYC);
        topicsRegistry.addClaimTopic(TOPIC_ACCREDITATION);

        // Create KYC attestation
        bytes memory kycData = _encodeInvestorEligibility(user1, 1, 0, 840, 0);
        bytes32 kycUid = _createAttestation(schemaKYC, user1, attester1, kycData, 0);
        verifier.registerAttestation(user1, TOPIC_KYC, kycUid);

        // Create accreditation attestation
        bytes memory accredData = _encodeInvestorEligibility(user1, 1, 2, 840, 0);
        bytes32 accredUid = _createAttestation(schemaAccreditation, user1, attester1, accredData, 0);
        verifier.registerAttestation(user1, TOPIC_ACCREDITATION, accredUid);

        assertTrue(verifier.isVerified(user1));
    }

    function test_isVerified_multipleTopics_oneMissing_returnsFalse() public {
        topicsRegistry.addClaimTopic(TOPIC_KYC);
        topicsRegistry.addClaimTopic(TOPIC_ACCREDITATION);

        // Only create KYC attestation
        bytes memory kycData = _encodeInvestorEligibility(user1, 1, 0, 840, 0);
        bytes32 kycUid = _createAttestation(schemaKYC, user1, attester1, kycData, 0);
        verifier.registerAttestation(user1, TOPIC_KYC, kycUid);

        assertFalse(verifier.isVerified(user1));
    }

    function test_isVerified_withIdentityProxy_resolvesWallet() public {
        topicsRegistry.addClaimTopic(TOPIC_KYC);

        // Register wallet to identity
        identityProxy.registerWallet(wallet1, identity1);

        // Create attestation for identity (not wallet)
        bytes memory data = _encodeInvestorEligibility(identity1, 1, 0, 840, 0);
        bytes32 uid = _createAttestation(schemaKYC, identity1, attester1, data, 0);
        verifier.registerAttestation(identity1, TOPIC_KYC, uid);

        // Verify wallet (should resolve to identity)
        assertTrue(verifier.isVerified(wallet1));
    }

    function test_isVerified_noIdentityProxy_usesWalletDirectly() public {
        verifier.setIdentityProxy(address(0));
        topicsRegistry.addClaimTopic(TOPIC_KYC);

        bytes memory data = _encodeInvestorEligibility(user1, 1, 0, 840, 0);
        bytes32 uid = _createAttestation(schemaKYC, user1, attester1, data, 0);
        vm.prank(attester1);
        verifier.registerAttestation(user1, TOPIC_KYC, uid);

        assertTrue(verifier.isVerified(user1));
    }

    function test_isVerified_noSchemaMapping_returnsFalse() public {
        topicsRegistry.addClaimTopic(99); // Topic with no schema mapping

        assertFalse(verifier.isVerified(user1));
    }

    function test_isVerified_noTrustedAttesters_returnsFalse() public {
        topicsRegistry.addClaimTopic(TOPIC_KYC);

        // Remove all attesters
        adapter.removeTrustedAttester(attester1);

        assertFalse(verifier.isVerified(user1));
    }

    // ============ registerAttestation Tests ============

    function test_registerAttestation_success() public {
        bytes memory data = _encodeInvestorEligibility(user1, 1, 0, 840, 0);
        bytes32 uid = _createAttestation(schemaKYC, user1, attester1, data, 0);

        vm.expectEmit(true, true, true, true);
        emit AttestationRegistered(user1, TOPIC_KYC, attester1, uid);

        vm.prank(attester1);
        verifier.registerAttestation(user1, TOPIC_KYC, uid);

        assertEq(verifier.getRegisteredAttestation(user1, TOPIC_KYC, attester1), uid);
    }

    function test_registerAttestation_revertsIfEASNotConfigured() public {
        EASClaimVerifier newVerifier = new EASClaimVerifier(owner);
        newVerifier.setTrustedIssuersAdapter(address(adapter));

        vm.expectRevert(IEASClaimVerifier.EASNotConfigured.selector);
        newVerifier.registerAttestation(user1, TOPIC_KYC, bytes32(uint256(1)));
    }

    function test_registerAttestation_revertsIfAdapterNotConfigured() public {
        EASClaimVerifier newVerifier = new EASClaimVerifier(owner);
        newVerifier.setEASAddress(address(eas));

        vm.expectRevert(IEASClaimVerifier.TrustedIssuersAdapterNotConfigured.selector);
        newVerifier.registerAttestation(user1, TOPIC_KYC, bytes32(uint256(1)));
    }

    function test_registerAttestation_revertsIfSchemaNotMapped() public {
        bytes memory data = _encodeInvestorEligibility(user1, 1, 0, 840, 0);
        bytes32 uid = _createAttestation(schemaKYC, user1, attester1, data, 0);

        vm.expectRevert(abi.encodeWithSelector(IEASClaimVerifier.SchemaNotMappedForTopic.selector, 99));
        verifier.registerAttestation(user1, 99, uid);
    }

    function test_registerAttestation_revertsIfAttestationNotFound() public {
        bytes32 fakeUid = bytes32(uint256(999));

        vm.expectRevert("Attestation not found");
        verifier.registerAttestation(user1, TOPIC_KYC, fakeUid);
    }

    function test_registerAttestation_revertsIfSchemaMismatch() public {
        // Create attestation with wrong schema
        bytes memory data = _encodeInvestorEligibility(user1, 1, 0, 840, 0);
        bytes32 uid = _createAttestation(schemaAccreditation, user1, attester1, data, 0);

        vm.expectRevert("Schema mismatch");
        verifier.registerAttestation(user1, TOPIC_KYC, uid);
    }

    function test_registerAttestation_revertsIfRecipientMismatch() public {
        bytes memory data = _encodeInvestorEligibility(user2, 1, 0, 840, 0);
        bytes32 uid = _createAttestation(schemaKYC, user2, attester1, data, 0);

        vm.expectRevert("Recipient mismatch");
        verifier.registerAttestation(user1, TOPIC_KYC, uid);
    }

    function test_registerAttestation_revertsIfAttesterNotTrusted() public {
        bytes memory data = _encodeInvestorEligibility(user1, 1, 0, 840, 0);
        bytes32 uid = _createAttestation(schemaKYC, user1, attester2, data, 0);

        vm.expectRevert("Attester not trusted");
        verifier.registerAttestation(user1, TOPIC_KYC, uid);
    }

    function test_registerAttestation_revertsIfCallerNotAuthorized() public {
        bytes memory data = _encodeInvestorEligibility(user1, 1, 0, 840, 0);
        bytes32 uid = _createAttestation(schemaKYC, user1, attester1, data, 0);

        vm.prank(user2);
        vm.expectRevert("Caller not authorized");
        verifier.registerAttestation(user1, TOPIC_KYC, uid);
    }

    function test_registerAttestation_allowsAuthorizedAgent() public {
        bytes memory data = _encodeInvestorEligibility(user1, 1, 0, 840, 0);
        bytes32 uid = _createAttestation(schemaKYC, user1, attester1, data, 0);

        address relayer = makeAddr("relayer");
        identityProxy.addAgent(relayer);

        vm.prank(relayer);
        verifier.registerAttestation(user1, TOPIC_KYC, uid);

        assertEq(verifier.getRegisteredAttestation(user1, TOPIC_KYC, attester1), uid);
    }

    // ============ Error State Tests ============

    function test_isVerified_revertsIfEASNotConfigured() public {
        EASClaimVerifier newVerifier = new EASClaimVerifier(owner);
        newVerifier.setTrustedIssuersAdapter(address(adapter));
        newVerifier.setClaimTopicsRegistry(address(topicsRegistry));

        vm.expectRevert(IEASClaimVerifier.EASNotConfigured.selector);
        newVerifier.isVerified(user1);
    }

    function test_isVerified_revertsIfAdapterNotConfigured() public {
        EASClaimVerifier newVerifier = new EASClaimVerifier(owner);
        newVerifier.setEASAddress(address(eas));
        newVerifier.setClaimTopicsRegistry(address(topicsRegistry));

        vm.expectRevert(IEASClaimVerifier.TrustedIssuersAdapterNotConfigured.selector);
        newVerifier.isVerified(user1);
    }

    function test_isVerified_revertsIfTopicsRegistryNotConfigured() public {
        EASClaimVerifier newVerifier = new EASClaimVerifier(owner);
        newVerifier.setEASAddress(address(eas));
        newVerifier.setTrustedIssuersAdapter(address(adapter));

        vm.expectRevert(IEASClaimVerifier.ClaimTopicsRegistryNotConfigured.selector);
        newVerifier.isVerified(user1);
    }

    // ============ EAS-Level Expiration Tests ============

    function test_isVerified_easLevelExpiration_valid() public {
        topicsRegistry.addClaimTopic(TOPIC_KYC);

        bytes memory data = _encodeInvestorEligibility(user1, 1, 0, 840, 0);
        bytes32 uid = _createAttestation(
            schemaKYC,
            user1,
            attester1,
            data,
            uint64(block.timestamp + 1 days) // Future expiration
        );
        verifier.registerAttestation(user1, TOPIC_KYC, uid);

        assertTrue(verifier.isVerified(user1));
    }

    function test_isVerified_easLevelExpiration_expired() public {
        topicsRegistry.addClaimTopic(TOPIC_KYC);

        bytes memory data = _encodeInvestorEligibility(user1, 1, 0, 840, 0);
        bytes32 uid = _createAttestation(
            schemaKYC,
            user1,
            attester1,
            data,
            uint64(block.timestamp + 1) // Almost immediate expiration
        );
        verifier.registerAttestation(user1, TOPIC_KYC, uid);

        // Advance time past expiration
        vm.warp(block.timestamp + 2);

        assertFalse(verifier.isVerified(user1));
    }

    // ============ Helper Functions ============

    function _encodeInvestorEligibility(
        address identity,
        uint8 kycStatus,
        uint8 accreditationType,
        uint16 countryCode,
        uint64 expirationTimestamp
    ) internal pure returns (bytes memory) {
        return abi.encode(identity, kycStatus, accreditationType, countryCode, expirationTimestamp);
    }

    function _createAttestation(
        bytes32 schema,
        address recipient,
        address attester,
        bytes memory data,
        uint64 expirationTime
    ) internal returns (bytes32) {
        AttestationRequest memory request = AttestationRequest({
            schema: schema,
            data: AttestationRequestData({
                recipient: recipient,
                expirationTime: expirationTime,
                revocable: true,
                refUID: bytes32(0),
                data: data,
                value: 0
            })
        });

        return eas.attestFrom(request, attester);
    }
}
