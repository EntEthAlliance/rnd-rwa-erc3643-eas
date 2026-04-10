// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {EASClaimVerifierIdentityWrapper} from "../../contracts/EASClaimVerifierIdentityWrapper.sol";
import {EASClaimVerifier} from "../../contracts/EASClaimVerifier.sol";
import {EASTrustedIssuersAdapter} from "../../contracts/EASTrustedIssuersAdapter.sol";
import {EASIdentityProxy} from "../../contracts/EASIdentityProxy.sol";
import {MockEAS} from "../../contracts/mocks/MockEAS.sol";
import {MockClaimTopicsRegistry} from "../../contracts/mocks/MockClaimTopicsRegistry.sol";
import {MockAttester} from "../../contracts/mocks/MockAttester.sol";
import {IIdentity} from "../../contracts/interfaces/IIdentity.sol";
import {AttestationRequest, AttestationRequestData} from "@eas/IEAS.sol";

/**
 * @title EASClaimVerifierIdentityWrapperTest
 * @notice Unit tests for the EASClaimVerifierIdentityWrapper (Path B implementation)
 */
contract EASClaimVerifierIdentityWrapperTest is Test {
    EASClaimVerifierIdentityWrapper public wrapper;
    EASClaimVerifier public verifier;
    MockEAS public eas;
    EASTrustedIssuersAdapter public adapter;
    EASIdentityProxy public identityProxy;
    MockClaimTopicsRegistry public topicsRegistry;
    MockAttester public kycProvider;

    address public owner = address(this);
    address public identityAddress = address(0x1D01);
    address public kycProviderAddr;

    uint256 public constant TOPIC_KYC = 1;
    uint256 public constant TOPIC_ACCREDITATION = 7;

    bytes32 public schemaKYC = keccak256("InvestorEligibility");

    function setUp() public {
        // Deploy infrastructure
        eas = new MockEAS();
        adapter = new EASTrustedIssuersAdapter(owner);
        identityProxy = new EASIdentityProxy(owner);
        topicsRegistry = new MockClaimTopicsRegistry();
        verifier = new EASClaimVerifier(owner);
        kycProvider = new MockAttester(address(eas), "Acme KYC");

        kycProviderAddr = address(kycProvider);

        // Configure verifier
        verifier.setEASAddress(address(eas));
        verifier.setTrustedIssuersAdapter(address(adapter));
        verifier.setIdentityProxy(address(identityProxy));
        verifier.setClaimTopicsRegistry(address(topicsRegistry));
        verifier.setTopicSchemaMapping(TOPIC_KYC, schemaKYC);

        // Add KYC provider as trusted attester
        uint256[] memory topics = new uint256[](1);
        topics[0] = TOPIC_KYC;
        adapter.addTrustedAttester(kycProviderAddr, topics);

        // Authorize test contract as agent for registerAttestation calls
        identityProxy.addAgent(address(this));

        // Deploy wrapper for identity
        wrapper =
            new EASClaimVerifierIdentityWrapper(identityAddress, address(eas), address(verifier), address(adapter));
    }

    // ============ Constructor Tests ============

    function test_constructor_setsIdentityAddress() public view {
        assertEq(wrapper.identityAddress(), identityAddress);
    }

    function test_constructor_setsEAS() public view {
        assertEq(address(wrapper.eas()), address(eas));
    }

    function test_constructor_setsClaimVerifier() public view {
        assertEq(address(wrapper.claimVerifier()), address(verifier));
    }

    function test_constructor_setsTrustedIssuersAdapter() public view {
        assertEq(address(wrapper.trustedIssuersAdapter()), address(adapter));
    }

    // ============ getClaim Tests ============

    function test_getClaim_returnsValidClaim() public {
        // Create and register attestation
        bytes32 uid = kycProvider.attestInvestorEligibility(
            schemaKYC,
            identityAddress,
            identityAddress,
            1, // VERIFIED
            0, // NONE
            840, // US
            0 // No expiration
        );
        verifier.registerAttestation(identityAddress, TOPIC_KYC, uid);

        // Get claim ID
        bytes32 claimId = keccak256(abi.encode(kycProviderAddr, TOPIC_KYC));

        // Get claim
        (uint256 topic, uint256 scheme, address issuer, bytes memory signature, bytes memory data, string memory uri) =
            wrapper.getClaim(claimId);

        assertEq(topic, TOPIC_KYC);
        assertEq(scheme, 1); // ECDSA-equivalent
        assertEq(issuer, kycProviderAddr);
        assertEq(signature.length, 0);
        assertTrue(data.length > 0);
        assertEq(bytes(uri).length, 0);
    }

    function test_getClaim_returnsEmptyForUnknownClaim() public view {
        bytes32 fakeClaimId = bytes32(uint256(999));

        (uint256 topic, uint256 scheme, address issuer, bytes memory signature, bytes memory data, string memory uri) =
            wrapper.getClaim(fakeClaimId);

        assertEq(topic, 0);
        assertEq(scheme, 0);
        assertEq(issuer, address(0));
        assertEq(signature.length, 0);
        assertEq(data.length, 0);
        assertEq(bytes(uri).length, 0);
    }

    function test_getClaim_returnsEmptyForUnregisteredAttestation() public view {
        // Claim ID exists but no attestation registered
        bytes32 claimId = keccak256(abi.encode(kycProviderAddr, TOPIC_KYC));

        (uint256 topic, uint256 scheme, address issuer,,,) = wrapper.getClaim(claimId);

        assertEq(topic, 0);
        assertEq(scheme, 0);
        assertEq(issuer, address(0));
    }

    // ============ getClaimIdsByTopic Tests ============

    function test_getClaimIdsByTopic_returnsValidClaimIds() public {
        // Create and register attestation
        bytes32 uid = kycProvider.attestInvestorEligibility(schemaKYC, identityAddress, identityAddress, 1, 0, 840, 0);
        verifier.registerAttestation(identityAddress, TOPIC_KYC, uid);

        bytes32[] memory claimIds = wrapper.getClaimIdsByTopic(TOPIC_KYC);

        assertEq(claimIds.length, 1);
        assertEq(claimIds[0], keccak256(abi.encode(kycProviderAddr, TOPIC_KYC)));
    }

    function test_getClaimIdsByTopic_returnsEmptyForNoAttestations() public view {
        bytes32[] memory claimIds = wrapper.getClaimIdsByTopic(TOPIC_KYC);
        assertEq(claimIds.length, 0);
    }

    function test_getClaimIdsByTopic_returnsMultipleClaimIds() public {
        // Add second attester
        MockAttester kycProvider2 = new MockAttester(address(eas), "Better KYC");
        address kycProvider2Addr = address(kycProvider2);

        uint256[] memory topics = new uint256[](1);
        topics[0] = TOPIC_KYC;
        adapter.addTrustedAttester(kycProvider2Addr, topics);

        // Create attestations from both providers
        bytes32 uid1 = kycProvider.attestInvestorEligibility(schemaKYC, identityAddress, identityAddress, 1, 0, 840, 0);
        bytes32 uid2 = kycProvider2.attestInvestorEligibility(schemaKYC, identityAddress, identityAddress, 1, 0, 826, 0);

        verifier.registerAttestation(identityAddress, TOPIC_KYC, uid1);
        verifier.registerAttestation(identityAddress, TOPIC_KYC, uid2);

        bytes32[] memory claimIds = wrapper.getClaimIdsByTopic(TOPIC_KYC);

        assertEq(claimIds.length, 2);
    }

    // ============ isClaimValid Tests ============

    function test_isClaimValid_returnsTrueForValidAttestation() public {
        bytes32 uid = kycProvider.attestInvestorEligibility(schemaKYC, identityAddress, identityAddress, 1, 0, 840, 0);
        verifier.registerAttestation(identityAddress, TOPIC_KYC, uid);

        bool isValid = wrapper.isClaimValid(IIdentity(address(wrapper)), TOPIC_KYC, "", "");

        assertTrue(isValid);
    }

    function test_isClaimValid_returnsFalseForNoAttestation() public view {
        bool isValid = wrapper.isClaimValid(IIdentity(address(wrapper)), TOPIC_KYC, "", "");

        assertFalse(isValid);
    }

    function test_isClaimValid_returnsFalseForRevokedAttestation() public {
        bytes32 uid = kycProvider.attestInvestorEligibility(schemaKYC, identityAddress, identityAddress, 1, 0, 840, 0);
        verifier.registerAttestation(identityAddress, TOPIC_KYC, uid);

        // Revoke the attestation
        eas.forceRevoke(uid);

        bool isValid = wrapper.isClaimValid(IIdentity(address(wrapper)), TOPIC_KYC, "", "");

        assertFalse(isValid);
    }

    function test_isClaimValid_returnsFalseForExpiredAttestation() public {
        // Create attestation with expiration
        bytes memory data = abi.encode(identityAddress, uint8(1), uint8(0), uint16(840), uint64(0));

        AttestationRequest memory request = AttestationRequest({
            schema: schemaKYC,
            data: AttestationRequestData({
                recipient: identityAddress,
                expirationTime: uint64(block.timestamp + 1), // Expires very soon
                revocable: true,
                refUID: bytes32(0),
                data: data,
                value: 0
            })
        });

        vm.prank(kycProviderAddr);
        bytes32 uid = eas.attest(request);

        verifier.registerAttestation(identityAddress, TOPIC_KYC, uid);

        // Fast forward past expiration
        vm.warp(block.timestamp + 2);

        bool isValid = wrapper.isClaimValid(IIdentity(address(wrapper)), TOPIC_KYC, "", "");

        assertFalse(isValid);
    }

    // ============ ERC-735 Mutation Function Tests ============

    function test_addClaim_reverts() public {
        vm.expectRevert("Use EAS to create attestations");
        wrapper.addClaim(TOPIC_KYC, 1, kycProviderAddr, "", "", "");
    }

    function test_removeClaim_reverts() public {
        vm.expectRevert("Use EAS to revoke attestations");
        wrapper.removeClaim(bytes32(uint256(1)));
    }

    // ============ ERC-734 Key Function Tests ============

    function test_getKey_returnsManagementKeyForIdentity() public view {
        bytes32 keyHash = keccak256(abi.encode(identityAddress));

        (uint256[] memory purposes, uint256 keyType, bytes32 key) = wrapper.getKey(keyHash);

        assertEq(purposes.length, 1);
        assertEq(purposes[0], 1); // MANAGEMENT
        assertEq(keyType, 1);
        assertEq(key, keyHash);
    }

    function test_getKey_returnsEmptyForUnknownKey() public view {
        bytes32 unknownKey = bytes32(uint256(999));

        (uint256[] memory purposes, uint256 keyType, bytes32 key) = wrapper.getKey(unknownKey);

        assertEq(purposes.length, 0);
        assertEq(keyType, 0);
        assertEq(key, bytes32(0));
    }

    function test_keyHasPurpose_returnsTrueForManagement() public view {
        bytes32 keyHash = keccak256(abi.encode(identityAddress));

        assertTrue(wrapper.keyHasPurpose(keyHash, 1));
    }

    function test_keyHasPurpose_returnsFalseForOtherPurposes() public view {
        bytes32 keyHash = keccak256(abi.encode(identityAddress));

        assertFalse(wrapper.keyHasPurpose(keyHash, 2)); // ACTION
        assertFalse(wrapper.keyHasPurpose(keyHash, 3)); // CLAIM
    }

    function test_getKeysByPurpose_returnsKeyForManagement() public view {
        bytes32[] memory keys = wrapper.getKeysByPurpose(1);

        assertEq(keys.length, 1);
        assertEq(keys[0], keccak256(abi.encode(identityAddress)));
    }

    function test_getKeysByPurpose_returnsEmptyForOtherPurposes() public view {
        bytes32[] memory keys = wrapper.getKeysByPurpose(2);
        assertEq(keys.length, 0);
    }

    // ============ ERC-734 Mutation Function Tests ============

    function test_addKey_reverts() public {
        vm.expectRevert("Key management not supported");
        wrapper.addKey(bytes32(uint256(1)), 1, 1);
    }

    function test_removeKey_reverts() public {
        vm.expectRevert("Key management not supported");
        wrapper.removeKey(bytes32(uint256(1)), 1);
    }

    function test_approve_reverts() public {
        vm.expectRevert("Execution not supported");
        wrapper.approve(1, true);
    }

    function test_execute_reverts() public {
        vm.expectRevert("Execution not supported");
        wrapper.execute(address(0), 0, "");
    }
}
