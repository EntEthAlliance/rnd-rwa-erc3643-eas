// SPDX-License-Identifier: Apache-2.0
// Copyright © 2026 Enterprise Ethereum Alliance Inc.
pragma solidity ^0.8.24;

import {BridgeHarness} from "../helpers/BridgeHarness.sol";
import {IEASClaimVerifier} from "../../contracts/interfaces/IEASClaimVerifier.sol";
import {MockAttester} from "../../contracts/mocks/MockAttester.sol";

/**
 * @title EASClaimVerifierTest
 * @notice Unit tests for the post-refactor verifier.
 */
contract EASClaimVerifierTest is BridgeHarness {
    address internal investor;
    address internal wallet;
    MockAttester internal kyc;

    function setUp() public {
        _setupBridge();
        investor = makeAddr("investor");
        wallet = makeAddr("wallet");
        kyc = _createAttester("KYC", _topicsArray(TOPIC_KYC));
        _bindWallet(wallet, investor);
    }

    function test_setters_require_operator_role() public {
        address outsider = makeAddr("outsider");
        vm.startPrank(outsider);
        vm.expectRevert();
        verifier.setEASAddress(address(eas));
        vm.expectRevert();
        verifier.setTrustedIssuersAdapter(address(adapter));
        vm.expectRevert();
        verifier.setIdentityProxy(address(identityProxy));
        vm.expectRevert();
        verifier.setClaimTopicsRegistry(address(claimTopicsRegistry));
        vm.expectRevert();
        verifier.setTopicSchemaMapping(TOPIC_KYC, keccak256("any"));
        vm.expectRevert();
        verifier.setTopicPolicy(TOPIC_KYC, address(kycPolicy));
        vm.stopPrank();
    }

    function test_setIdentityProxy_zero_reverts() public {
        vm.prank(tokenIssuer);
        vm.expectRevert(IEASClaimVerifier.ZeroAddressNotAllowed.selector);
        verifier.setIdentityProxy(address(0));
    }

    function test_topicPolicy_returns_configured_policy() public view {
        assertEq(verifier.getTopicPolicy(TOPIC_KYC), address(kycPolicy));
        assertEq(verifier.getTopicPolicy(TOPIC_ACCREDITATION), address(accreditationPolicy));
    }

    function test_isVerified_passes_happy_path() public {
        _setRequiredTopics(_topicsArray(TOPIC_KYC));
        EligibilityData memory e = _happyPayload(uint64(block.timestamp + 365 days));
        _attestAndRegister(kyc, investor, _topicsArray(TOPIC_KYC), e);
        assertTrue(verifier.isVerified(wallet));
    }

    function test_isVerified_fails_on_bad_payload() public {
        _setRequiredTopics(_topicsArray(TOPIC_KYC));
        EligibilityData memory e = _happyPayload(uint64(block.timestamp + 365 days));
        e.kycStatus = 0;
        _attestAndRegister(kyc, investor, _topicsArray(TOPIC_KYC), e);
        assertFalse(verifier.isVerified(wallet));
    }

    function test_isVerified_reverts_when_policy_unconfigured() public {
        _setRequiredTopics(_topicsArray(TOPIC_KYC));
        vm.prank(tokenIssuer);
        verifier.setTopicPolicy(TOPIC_KYC, address(0));
        vm.expectRevert(abi.encodeWithSelector(IEASClaimVerifier.PolicyNotConfiguredForTopic.selector, TOPIC_KYC));
        verifier.isVerified(wallet);
    }

    function test_registerAttestation_rejects_self_registration() public {
        EligibilityData memory e = _happyPayload(uint64(block.timestamp + 365 days));
        bytes32 uid = _attestOnly(kyc, investor, e);

        vm.prank(investor);
        vm.expectRevert(bytes("Caller not authorized"));
        verifier.registerAttestation(investor, TOPIC_KYC, uid);
    }

    function test_registerAttestation_allows_attester() public {
        EligibilityData memory e = _happyPayload(uint64(block.timestamp + 365 days));
        bytes32 uid = _attestOnly(kyc, investor, e);

        vm.prank(address(kyc));
        verifier.registerAttestation(investor, TOPIC_KYC, uid);
        assertEq(verifier.getRegisteredAttestation(investor, TOPIC_KYC, address(kyc)), uid);
    }

    function test_registerAttestation_allows_agent() public {
        address agent = makeAddr("agent");
        vm.prank(tokenIssuer);
        identityProxy.addAgent(agent);

        EligibilityData memory e = _happyPayload(uint64(block.timestamp + 365 days));
        bytes32 uid = _attestOnly(kyc, investor, e);

        vm.prank(agent);
        verifier.registerAttestation(investor, TOPIC_KYC, uid);
        assertEq(verifier.getRegisteredAttestation(investor, TOPIC_KYC, address(kyc)), uid);
    }

    function _attestOnly(MockAttester attester, address id, EligibilityData memory e) internal returns (bytes32) {
        return attester.attestInvestorEligibility(
            SCHEMA_INVESTOR_ELIGIBILITY,
            id,
            id,
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
    }
}
