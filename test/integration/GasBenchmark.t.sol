// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {EASClaimVerifier} from "../../contracts/EASClaimVerifier.sol";
import {EASTrustedIssuersAdapter} from "../../contracts/EASTrustedIssuersAdapter.sol";
import {EASIdentityProxy} from "../../contracts/EASIdentityProxy.sol";
import {MockEAS} from "../../contracts/mocks/MockEAS.sol";
import {MockClaimTopicsRegistry} from "../../contracts/mocks/MockClaimTopicsRegistry.sol";
import {MockAttester} from "../../contracts/mocks/MockAttester.sol";
import {RevocationRequest, RevocationRequestData} from "@eas/IEAS.sol";

/**
 * @title GasBenchmarkTest
 * @notice Gas benchmarking tests for EAS bridge operations
 * @dev Measures and records gas costs for:
 * - isVerified() via EAS path (1, 3, 5 required topics)
 * - Creating an EAS attestation (investor onboarding cost)
 * - Revoking an EAS attestation
 * - Registering a wallet in EASIdentityProxy
 * - Adding a trusted attester
 */
contract GasBenchmarkTest is Test {
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
    address public investor;

    // ============ Constants ============
    uint256 public constant TOPIC_1 = 1;
    uint256 public constant TOPIC_2 = 2;
    uint256 public constant TOPIC_3 = 3;
    uint256 public constant TOPIC_4 = 4;
    uint256 public constant TOPIC_5 = 5;

    bytes32 public constant SCHEMA_1 = keccak256("SCHEMA_1");
    bytes32 public constant SCHEMA_2 = keccak256("SCHEMA_2");
    bytes32 public constant SCHEMA_3 = keccak256("SCHEMA_3");
    bytes32 public constant SCHEMA_4 = keccak256("SCHEMA_4");
    bytes32 public constant SCHEMA_5 = keccak256("SCHEMA_5");

    function setUp() public {
        tokenIssuer = makeAddr("tokenIssuer");
        investor = makeAddr("investor");

        mockEAS = new MockEAS();
        claimTopicsRegistry = new MockClaimTopicsRegistry();
        kycProvider = new MockAttester(address(mockEAS), "KYC Provider");
        kycProviderAddr = address(kycProvider);

        vm.startPrank(tokenIssuer);

        trustedIssuers = new EASTrustedIssuersAdapter(tokenIssuer);
        identityProxy = new EASIdentityProxy(tokenIssuer);
        verifier = new EASClaimVerifier(tokenIssuer);

        verifier.setEASAddress(address(mockEAS));
        verifier.setTrustedIssuersAdapter(address(trustedIssuers));
        verifier.setIdentityProxy(address(identityProxy));
        verifier.setClaimTopicsRegistry(address(claimTopicsRegistry));

        // Map all topics to schemas
        verifier.setTopicSchemaMapping(TOPIC_1, SCHEMA_1);
        verifier.setTopicSchemaMapping(TOPIC_2, SCHEMA_2);
        verifier.setTopicSchemaMapping(TOPIC_3, SCHEMA_3);
        verifier.setTopicSchemaMapping(TOPIC_4, SCHEMA_4);
        verifier.setTopicSchemaMapping(TOPIC_5, SCHEMA_5);

        // Add attester for all topics
        uint256[] memory topics = new uint256[](5);
        topics[0] = TOPIC_1;
        topics[1] = TOPIC_2;
        topics[2] = TOPIC_3;
        topics[3] = TOPIC_4;
        topics[4] = TOPIC_5;
        trustedIssuers.addTrustedAttester(kycProviderAddr, topics);

        vm.stopPrank();
    }

    // ============ isVerified Gas Benchmarks ============

    /**
     * @notice Benchmark: isVerified with 1 required topic
     */
    function test_gas_isVerified_1Topic() public {
        // Setup: 1 topic required
        claimTopicsRegistry.addClaimTopic(TOPIC_1);

        // Create and register attestation
        bytes32 uid = kycProvider.attestInvestorEligibility(
            SCHEMA_1, investor, investor, 1, 0, 840, 0
        );
        verifier.registerAttestation(investor, TOPIC_1, uid);

        // Measure gas
        uint256 gasBefore = gasleft();
        bool result = verifier.isVerified(investor);
        uint256 gasUsed = gasBefore - gasleft();

        assertTrue(result);
        console.log("isVerified (1 topic):", gasUsed);
    }

    /**
     * @notice Benchmark: isVerified with 3 required topics
     */
    function test_gas_isVerified_3Topics() public {
        // Setup: 3 topics required
        claimTopicsRegistry.addClaimTopic(TOPIC_1);
        claimTopicsRegistry.addClaimTopic(TOPIC_2);
        claimTopicsRegistry.addClaimTopic(TOPIC_3);

        // Create and register attestations
        bytes32 uid1 = kycProvider.attestInvestorEligibility(
            SCHEMA_1, investor, investor, 1, 0, 840, 0
        );
        bytes32 uid2 = kycProvider.attestInvestorEligibility(
            SCHEMA_2, investor, investor, 1, 0, 840, 0
        );
        bytes32 uid3 = kycProvider.attestInvestorEligibility(
            SCHEMA_3, investor, investor, 1, 0, 840, 0
        );

        verifier.registerAttestation(investor, TOPIC_1, uid1);
        verifier.registerAttestation(investor, TOPIC_2, uid2);
        verifier.registerAttestation(investor, TOPIC_3, uid3);

        // Measure gas
        uint256 gasBefore = gasleft();
        bool result = verifier.isVerified(investor);
        uint256 gasUsed = gasBefore - gasleft();

        assertTrue(result);
        console.log("isVerified (3 topics):", gasUsed);
    }

    /**
     * @notice Benchmark: isVerified with 5 required topics
     */
    function test_gas_isVerified_5Topics() public {
        // Setup: 5 topics required
        claimTopicsRegistry.addClaimTopic(TOPIC_1);
        claimTopicsRegistry.addClaimTopic(TOPIC_2);
        claimTopicsRegistry.addClaimTopic(TOPIC_3);
        claimTopicsRegistry.addClaimTopic(TOPIC_4);
        claimTopicsRegistry.addClaimTopic(TOPIC_5);

        // Create and register attestations
        bytes32 uid1 = kycProvider.attestInvestorEligibility(
            SCHEMA_1, investor, investor, 1, 0, 840, 0
        );
        bytes32 uid2 = kycProvider.attestInvestorEligibility(
            SCHEMA_2, investor, investor, 1, 0, 840, 0
        );
        bytes32 uid3 = kycProvider.attestInvestorEligibility(
            SCHEMA_3, investor, investor, 1, 0, 840, 0
        );
        bytes32 uid4 = kycProvider.attestInvestorEligibility(
            SCHEMA_4, investor, investor, 1, 0, 840, 0
        );
        bytes32 uid5 = kycProvider.attestInvestorEligibility(
            SCHEMA_5, investor, investor, 1, 0, 840, 0
        );

        verifier.registerAttestation(investor, TOPIC_1, uid1);
        verifier.registerAttestation(investor, TOPIC_2, uid2);
        verifier.registerAttestation(investor, TOPIC_3, uid3);
        verifier.registerAttestation(investor, TOPIC_4, uid4);
        verifier.registerAttestation(investor, TOPIC_5, uid5);

        // Measure gas
        uint256 gasBefore = gasleft();
        bool result = verifier.isVerified(investor);
        uint256 gasUsed = gasBefore - gasleft();

        assertTrue(result);
        console.log("isVerified (5 topics):", gasUsed);
    }

    // ============ Attestation Creation Gas Benchmark ============

    /**
     * @notice Benchmark: Creating an EAS attestation (investor onboarding)
     */
    function test_gas_createAttestation() public {
        uint256 gasBefore = gasleft();
        bytes32 uid = kycProvider.attestInvestorEligibility(
            SCHEMA_1, investor, investor, 1, 2, 840, uint64(block.timestamp + 365 days)
        );
        uint256 gasUsed = gasBefore - gasleft();

        assertTrue(uid != bytes32(0));
        console.log("Create attestation:", gasUsed);
    }

    // ============ Attestation Registration Gas Benchmark ============

    /**
     * @notice Benchmark: Registering an attestation in verifier
     */
    function test_gas_registerAttestation() public {
        claimTopicsRegistry.addClaimTopic(TOPIC_1);

        bytes32 uid = kycProvider.attestInvestorEligibility(
            SCHEMA_1, investor, investor, 1, 0, 840, 0
        );

        uint256 gasBefore = gasleft();
        verifier.registerAttestation(investor, TOPIC_1, uid);
        uint256 gasUsed = gasBefore - gasleft();

        console.log("Register attestation:", gasUsed);
    }

    // ============ Revocation Gas Benchmark ============

    /**
     * @notice Benchmark: Revoking an EAS attestation
     */
    function test_gas_revokeAttestation() public {
        bytes32 uid = kycProvider.attestInvestorEligibility(
            SCHEMA_1, investor, investor, 1, 0, 840, 0
        );

        uint256 gasBefore = gasleft();
        vm.prank(kycProviderAddr);
        mockEAS.revoke(
            RevocationRequest({
                schema: SCHEMA_1,
                data: RevocationRequestData({uid: uid, value: 0})
            })
        );
        uint256 gasUsed = gasBefore - gasleft();

        console.log("Revoke attestation:", gasUsed);
    }

    // ============ Wallet Registration Gas Benchmark ============

    /**
     * @notice Benchmark: Registering a wallet in EASIdentityProxy
     */
    function test_gas_registerWallet() public {
        address wallet = makeAddr("wallet");
        address identity = makeAddr("identity");

        vm.prank(tokenIssuer);
        uint256 gasBefore = gasleft();
        identityProxy.registerWallet(wallet, identity);
        uint256 gasUsed = gasBefore - gasleft();

        console.log("Register wallet:", gasUsed);
    }

    /**
     * @notice Benchmark: Batch registering wallets
     */
    function test_gas_batchRegisterWallets() public {
        address identity = makeAddr("identity");
        address[] memory wallets = new address[](5);
        for (uint256 i = 0; i < 5; i++) {
            wallets[i] = makeAddr(string(abi.encodePacked("batchWallet", i)));
        }

        vm.prank(tokenIssuer);
        uint256 gasBefore = gasleft();
        identityProxy.batchRegisterWallets(wallets, identity);
        uint256 gasUsed = gasBefore - gasleft();

        console.log("Batch register 5 wallets:", gasUsed);
    }

    // ============ Trusted Attester Management Gas Benchmarks ============

    /**
     * @notice Benchmark: Adding a trusted attester
     */
    function test_gas_addTrustedAttester() public {
        address newAttester = makeAddr("newAttester");
        uint256[] memory topics = new uint256[](3);
        topics[0] = TOPIC_1;
        topics[1] = TOPIC_2;
        topics[2] = TOPIC_3;

        vm.prank(tokenIssuer);
        uint256 gasBefore = gasleft();
        trustedIssuers.addTrustedAttester(newAttester, topics);
        uint256 gasUsed = gasBefore - gasleft();

        console.log("Add trusted attester (3 topics):", gasUsed);
    }

    /**
     * @notice Benchmark: Removing a trusted attester
     */
    function test_gas_removeTrustedAttester() public {
        vm.prank(tokenIssuer);
        uint256 gasBefore = gasleft();
        trustedIssuers.removeTrustedAttester(kycProviderAddr);
        uint256 gasUsed = gasBefore - gasleft();

        console.log("Remove trusted attester:", gasUsed);
    }

    /**
     * @notice Benchmark: Updating attester topics
     */
    function test_gas_updateAttesterTopics() public {
        uint256[] memory newTopics = new uint256[](2);
        newTopics[0] = TOPIC_1;
        newTopics[1] = TOPIC_3;

        vm.prank(tokenIssuer);
        uint256 gasBefore = gasleft();
        trustedIssuers.updateAttesterTopics(kycProviderAddr, newTopics);
        uint256 gasUsed = gasBefore - gasleft();

        console.log("Update attester topics:", gasUsed);
    }

    // ============ Identity Resolution Gas Benchmark ============

    /**
     * @notice Benchmark: Resolving identity (no mapping - returns wallet)
     */
    function test_gas_getIdentity_noMapping() public view {
        address wallet = address(0xDEADBEEF);

        uint256 gasBefore = gasleft();
        address identity = identityProxy.getIdentity(wallet);
        uint256 gasUsed = gasBefore - gasleft();

        assertEq(identity, wallet);
        console.log("getIdentity (no mapping):", gasUsed);
    }

    /**
     * @notice Benchmark: Resolving identity (with mapping)
     */
    function test_gas_getIdentity_withMapping() public {
        address wallet = makeAddr("mappedWallet");
        address identity = makeAddr("identity");

        vm.prank(tokenIssuer);
        identityProxy.registerWallet(wallet, identity);

        uint256 gasBefore = gasleft();
        address resolved = identityProxy.getIdentity(wallet);
        uint256 gasUsed = gasBefore - gasleft();

        assertEq(resolved, identity);
        console.log("getIdentity (with mapping):", gasUsed);
    }

    // ============ Summary Test ============

    /**
     * @notice Output all gas benchmarks in a summary
     */
    function test_gas_summary() public {
        console.log("=== GAS BENCHMARK SUMMARY ===");
        console.log("");

        // Setup
        claimTopicsRegistry.addClaimTopic(TOPIC_1);

        // isVerified (1 topic)
        bytes32 uid = kycProvider.attestInvestorEligibility(SCHEMA_1, investor, investor, 1, 0, 840, 0);
        verifier.registerAttestation(investor, TOPIC_1, uid);

        uint256 g1 = gasleft();
        verifier.isVerified(investor);
        console.log("isVerified (1 topic):     ", g1 - gasleft());

        // Create attestation
        address investor2 = makeAddr("investor2");
        uint256 g2 = gasleft();
        kycProvider.attestInvestorEligibility(SCHEMA_1, investor2, investor2, 1, 0, 840, 0);
        console.log("Create attestation:       ", g2 - gasleft());

        // Register attestation
        address investor3 = makeAddr("investor3");
        bytes32 uid3 = kycProvider.attestInvestorEligibility(SCHEMA_1, investor3, investor3, 1, 0, 840, 0);
        uint256 g3 = gasleft();
        verifier.registerAttestation(investor3, TOPIC_1, uid3);
        console.log("Register attestation:     ", g3 - gasleft());

        // Register wallet
        address wallet = makeAddr("wallet");
        address identity = makeAddr("identity");
        vm.prank(tokenIssuer);
        uint256 g4 = gasleft();
        identityProxy.registerWallet(wallet, identity);
        console.log("Register wallet:          ", g4 - gasleft());

        // Add trusted attester
        address newAttester = makeAddr("newAttester");
        uint256[] memory topics = new uint256[](1);
        topics[0] = TOPIC_2;
        vm.prank(tokenIssuer);
        uint256 g5 = gasleft();
        trustedIssuers.addTrustedAttester(newAttester, topics);
        console.log("Add trusted attester:     ", g5 - gasleft());

        console.log("");
        console.log("=== END SUMMARY ===");
    }
}
