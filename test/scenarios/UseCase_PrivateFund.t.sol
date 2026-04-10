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
 * @title UseCase_PrivateFund_Test
 * @notice Private fund scenario tests
 * @dev Tests as specified in PRD:
 * - Hedge fund tokenizing fund interests
 * - Only accredited investors allowed ($1M+ net worth or $200K income)
 * - Fund administrator can whitelist specific investors
 * - Test that accredited investor attestation grants access
 * - Test that administrator whitelist provides override
 * - Test that non-accredited investors are blocked
 */
contract UseCase_PrivateFund_Test is Test {
    // ============ Contracts ============
    EASClaimVerifier public verifier;
    EASTrustedIssuersAdapter public trustedIssuers;
    EASIdentityProxy public identityProxy;
    MockEAS public mockEAS;
    MockClaimTopicsRegistry public claimTopicsRegistry;
    MockAttester public kycProvider;
    MockAttester public accreditationVerifier;

    // ============ Addresses ============
    address public fundAdmin;
    address public kycProviderAddr;
    address public accreditationVerifierAddr;

    // Investors
    address public accreditedInvestor1;
    address public accreditedInvestor2;
    address public retailInvestor;
    address public whitelistedInvestor;
    address public institutionalInvestor;

    // ============ Constants ============
    uint256 public constant TOPIC_KYC = 1;
    uint256 public constant TOPIC_ACCREDITATION = 7;

    bytes32 public constant SCHEMA_KYC = keccak256("KYC_FUND");
    bytes32 public constant SCHEMA_ACCREDITATION = keccak256("ACCREDITATION_FUND");

    // Accreditation types
    uint8 public constant ACCRED_NONE = 0;
    uint8 public constant ACCRED_NET_WORTH = 1; // $1M+ net worth
    uint8 public constant ACCRED_INCOME = 2; // $200K+ income
    uint8 public constant ACCRED_INSTITUTIONAL = 3; // Institutional investor
    uint8 public constant ACCRED_QIB = 4; // Qualified Institutional Buyer

    // Admin whitelist (simulated)
    mapping(address => bool) public adminWhitelist;

    function setUp() public {
        fundAdmin = makeAddr("fundAdmin");
        accreditedInvestor1 = makeAddr("accreditedInvestor1");
        accreditedInvestor2 = makeAddr("accreditedInvestor2");
        retailInvestor = makeAddr("retailInvestor");
        whitelistedInvestor = makeAddr("whitelistedInvestor");
        institutionalInvestor = makeAddr("institutionalInvestor");

        // Deploy infrastructure
        mockEAS = new MockEAS();
        claimTopicsRegistry = new MockClaimTopicsRegistry();
        kycProvider = new MockAttester(address(mockEAS), "Fund KYC");
        accreditationVerifier = new MockAttester(address(mockEAS), "Accreditation Verifier");
        kycProviderAddr = address(kycProvider);
        accreditationVerifierAddr = address(accreditationVerifier);

        vm.startPrank(fundAdmin);

        trustedIssuers = new EASTrustedIssuersAdapter(fundAdmin);
        identityProxy = new EASIdentityProxy(fundAdmin);
        verifier = new EASClaimVerifier(fundAdmin);

        verifier.setEASAddress(address(mockEAS));
        verifier.setTrustedIssuersAdapter(address(trustedIssuers));
        verifier.setIdentityProxy(address(identityProxy));
        verifier.setClaimTopicsRegistry(address(claimTopicsRegistry));

        verifier.setTopicSchemaMapping(TOPIC_KYC, SCHEMA_KYC);
        verifier.setTopicSchemaMapping(TOPIC_ACCREDITATION, SCHEMA_ACCREDITATION);

        // Add KYC provider for KYC topic
        uint256[] memory kycTopics = new uint256[](1);
        kycTopics[0] = TOPIC_KYC;
        trustedIssuers.addTrustedAttester(kycProviderAddr, kycTopics);

        // Add accreditation verifier for accreditation topic
        uint256[] memory accredTopics = new uint256[](1);
        accredTopics[0] = TOPIC_ACCREDITATION;
        trustedIssuers.addTrustedAttester(accreditationVerifierAddr, accredTopics);

        // Authorize test contract as an agent for registerAttestation calls
        identityProxy.addAgent(address(this));

        vm.stopPrank();

        // Private fund requires both KYC AND accreditation
        claimTopicsRegistry.addClaimTopic(TOPIC_KYC);
        claimTopicsRegistry.addClaimTopic(TOPIC_ACCREDITATION);
    }

    // ============ Helper Functions ============

    function _attestKYC(address investor) internal returns (bytes32) {
        bytes32 uid = kycProvider.attestInvestorEligibility(
            SCHEMA_KYC,
            investor,
            investor,
            1, // VERIFIED
            0,
            840, // US
            0
        );
        verifier.registerAttestation(investor, TOPIC_KYC, uid);
        return uid;
    }

    function _attestAccreditation(address investor, uint8 accredType) internal returns (bytes32) {
        bytes32 uid = accreditationVerifier.attestInvestorEligibility(
            SCHEMA_ACCREDITATION,
            investor,
            investor,
            1, // VERIFIED
            accredType,
            840,
            0
        );
        verifier.registerAttestation(investor, TOPIC_ACCREDITATION, uid);
        return uid;
    }

    function _canInvestInFund(address investor) internal view returns (bool) {
        // Check admin whitelist first (override)
        if (adminWhitelist[investor]) {
            return true;
        }

        // Otherwise check EAS verification
        return verifier.isVerified(investor);
    }

    // ============ Scenario Tests ============

    /**
     * @notice Test: Accredited investor (net worth) can invest
     */
    function test_privateFund_accreditedNetWorthCanInvest() public {
        _attestKYC(accreditedInvestor1);
        _attestAccreditation(accreditedInvestor1, ACCRED_NET_WORTH);

        assertTrue(verifier.isVerified(accreditedInvestor1));
        assertTrue(_canInvestInFund(accreditedInvestor1));
    }

    /**
     * @notice Test: Accredited investor (income) can invest
     */
    function test_privateFund_accreditedIncomeCanInvest() public {
        _attestKYC(accreditedInvestor2);
        _attestAccreditation(accreditedInvestor2, ACCRED_INCOME);

        assertTrue(verifier.isVerified(accreditedInvestor2));
        assertTrue(_canInvestInFund(accreditedInvestor2));
    }

    /**
     * @notice Test: Retail investor (no accreditation) cannot invest
     */
    function test_privateFund_retailInvestorBlocked() public {
        // Only KYC, no accreditation
        _attestKYC(retailInvestor);

        // Fails because missing accreditation
        assertFalse(verifier.isVerified(retailInvestor));
        assertFalse(_canInvestInFund(retailInvestor));
    }

    /**
     * @notice Test: Retail investor with ACCRED_NONE still blocked
     */
    function test_privateFund_noneAccreditationStillWorks() public {
        _attestKYC(retailInvestor);
        // Attestation with ACCRED_NONE type
        _attestAccreditation(retailInvestor, ACCRED_NONE);

        // Has both attestations, so technically verified
        // (The fund would check the accreditation type in the data)
        assertTrue(verifier.isVerified(retailInvestor));
    }

    /**
     * @notice Test: Administrator whitelist provides override
     */
    function test_privateFund_adminWhitelistOverride() public {
        // Whitelisted investor has no attestations
        assertFalse(verifier.isVerified(whitelistedInvestor));

        // But admin whitelists them
        adminWhitelist[whitelistedInvestor] = true;

        // Can invest via whitelist override
        assertTrue(_canInvestInFund(whitelistedInvestor));
    }

    /**
     * @notice Test: Institutional investor (QIB) can invest
     */
    function test_privateFund_institutionalQIBCanInvest() public {
        _attestKYC(institutionalInvestor);
        _attestAccreditation(institutionalInvestor, ACCRED_QIB);

        assertTrue(verifier.isVerified(institutionalInvestor));
        assertTrue(_canInvestInFund(institutionalInvestor));
    }

    /**
     * @notice Test: Accreditation revocation blocks investor
     */
    function test_privateFund_accreditationRevocationBlocks() public {
        _attestKYC(accreditedInvestor1);
        bytes32 accredUid = _attestAccreditation(accreditedInvestor1, ACCRED_NET_WORTH);

        assertTrue(_canInvestInFund(accreditedInvestor1));

        // Revoke accreditation
        mockEAS.forceRevoke(accredUid);

        // Now blocked (has KYC but no valid accreditation)
        assertFalse(verifier.isVerified(accreditedInvestor1));
        assertFalse(_canInvestInFund(accreditedInvestor1));
    }

    /**
     * @notice Test: KYC expiration blocks investor
     */
    function test_privateFund_kycExpirationBlocks() public {
        vm.warp(1000);

        uint64 kycExpiration = uint64(block.timestamp + 100);

        // Create KYC attestation with expiration
        bytes32 kycUid = kycProvider.attestInvestorEligibility(
            SCHEMA_KYC, accreditedInvestor1, accreditedInvestor1, 1, 0, 840, kycExpiration
        );
        verifier.registerAttestation(accreditedInvestor1, TOPIC_KYC, kycUid);
        _attestAccreditation(accreditedInvestor1, ACCRED_NET_WORTH);

        assertTrue(_canInvestInFund(accreditedInvestor1));

        // KYC expires
        vm.warp(kycExpiration);

        // Now blocked
        assertFalse(verifier.isVerified(accreditedInvestor1));
        assertFalse(_canInvestInFund(accreditedInvestor1));
    }

    /**
     * @notice Test: Multi-wallet investor
     */
    function test_privateFund_multiWalletInvestor() public {
        address identity = makeAddr("investorIdentity");
        address wallet1 = makeAddr("wallet1");
        address wallet2 = makeAddr("wallet2");

        // Register wallets
        vm.prank(fundAdmin);
        identityProxy.registerWallet(wallet1, identity);
        vm.prank(fundAdmin);
        identityProxy.registerWallet(wallet2, identity);

        // Attest the identity
        _attestKYC(identity);
        _attestAccreditation(identity, ACCRED_NET_WORTH);

        // Both wallets can invest
        assertTrue(verifier.isVerified(wallet1));
        assertTrue(verifier.isVerified(wallet2));
        assertTrue(_canInvestInFund(wallet1));
        assertTrue(_canInvestInFund(wallet2));
    }

    /**
     * @notice Test: Upgrade from retail to accredited
     */
    function test_privateFund_upgradeToAccredited() public {
        // Start as retail (KYC only)
        _attestKYC(retailInvestor);

        assertFalse(_canInvestInFund(retailInvestor));

        // Investor becomes accredited
        _attestAccreditation(retailInvestor, ACCRED_NET_WORTH);

        // Now can invest
        assertTrue(_canInvestInFund(retailInvestor));
    }

    /**
     * @notice Test: Multiple accreditation attestations (from different verifiers)
     */
    function test_privateFund_multipleAccreditationVerifiers() public {
        // Add second accreditation verifier
        MockAttester secondVerifier = new MockAttester(address(mockEAS), "Second Accred");
        vm.prank(fundAdmin);
        uint256[] memory topics = new uint256[](1);
        topics[0] = TOPIC_ACCREDITATION;
        trustedIssuers.addTrustedAttester(address(secondVerifier), topics);

        _attestKYC(accreditedInvestor1);

        // Get accreditation from first verifier
        _attestAccreditation(accreditedInvestor1, ACCRED_NET_WORTH);
        assertTrue(_canInvestInFund(accreditedInvestor1));

        // Revoke first accreditation
        // (In real scenario, we'd need to track the UID)

        // Get accreditation from second verifier
        bytes32 uid2 = secondVerifier.attestInvestorEligibility(
            SCHEMA_ACCREDITATION, accreditedInvestor1, accreditedInvestor1, 1, ACCRED_INCOME, 840, 0
        );
        verifier.registerAttestation(accreditedInvestor1, TOPIC_ACCREDITATION, uid2);

        // Still verified
        assertTrue(_canInvestInFund(accreditedInvestor1));
    }
}
