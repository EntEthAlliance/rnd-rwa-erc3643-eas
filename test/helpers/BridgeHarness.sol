// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IEAS} from "@eas/IEAS.sol";

import {EASClaimVerifier} from "../../contracts/EASClaimVerifier.sol";
import {EASTrustedIssuersAdapter} from "../../contracts/EASTrustedIssuersAdapter.sol";
import {EASIdentityProxy} from "../../contracts/EASIdentityProxy.sol";

import {MockEAS} from "../../contracts/mocks/MockEAS.sol";
import {MockAttester} from "../../contracts/mocks/MockAttester.sol";
import {MockClaimTopicsRegistry} from "../../contracts/mocks/MockClaimTopicsRegistry.sol";

import {ITopicPolicy} from "../../contracts/policies/ITopicPolicy.sol";
import {KYCStatusPolicy} from "../../contracts/policies/KYCStatusPolicy.sol";
import {AMLPolicy} from "../../contracts/policies/AMLPolicy.sol";
import {SanctionsPolicy} from "../../contracts/policies/SanctionsPolicy.sol";
import {SourceOfFundsPolicy} from "../../contracts/policies/SourceOfFundsPolicy.sol";
import {ProfessionalInvestorPolicy} from "../../contracts/policies/ProfessionalInvestorPolicy.sol";
import {InstitutionalInvestorPolicy} from "../../contracts/policies/InstitutionalInvestorPolicy.sol";
import {CountryAllowListPolicy} from "../../contracts/policies/CountryAllowListPolicy.sol";
import {AccreditationPolicy} from "../../contracts/policies/AccreditationPolicy.sol";

/**
 * @title BridgeHarness
 * @notice Test-only helper that assembles a fully-configured post-refactor Shibui
 *         bridge stack (verifier + adapter + proxy + mocks + policies) so that
 *         individual test files can stay focused on their assertion surface.
 * @dev Topic constants mirror `docs/research/claim-topic-analysis.md`.
 *
 *      Schema UIDs are chosen freely (keccak-of-string) because MockEAS does not
 *      enforce registration; production deployments wire real EAS-registered UIDs
 *      via the `RegisterSchemas` script.
 */
abstract contract BridgeHarness is Test {
    // ============ Topics (production-use set) ============
    uint256 internal constant TOPIC_KYC = 1;
    uint256 internal constant TOPIC_AML = 2;
    uint256 internal constant TOPIC_COUNTRY = 3;
    uint256 internal constant TOPIC_ACCREDITATION = 7;
    uint256 internal constant TOPIC_PROFESSIONAL = 9;
    uint256 internal constant TOPIC_INSTITUTIONAL = 10;
    uint256 internal constant TOPIC_SANCTIONS = 13;
    uint256 internal constant TOPIC_SOURCE_OF_FUNDS = 14;

    // ============ Core ============
    address internal tokenIssuer;

    EASClaimVerifier internal verifier;
    EASTrustedIssuersAdapter internal adapter;
    EASIdentityProxy internal identityProxy;

    MockEAS internal eas;
    MockClaimTopicsRegistry internal claimTopicsRegistry;

    /// @notice Harness-owned attester used to create Schema-2 (Issuer Authorization)
    ///         attestations. In production, only addresses registered on the
    ///         `TrustedIssuerResolver` can create these; MockEAS is permissive so
    ///         this stand-in is sufficient for unit/integration tests.
    MockAttester internal authorizer;

    // ============ Schemas ============
    bytes32 internal constant SCHEMA_INVESTOR_ELIGIBILITY = keccak256("InvestorEligibility_v2");
    bytes32 internal constant SCHEMA_ISSUER_AUTHORIZATION = keccak256("IssuerAuthorization_v1");

    // ============ Policies ============
    KYCStatusPolicy internal kycPolicy;
    AMLPolicy internal amlPolicy;
    SanctionsPolicy internal sanctionsPolicy;
    SourceOfFundsPolicy internal sofPolicy;
    ProfessionalInvestorPolicy internal professionalPolicy;
    InstitutionalInvestorPolicy internal institutionalPolicy;
    CountryAllowListPolicy internal countryPolicy;
    AccreditationPolicy internal accreditationPolicy;

    // ============ Setup ============

    /**
     * @notice Deploys and wires the full bridge stack. Call from `setUp()`.
     * @dev After this, `tokenIssuer` holds both DEFAULT_ADMIN_ROLE and
     *      OPERATOR_ROLE/AGENT_ROLE on all contracts.
     */
    function _setupBridge() internal {
        tokenIssuer = makeAddr("tokenIssuer");

        // Core
        vm.startPrank(tokenIssuer);
        eas = new MockEAS();
        adapter = new EASTrustedIssuersAdapter(tokenIssuer);
        identityProxy = new EASIdentityProxy(tokenIssuer);
        verifier = new EASClaimVerifier(tokenIssuer);
        claimTopicsRegistry = new MockClaimTopicsRegistry();

        adapter.setEASAddress(address(eas));
        adapter.setIssuerAuthSchemaUID(SCHEMA_ISSUER_AUTHORIZATION);

        // Harness-local authorizer for Schema-2 attestations
        authorizer = new MockAttester(address(eas), "HarnessAuthorizer");

        verifier.setEASAddress(address(eas));
        verifier.setTrustedIssuersAdapter(address(adapter));
        verifier.setIdentityProxy(address(identityProxy));
        verifier.setClaimTopicsRegistry(address(claimTopicsRegistry));

        // Policies
        kycPolicy = new KYCStatusPolicy();
        amlPolicy = new AMLPolicy();
        sanctionsPolicy = new SanctionsPolicy();
        sofPolicy = new SourceOfFundsPolicy();
        professionalPolicy = new ProfessionalInvestorPolicy();
        institutionalPolicy = new InstitutionalInvestorPolicy();

        uint16[] memory allowedCountries = new uint16[](3);
        allowedCountries[0] = 840; // US
        allowedCountries[1] = 826; // UK
        allowedCountries[2] = 276; // DE
        countryPolicy = new CountryAllowListPolicy(tokenIssuer, CountryAllowListPolicy.Mode.Allow, allowedCountries);

        uint8[] memory allowedAccreditations = new uint8[](3);
        allowedAccreditations[0] = 2; // ACCREDITED
        allowedAccreditations[1] = 3; // QUALIFIED_PURCHASER
        allowedAccreditations[2] = 4; // INSTITUTIONAL
        accreditationPolicy = new AccreditationPolicy(tokenIssuer, allowedAccreditations);

        // Topic → schema
        verifier.setTopicSchemaMapping(TOPIC_KYC, SCHEMA_INVESTOR_ELIGIBILITY);
        verifier.setTopicSchemaMapping(TOPIC_AML, SCHEMA_INVESTOR_ELIGIBILITY);
        verifier.setTopicSchemaMapping(TOPIC_COUNTRY, SCHEMA_INVESTOR_ELIGIBILITY);
        verifier.setTopicSchemaMapping(TOPIC_ACCREDITATION, SCHEMA_INVESTOR_ELIGIBILITY);
        verifier.setTopicSchemaMapping(TOPIC_PROFESSIONAL, SCHEMA_INVESTOR_ELIGIBILITY);
        verifier.setTopicSchemaMapping(TOPIC_INSTITUTIONAL, SCHEMA_INVESTOR_ELIGIBILITY);
        verifier.setTopicSchemaMapping(TOPIC_SANCTIONS, SCHEMA_INVESTOR_ELIGIBILITY);
        verifier.setTopicSchemaMapping(TOPIC_SOURCE_OF_FUNDS, SCHEMA_INVESTOR_ELIGIBILITY);

        // Topic → policy
        verifier.setTopicPolicy(TOPIC_KYC, address(kycPolicy));
        verifier.setTopicPolicy(TOPIC_AML, address(amlPolicy));
        verifier.setTopicPolicy(TOPIC_COUNTRY, address(countryPolicy));
        verifier.setTopicPolicy(TOPIC_ACCREDITATION, address(accreditationPolicy));
        verifier.setTopicPolicy(TOPIC_PROFESSIONAL, address(professionalPolicy));
        verifier.setTopicPolicy(TOPIC_INSTITUTIONAL, address(institutionalPolicy));
        verifier.setTopicPolicy(TOPIC_SANCTIONS, address(sanctionsPolicy));
        verifier.setTopicPolicy(TOPIC_SOURCE_OF_FUNDS, address(sofPolicy));

        vm.stopPrank();
    }

    // ============ Attester onboarding ============

    /**
     * @notice Deploys a new MockAttester and registers it as trusted for the
     *         given topics, creating a Schema-2 authorization attestation as
     *         the required `authUID`.
     * @dev The attestation is created by this harness itself (the test contract
     *      becomes the attester of the Schema-2 record). In production, only
     *      authorizer addresses registered on `TrustedIssuerResolver` can do
     *      this — here MockEAS is permissive and the adapter's Schema-2 gate
     *      is the only check. The gate passes because schema UID, recipient,
     *      and topic subset are correct.
     */
    function _createAttester(string memory nameLabel, uint256[] memory topics)
        internal
        returns (MockAttester attester)
    {
        attester = new MockAttester(address(eas), nameLabel);

        bytes32 authUID =
            authorizer.attestIssuerAuthorization(SCHEMA_ISSUER_AUTHORIZATION, address(attester), topics, nameLabel);

        vm.prank(tokenIssuer);
        adapter.addTrustedAttester(address(attester), topics, authUID);
    }

    /**
     * @notice Like `_createAttester` but the caller supplies an attester address
     *         (e.g. an already-deployed MockAttester in a dual-provider test).
     */
    function _trustAttester(address attester, uint256[] memory topics, string memory nameLabel) internal {
        bytes32 authUID =
            authorizer.attestIssuerAuthorization(SCHEMA_ISSUER_AUTHORIZATION, attester, topics, nameLabel);
        vm.prank(tokenIssuer);
        adapter.addTrustedAttester(attester, topics, authUID);
    }

    // ============ Investor setup ============

    struct EligibilityData {
        uint8 kycStatus;
        uint8 amlStatus;
        uint8 sanctionsStatus;
        uint8 sourceOfFundsStatus;
        uint8 accreditationType;
        uint16 countryCode;
        uint64 expirationTimestamp;
        bytes32 evidenceHash;
        uint8 verificationMethod;
    }

    /// @notice Returns a "happy path" payload: verified, clean, US-accredited, 1-year expiry.
    function _happyPayload(uint64 expiry) internal pure returns (EligibilityData memory e) {
        e.kycStatus = 1;
        e.amlStatus = 0;
        e.sanctionsStatus = 0;
        e.sourceOfFundsStatus = 1;
        e.accreditationType = 2;
        e.countryCode = 840;
        e.expirationTimestamp = expiry;
        e.evidenceHash = keccak256("evidence-v1");
        e.verificationMethod = 2; // third-party
    }

    /**
     * @notice Attests an investor-eligibility record and registers it for all
     *         provided topics.
     */
    function _attestAndRegister(MockAttester attester, address identity, uint256[] memory topics, EligibilityData memory e)
        internal
        returns (bytes32 uid)
    {
        uid = attester.attestInvestorEligibility(
            SCHEMA_INVESTOR_ELIGIBILITY,
            identity,
            identity,
            e.kycStatus,
            e.amlStatus,
            e.sanctionsStatus,
            e.sourceOfFundsStatus,
            e.accreditationType,
            e.countryCode,
            e.expirationTimestamp,
            e.evidenceHash,
            e.verificationMethod
        );

        for (uint256 i = 0; i < topics.length; i++) {
            vm.prank(address(attester));
            verifier.registerAttestation(identity, topics[i], uid);
        }
    }

    /**
     * @notice Binds `wallet` to `identity` in the identity proxy (must be called
     *         before `isVerified(wallet)` returns anything meaningful).
     */
    function _bindWallet(address wallet, address identity) internal {
        vm.prank(tokenIssuer);
        identityProxy.registerWallet(wallet, identity);
    }

    // ============ Convenience ============

    function _topicsArray(uint256 a) internal pure returns (uint256[] memory arr) {
        arr = new uint256[](1);
        arr[0] = a;
    }

    function _topicsArray(uint256 a, uint256 b) internal pure returns (uint256[] memory arr) {
        arr = new uint256[](2);
        arr[0] = a;
        arr[1] = b;
    }

    function _topicsArray(uint256 a, uint256 b, uint256 c) internal pure returns (uint256[] memory arr) {
        arr = new uint256[](3);
        arr[0] = a;
        arr[1] = b;
        arr[2] = c;
    }

    function _topicsArray(uint256 a, uint256 b, uint256 c, uint256 d) internal pure returns (uint256[] memory arr) {
        arr = new uint256[](4);
        arr[0] = a;
        arr[1] = b;
        arr[2] = c;
        arr[3] = d;
    }

    function _setRequiredTopics(uint256[] memory topics) internal {
        for (uint256 i = 0; i < topics.length; i++) {
            claimTopicsRegistry.addClaimTopic(topics[i]);
        }
    }
}
