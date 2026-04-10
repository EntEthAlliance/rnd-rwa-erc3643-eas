// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {EASClaimVerifier} from "../../contracts/EASClaimVerifier.sol";
import {EASTrustedIssuersAdapter} from "../../contracts/EASTrustedIssuersAdapter.sol";
import {EASIdentityProxy} from "../../contracts/EASIdentityProxy.sol";
import {MockEAS} from "../../contracts/mocks/MockEAS.sol";
import {MockClaimTopicsRegistry} from "../../contracts/mocks/MockClaimTopicsRegistry.sol";
import {MockAttester} from "../../contracts/mocks/MockAttester.sol";
import {AttestationRequest, AttestationRequestData} from "@eas/IEAS.sol";

/**
 * @title BridgeIntegrationTest
 * @notice Integration tests for the complete EAS-to-ERC-3643 bridge flow
 */
contract BridgeIntegrationTest is Test {
    // Contracts
    EASClaimVerifier public verifier;
    MockEAS public eas;
    EASTrustedIssuersAdapter public adapter;
    EASIdentityProxy public identityProxy;
    MockClaimTopicsRegistry public topicsRegistry;
    MockAttester public kycProvider;

    // Addresses
    address public owner = address(this);
    address public tokenIssuer = address(0x1111111111111111111111111111111111111111);
    address public kycProviderAddr;

    address public investor1 = address(0x2111111111111111111111111111111111111111);
    address public investor2 = address(0x2222222222222222222222222222222222222222);
    address public investor3 = address(0x2333333333333333333333333333333333333333);

    address public wallet1a = address(0x3111111111111111111111111111111111111111);
    address public wallet1b = address(0x3222222222222222222222222222222222222222);

    // Constants
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

        // Set required topics
        topicsRegistry.addClaimTopic(TOPIC_KYC);
    }

    // ============ Full Flow Tests ============

    function test_completeFlow_singleInvestor() public {
        // 1. Investor is not verified initially
        assertFalse(verifier.isVerified(investor1));

        // 2. KYC provider creates attestation
        bytes32 uid = kycProvider.attestInvestorEligibility(
            schemaKYC,
            investor1,
            investor1,
            1, // VERIFIED
            0, // NONE
            840, // US
            0 // No expiration
        );

        // 3. Register attestation
        verifier.registerAttestation(investor1, TOPIC_KYC, uid);

        // 4. Investor is now verified
        assertTrue(verifier.isVerified(investor1));
    }

    function test_completeFlow_multiWallet() public {
        // 1. Register wallets under one identity
        identityProxy.registerWallet(wallet1a, investor1);
        identityProxy.registerWallet(wallet1b, investor1);

        // 2. Create attestation for identity
        bytes32 uid = kycProvider.attestInvestorEligibility(
            schemaKYC,
            investor1, // recipient is identity
            investor1,
            1, // VERIFIED
            0,
            840,
            0
        );

        // 3. Register attestation
        verifier.registerAttestation(investor1, TOPIC_KYC, uid);

        // 4. Both wallets are verified
        assertTrue(verifier.isVerified(wallet1a));
        assertTrue(verifier.isVerified(wallet1b));

        // 5. Identity itself is also verified
        assertTrue(verifier.isVerified(investor1));
    }

    function test_completeFlow_revocation() public {
        // 1. Create and register attestation
        bytes memory data = abi.encode(investor1, uint8(1), uint8(0), uint16(840), uint64(0));

        AttestationRequest memory request = AttestationRequest({
            schema: schemaKYC,
            data: AttestationRequestData({
                recipient: investor1, expirationTime: 0, revocable: true, refUID: bytes32(0), data: data, value: 0
            })
        });

        vm.prank(kycProviderAddr);
        bytes32 uid = eas.attest(request);

        verifier.registerAttestation(investor1, TOPIC_KYC, uid);
        assertTrue(verifier.isVerified(investor1));

        // 2. Revoke attestation
        vm.prank(kycProviderAddr);
        eas.revoke(RevocationRequest({schema: schemaKYC, data: RevocationRequestData({uid: uid, value: 0})}));

        // 3. Investor is no longer verified
        assertFalse(verifier.isVerified(investor1));
    }

    function test_completeFlow_expiration() public {
        // 1. Create attestation with short expiration
        uint64 expirationTime = uint64(block.timestamp + 1 hours);

        bytes memory data = abi.encode(investor1, uint8(1), uint8(0), uint16(840), expirationTime);

        AttestationRequest memory request = AttestationRequest({
            schema: schemaKYC,
            data: AttestationRequestData({
                recipient: investor1,
                expirationTime: 0, // No EAS-level expiration
                revocable: true,
                refUID: bytes32(0),
                data: data,
                value: 0
            })
        });

        vm.prank(kycProviderAddr);
        bytes32 uid = eas.attest(request);

        verifier.registerAttestation(investor1, TOPIC_KYC, uid);

        // 2. Initially verified
        assertTrue(verifier.isVerified(investor1));

        // 3. After expiration
        vm.warp(block.timestamp + 2 hours);
        assertFalse(verifier.isVerified(investor1));
    }

    function test_completeFlow_multipleAttesters() public {
        // Add second KYC provider
        MockAttester kycProvider2 = new MockAttester(address(eas), "Better KYC");
        address kycProvider2Addr = address(kycProvider2);

        uint256[] memory topics = new uint256[](1);
        topics[0] = TOPIC_KYC;
        adapter.addTrustedAttester(kycProvider2Addr, topics);

        // Investor1 uses provider1
        bytes32 uid1 = kycProvider.attestInvestorEligibility(schemaKYC, investor1, investor1, 1, 0, 840, 0);
        verifier.registerAttestation(investor1, TOPIC_KYC, uid1);

        // Investor2 uses provider2
        bytes32 uid2 = kycProvider2.attestInvestorEligibility(
            schemaKYC,
            investor2,
            investor2,
            1,
            0,
            826,
            0 // UK
        );
        verifier.registerAttestation(investor2, TOPIC_KYC, uid2);

        // Both are verified
        assertTrue(verifier.isVerified(investor1));
        assertTrue(verifier.isVerified(investor2));

        // Remove provider1
        adapter.removeTrustedAttester(kycProviderAddr);

        // Investor1 no longer verified (their attester was removed)
        assertFalse(verifier.isVerified(investor1));

        // Investor2 still verified
        assertTrue(verifier.isVerified(investor2));
    }

    function test_completeFlow_changeTopicRequirements() public {
        // Initially only KYC required
        bytes32 uid1 = kycProvider.attestInvestorEligibility(schemaKYC, investor1, investor1, 1, 0, 840, 0);
        verifier.registerAttestation(investor1, TOPIC_KYC, uid1);

        assertTrue(verifier.isVerified(investor1));

        // Add accreditation requirement
        topicsRegistry.addClaimTopic(TOPIC_ACCREDITATION);

        bytes32 schemaAccred = keccak256("Accreditation");
        verifier.setTopicSchemaMapping(TOPIC_ACCREDITATION, schemaAccred);

        // Investor no longer verified (missing accreditation)
        assertFalse(verifier.isVerified(investor1));
    }

    function test_completeFlow_batchWalletRegistration() public {
        // Register multiple wallets at once
        address[] memory wallets = new address[](3);
        wallets[0] = wallet1a;
        wallets[1] = wallet1b;
        wallets[2] = address(0x01C1);

        identityProxy.batchRegisterWallets(wallets, investor1);

        // Create attestation for identity
        bytes32 uid = kycProvider.attestInvestorEligibility(schemaKYC, investor1, investor1, 1, 0, 840, 0);
        verifier.registerAttestation(investor1, TOPIC_KYC, uid);

        // All wallets verified
        assertTrue(verifier.isVerified(wallets[0]));
        assertTrue(verifier.isVerified(wallets[1]));
        assertTrue(verifier.isVerified(wallets[2]));
    }

    function test_completeFlow_walletRemoval() public {
        // Setup multi-wallet
        identityProxy.registerWallet(wallet1a, investor1);
        identityProxy.registerWallet(wallet1b, investor1);

        bytes32 uid = kycProvider.attestInvestorEligibility(schemaKYC, investor1, investor1, 1, 0, 840, 0);
        verifier.registerAttestation(investor1, TOPIC_KYC, uid);

        assertTrue(verifier.isVerified(wallet1a));
        assertTrue(verifier.isVerified(wallet1b));

        // Remove wallet1a
        identityProxy.removeWallet(wallet1a);

        // wallet1a now uses itself as identity (no attestation)
        assertFalse(verifier.isVerified(wallet1a));

        // wallet1b still verified
        assertTrue(verifier.isVerified(wallet1b));
    }
}

// Import structs for revocation
import {RevocationRequest, RevocationRequestData} from "@eas/IEAS.sol";
