// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BridgeHarness} from "../helpers/BridgeHarness.sol";
import {MockAttester} from "../../contracts/mocks/MockAttester.sol";
import {CountryAllowListPolicy} from "../../contracts/policies/CountryAllowListPolicy.sol";

/**
 * @title ComplianceScenariosTest
 * @notice Regulation-shaped end-to-end scenarios composed from topic policies
 *         (follow-up to #54).
 * @dev Each scenario:
 *        1. Declares the required topics its regulatory regime mandates.
 *        2. Deploys a KYC provider authorized for those topics.
 *        3. Constructs an investor payload that should pass, and a negative
 *           variant that should fail.
 *
 *      The negative case is the interesting one — it demonstrates that audit
 *      fix C-1 (payload-aware verification) is actually active, because each
 *      failure is due to a specific payload field, not just "no attestation".
 */
contract ComplianceScenariosTest is BridgeHarness {
    function setUp() public {
        _setupBridge();
    }

    // ----- Reg D 506(c): accredited-only, US investors -----

    function test_regD506c_accredited_us_investor_passes() public {
        uint256[] memory required = _topicsArray(TOPIC_KYC, TOPIC_ACCREDITATION, TOPIC_COUNTRY);
        _setRequiredTopics(required);

        MockAttester provider = _createAttester("RegDProvider", required);

        address investor = makeAddr("regd-investor");
        address wallet = makeAddr("regd-wallet");
        _bindWallet(wallet, investor);

        EligibilityData memory e = _happyPayload(uint64(block.timestamp + 365 days));
        // e defaults to accreditationType=2 (ACCREDITED), country=840 (US)
        _attestAndRegister(provider, investor, required, e);

        assertTrue(verifier.isVerified(wallet));
    }

    function test_regD506c_rejects_non_accredited() public {
        uint256[] memory required = _topicsArray(TOPIC_KYC, TOPIC_ACCREDITATION);
        _setRequiredTopics(required);

        MockAttester provider = _createAttester("RegDProvider", required);
        address investor = makeAddr("retail");
        address wallet = makeAddr("retailWallet");
        _bindWallet(wallet, investor);

        EligibilityData memory e = _happyPayload(uint64(block.timestamp + 365 days));
        e.accreditationType = 0; // NONE — would be a Reg D violation
        _attestAndRegister(provider, investor, required, e);

        assertFalse(verifier.isVerified(wallet));
    }

    // ----- Reg S: non-US persons only -----

    function test_regS_non_us_passes() public {
        // Reconfigure the country policy to a Reg-S-style *block* of the US.
        vm.startPrank(tokenIssuer);
        // Reset the default allow-list to avoid interference.
        uint16[] memory toRemove = countryPolicy.getSet();
        for (uint256 i = 0; i < toRemove.length; i++) {
            countryPolicy.removeCountry(toRemove[i]);
        }
        countryPolicy.setMode( /*Block*/
            CountryAllowListPolicy.Mode.Block
        );
        countryPolicy.addCountry(840); // Block US
        vm.stopPrank();

        uint256[] memory required = _topicsArray(TOPIC_KYC, TOPIC_COUNTRY);
        _setRequiredTopics(required);

        MockAttester provider = _createAttester("RegSProvider", required);
        address investor = makeAddr("regs-investor");
        address wallet = makeAddr("regs-wallet");
        _bindWallet(wallet, investor);

        EligibilityData memory e = _happyPayload(uint64(block.timestamp + 365 days));
        e.countryCode = 826; // UK — not in the block-list
        _attestAndRegister(provider, investor, required, e);

        assertTrue(verifier.isVerified(wallet));
    }

    function test_regS_rejects_us_investor() public {
        vm.startPrank(tokenIssuer);
        uint16[] memory toRemove = countryPolicy.getSet();
        for (uint256 i = 0; i < toRemove.length; i++) {
            countryPolicy.removeCountry(toRemove[i]);
        }
        countryPolicy.setMode(CountryAllowListPolicy.Mode.Block);
        countryPolicy.addCountry(840);
        vm.stopPrank();

        uint256[] memory required = _topicsArray(TOPIC_KYC, TOPIC_COUNTRY);
        _setRequiredTopics(required);

        MockAttester provider = _createAttester("RegSProvider", required);
        address investor = makeAddr("us-investor");
        address wallet = makeAddr("us-wallet");
        _bindWallet(wallet, investor);

        EligibilityData memory e = _happyPayload(uint64(block.timestamp + 365 days));
        e.countryCode = 840; // US — on the block-list
        _attestAndRegister(provider, investor, required, e);

        assertFalse(verifier.isVerified(wallet));
    }

    // ----- MiFID II professional -----

    function test_mifid_professional_passes() public {
        uint256[] memory required = _topicsArray(TOPIC_KYC, TOPIC_PROFESSIONAL);
        _setRequiredTopics(required);

        MockAttester provider = _createAttester("MiFIDProvider", required);
        address investor = makeAddr("eu-pro");
        address wallet = makeAddr("eu-pro-wallet");
        _bindWallet(wallet, investor);

        EligibilityData memory e = _happyPayload(uint64(block.timestamp + 365 days));
        e.accreditationType = 1; // RETAIL_QUALIFIED (opted-up) — passes professional policy
        _attestAndRegister(provider, investor, required, e);

        assertTrue(verifier.isVerified(wallet));
    }

    function test_mifid_rejects_retail() public {
        uint256[] memory required = _topicsArray(TOPIC_KYC, TOPIC_PROFESSIONAL);
        _setRequiredTopics(required);

        MockAttester provider = _createAttester("MiFIDProvider", required);
        address investor = makeAddr("retail");
        address wallet = makeAddr("retailWallet");
        _bindWallet(wallet, investor);

        EligibilityData memory e = _happyPayload(uint64(block.timestamp + 365 days));
        e.accreditationType = 0; // NONE — fails professional policy
        _attestAndRegister(provider, investor, required, e);

        assertFalse(verifier.isVerified(wallet));
    }

    // ----- OFAC sanctions gate -----

    function test_sanctions_hit_blocks_otherwise_valid_investor() public {
        uint256[] memory required = _topicsArray(TOPIC_KYC, TOPIC_SANCTIONS);
        _setRequiredTopics(required);

        MockAttester provider = _createAttester("Screener", required);
        address investor = makeAddr("hit");
        address wallet = makeAddr("hitWallet");
        _bindWallet(wallet, investor);

        EligibilityData memory e = _happyPayload(uint64(block.timestamp + 365 days));
        e.sanctionsStatus = 1; // HIT
        _attestAndRegister(provider, investor, required, e);

        assertFalse(verifier.isVerified(wallet));
    }
}

