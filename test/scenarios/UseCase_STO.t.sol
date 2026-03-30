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
 * @title UseCase_STO_Test
 * @notice Security Token Offering scenario tests
 * @dev Tests as specified in PRD:
 * - Issuer creates token with max 500 holders
 * - KYC provider attests 10 test investors via EAS
 * - Investors are in 3 different countries
 * - Compliance module restricts country distribution
 * - Test that transfers respect both EAS identity verification AND compliance module restrictions
 * - Test that compliance and identity are independently enforced
 */
contract UseCase_STO_Test is Test {
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

    // Investors by country
    address[] public usInvestors;
    address[] public ukInvestors;
    address[] public deInvestors;

    // ============ Constants ============
    uint256 public constant TOPIC_KYC = 1;
    uint256 public constant TOPIC_COUNTRY = 3;

    bytes32 public constant SCHEMA_KYC = keccak256("KYC_STO");
    bytes32 public constant SCHEMA_COUNTRY = keccak256("COUNTRY_STO");

    // Country codes (ISO 3166-1 numeric)
    uint16 public constant COUNTRY_US = 840;
    uint16 public constant COUNTRY_UK = 826;
    uint16 public constant COUNTRY_DE = 276;

    // STO constraints
    uint256 public constant MAX_HOLDERS = 500;
    uint256 public constant MAX_US_INVESTORS = 5;
    uint256 public constant MAX_UK_INVESTORS = 3;
    uint256 public constant MAX_DE_INVESTORS = 2;

    // Tracking
    uint256 public usInvestorCount;
    uint256 public ukInvestorCount;
    uint256 public deInvestorCount;
    uint256 public totalHolders;

    function setUp() public {
        tokenIssuer = makeAddr("stoIssuer");

        // Create investor arrays
        for (uint256 i = 0; i < 5; i++) {
            usInvestors.push(makeAddr(string(abi.encodePacked("usInvestor", i))));
        }
        for (uint256 i = 0; i < 3; i++) {
            ukInvestors.push(makeAddr(string(abi.encodePacked("ukInvestor", i))));
        }
        for (uint256 i = 0; i < 2; i++) {
            deInvestors.push(makeAddr(string(abi.encodePacked("deInvestor", i))));
        }

        // Deploy infrastructure
        mockEAS = new MockEAS();
        claimTopicsRegistry = new MockClaimTopicsRegistry();
        kycProvider = new MockAttester(address(mockEAS), "STO KYC Provider");
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
        verifier.setTopicSchemaMapping(TOPIC_COUNTRY, SCHEMA_COUNTRY);

        uint256[] memory topics = new uint256[](2);
        topics[0] = TOPIC_KYC;
        topics[1] = TOPIC_COUNTRY;
        trustedIssuers.addTrustedAttester(kycProviderAddr, topics);

        vm.stopPrank();

        // Set required topics (KYC only for now)
        claimTopicsRegistry.addClaimTopic(TOPIC_KYC);
    }

    // ============ Helper Functions ============

    function _attestInvestor(address investor, uint16 countryCode) internal returns (bytes32) {
        bytes32 uid = kycProvider.attestInvestorEligibility(
            SCHEMA_KYC,
            investor,
            investor,
            1, // VERIFIED
            0, // NONE
            countryCode,
            0 // No expiration
        );
        verifier.registerAttestation(investor, TOPIC_KYC, uid);
        return uid;
    }

    function _canReceiveTokens(
        address investor,
        uint16 countryCode
    ) internal view returns (bool) {
        // Check 1: EAS identity verification
        if (!verifier.isVerified(investor)) {
            return false;
        }

        // Check 2: Country-based compliance limits (simulated)
        if (countryCode == COUNTRY_US && usInvestorCount >= MAX_US_INVESTORS) {
            return false;
        }
        if (countryCode == COUNTRY_UK && ukInvestorCount >= MAX_UK_INVESTORS) {
            return false;
        }
        if (countryCode == COUNTRY_DE && deInvestorCount >= MAX_DE_INVESTORS) {
            return false;
        }

        // Check 3: Max holders
        if (totalHolders >= MAX_HOLDERS) {
            return false;
        }

        return true;
    }

    function _registerHolder(uint16 countryCode) internal {
        if (countryCode == COUNTRY_US) usInvestorCount++;
        else if (countryCode == COUNTRY_UK) ukInvestorCount++;
        else if (countryCode == COUNTRY_DE) deInvestorCount++;
        totalHolders++;
    }

    // ============ Scenario Tests ============

    /**
     * @notice Test: 10 investors from 3 countries complete KYC
     */
    function test_sto_kycAttestation10Investors() public {
        // Attest all US investors (5)
        for (uint256 i = 0; i < usInvestors.length; i++) {
            _attestInvestor(usInvestors[i], COUNTRY_US);
            assertTrue(verifier.isVerified(usInvestors[i]));
        }

        // Attest all UK investors (3)
        for (uint256 i = 0; i < ukInvestors.length; i++) {
            _attestInvestor(ukInvestors[i], COUNTRY_UK);
            assertTrue(verifier.isVerified(ukInvestors[i]));
        }

        // Attest all DE investors (2)
        for (uint256 i = 0; i < deInvestors.length; i++) {
            _attestInvestor(deInvestors[i], COUNTRY_DE);
            assertTrue(verifier.isVerified(deInvestors[i]));
        }
    }

    /**
     * @notice Test: Country distribution limits are respected
     */
    function test_sto_countryDistributionLimits() public {
        // Attest all investors
        for (uint256 i = 0; i < usInvestors.length; i++) {
            _attestInvestor(usInvestors[i], COUNTRY_US);
        }
        for (uint256 i = 0; i < ukInvestors.length; i++) {
            _attestInvestor(ukInvestors[i], COUNTRY_UK);
        }
        for (uint256 i = 0; i < deInvestors.length; i++) {
            _attestInvestor(deInvestors[i], COUNTRY_DE);
        }

        // Register US investors up to limit
        for (uint256 i = 0; i < MAX_US_INVESTORS; i++) {
            assertTrue(_canReceiveTokens(usInvestors[i], COUNTRY_US));
            _registerHolder(COUNTRY_US);
        }

        // Additional US investor (simulated extra) should fail compliance
        address extraUsInvestor = makeAddr("extraUsInvestor");
        _attestInvestor(extraUsInvestor, COUNTRY_US);

        // Identity is verified but compliance limit exceeded
        assertTrue(verifier.isVerified(extraUsInvestor));
        assertFalse(_canReceiveTokens(extraUsInvestor, COUNTRY_US));
    }

    /**
     * @notice Test: Identity and compliance are independently enforced
     */
    function test_sto_independentEnforcement() public {
        address unverifiedInvestor = makeAddr("unverified");
        address verifiedInvestor = usInvestors[0];

        // Attest one investor
        _attestInvestor(verifiedInvestor, COUNTRY_US);

        // Unverified investor fails on identity (not compliance)
        assertFalse(verifier.isVerified(unverifiedInvestor));
        assertFalse(_canReceiveTokens(unverifiedInvestor, COUNTRY_US));

        // Verified investor passes identity
        assertTrue(verifier.isVerified(verifiedInvestor));
        assertTrue(_canReceiveTokens(verifiedInvestor, COUNTRY_US));

        // Fill up US investor slots
        for (uint256 i = 0; i < MAX_US_INVESTORS; i++) {
            _registerHolder(COUNTRY_US);
        }

        // Verified investor now fails on compliance (not identity)
        address newUsInvestor = makeAddr("newUsInvestor");
        _attestInvestor(newUsInvestor, COUNTRY_US);
        assertTrue(verifier.isVerified(newUsInvestor));
        assertFalse(_canReceiveTokens(newUsInvestor, COUNTRY_US));
    }

    /**
     * @notice Test: Transfer fails when attestation is revoked
     */
    function test_sto_transferFailsOnRevocation() public {
        address investor = usInvestors[0];

        bytes32 uid = _attestInvestor(investor, COUNTRY_US);
        assertTrue(_canReceiveTokens(investor, COUNTRY_US));

        // Revoke attestation
        mockEAS.forceRevoke(uid);

        // Now fails identity check
        assertFalse(verifier.isVerified(investor));
        assertFalse(_canReceiveTokens(investor, COUNTRY_US));
    }

    /**
     * @notice Test: Max holders limit
     */
    function test_sto_maxHoldersLimit() public {
        // For this test, simulate reaching max holders
        totalHolders = MAX_HOLDERS;

        address investor = usInvestors[0];
        _attestInvestor(investor, COUNTRY_US);

        // Identity is verified
        assertTrue(verifier.isVerified(investor));

        // But cannot receive tokens due to max holders
        assertFalse(_canReceiveTokens(investor, COUNTRY_US));
    }

    /**
     * @notice Test: Multi-country STO with proper distribution
     */
    function test_sto_multiCountryDistribution() public {
        // Attest investors from all countries
        for (uint256 i = 0; i < 3; i++) {
            _attestInvestor(usInvestors[i], COUNTRY_US);
            _registerHolder(COUNTRY_US);
        }
        for (uint256 i = 0; i < 2; i++) {
            _attestInvestor(ukInvestors[i], COUNTRY_UK);
            _registerHolder(COUNTRY_UK);
        }
        _attestInvestor(deInvestors[0], COUNTRY_DE);
        _registerHolder(COUNTRY_DE);

        // Check total holders
        assertEq(totalHolders, 6);
        assertEq(usInvestorCount, 3);
        assertEq(ukInvestorCount, 2);
        assertEq(deInvestorCount, 1);

        // More US investors can still join (limit is 5) - attest them first
        _attestInvestor(usInvestors[3], COUNTRY_US);
        assertTrue(_canReceiveTokens(usInvestors[3], COUNTRY_US));

        // More UK investors can still join (limit is 3) - attest them first
        _attestInvestor(ukInvestors[2], COUNTRY_UK);
        assertTrue(_canReceiveTokens(ukInvestors[2], COUNTRY_UK));

        // More DE investors can still join (limit is 2) - attest them first
        _attestInvestor(deInvestors[1], COUNTRY_DE);
        assertTrue(_canReceiveTokens(deInvestors[1], COUNTRY_DE));
    }
}
