// SPDX-License-Identifier: Apache-2.0
// Copyright © 2026 Enterprise Ethereum Alliance Inc.
pragma solidity ^0.8.24;

import {BridgeHarness} from "../helpers/BridgeHarness.sol";
import {MockAttester} from "../../contracts/mocks/MockAttester.sol";

/**
 * @title GasBenchmarkTest
 * @notice Gas benchmarks for the hot path (follow-up to #55).
 * @dev Benchmarks `isVerified` with 1, 3, and 5 required topics (each with its
 *      topic policy active), plus `registerAttestation`, adding a trusted
 *      attester, and the Schema-2 authorization attestation cost.
 *
 *      Numbers surface via emit+console log so they're visible in `forge test -vv`
 *      output and can be snapshotted by `forge snapshot`. They feed
 *      `docs/gas-benchmarks.md` which should be refreshed alongside any changes
 *      to the verifier's hot path.
 *
 *      These are observational "characterisation" tests — they always pass but
 *      their gas readings tell reviewers whether a patch introduced a
 *      regression in the verification path.
 */
contract GasBenchmarkTest is BridgeHarness {
    address internal investor;
    address internal wallet;
    MockAttester internal kyc;

    event GasUsed(string label, uint256 gas);

    function setUp() public {
        _setupBridge();
        investor = makeAddr("investor");
        wallet = makeAddr("wallet");
        _bindWallet(wallet, investor);
    }

    // ----- isVerified ---------------------------------------------------------

    function test_gas_isVerified_1_topic() public {
        kyc = _createAttester("KYC", _topicsArray(TOPIC_KYC));
        _setRequiredTopics(_topicsArray(TOPIC_KYC));
        EligibilityData memory e = _happyPayload(uint64(block.timestamp + 365 days));
        _attestAndRegister(kyc, investor, _topicsArray(TOPIC_KYC), e);

        uint256 g = gasleft();
        bool ok = verifier.isVerified(wallet);
        uint256 used = g - gasleft();
        emit GasUsed("isVerified(1 topic)", used);
        assertTrue(ok);
    }

    function test_gas_isVerified_3_topics() public {
        uint256[] memory topics3 = _topicsArray(TOPIC_KYC, TOPIC_COUNTRY, TOPIC_ACCREDITATION);
        kyc = _createAttester("KYC", topics3);
        _setRequiredTopics(topics3);
        EligibilityData memory e = _happyPayload(uint64(block.timestamp + 365 days));
        _attestAndRegister(kyc, investor, topics3, e);

        uint256 g = gasleft();
        bool ok = verifier.isVerified(wallet);
        uint256 used = g - gasleft();
        emit GasUsed("isVerified(3 topics)", used);
        assertTrue(ok);
    }

    function test_gas_isVerified_5_topics() public {
        uint256[] memory topics5 = new uint256[](5);
        topics5[0] = TOPIC_KYC;
        topics5[1] = TOPIC_AML;
        topics5[2] = TOPIC_COUNTRY;
        topics5[3] = TOPIC_ACCREDITATION;
        topics5[4] = TOPIC_SANCTIONS;
        kyc = _createAttester("KYC", topics5);
        _setRequiredTopics(topics5);
        EligibilityData memory e = _happyPayload(uint64(block.timestamp + 365 days));
        _attestAndRegister(kyc, investor, topics5, e);

        uint256 g = gasleft();
        bool ok = verifier.isVerified(wallet);
        uint256 used = g - gasleft();
        emit GasUsed("isVerified(5 topics)", used);
        assertTrue(ok);
    }

    // ----- Administration ----------------------------------------------------

    function test_gas_addTrustedAttester() public {
        MockAttester newAttester = new MockAttester(address(eas), "New");
        uint256[] memory topics = _topicsArray(TOPIC_KYC);
        bytes32 authUID =
            authorizer.attestIssuerAuthorization(SCHEMA_ISSUER_AUTHORIZATION, address(newAttester), topics, "New");

        vm.startPrank(tokenIssuer);
        uint256 g = gasleft();
        adapter.addTrustedAttester(address(newAttester), topics, authUID);
        uint256 used = g - gasleft();
        vm.stopPrank();

        emit GasUsed("addTrustedAttester", used);
    }

    function test_gas_registerAttestation() public {
        kyc = _createAttester("KYC", _topicsArray(TOPIC_KYC));
        EligibilityData memory e = _happyPayload(uint64(block.timestamp + 365 days));
        bytes32 uid = kyc.attestInvestorEligibility(
            SCHEMA_INVESTOR_ELIGIBILITY,
            investor,
            investor,
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

        vm.startPrank(address(kyc));
        uint256 g = gasleft();
        verifier.registerAttestation(investor, TOPIC_KYC, uid);
        uint256 used = g - gasleft();
        vm.stopPrank();

        emit GasUsed("registerAttestation", used);
    }

    function test_gas_registerWallet() public {
        address freshWallet = makeAddr("fresh");
        address freshIdentity = makeAddr("freshIdentity");

        vm.startPrank(tokenIssuer);
        uint256 g = gasleft();
        identityProxy.registerWallet(freshWallet, freshIdentity);
        uint256 used = g - gasleft();
        vm.stopPrank();

        emit GasUsed("registerWallet", used);
    }
}
