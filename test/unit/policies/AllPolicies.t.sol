// SPDX-License-Identifier: Apache-2.0
// Copyright © 2026 Enterprise Ethereum Alliance Inc.
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Attestation} from "@eas/Common.sol";

import {KYCStatusPolicy} from "../../../contracts/policies/KYCStatusPolicy.sol";
import {AMLPolicy} from "../../../contracts/policies/AMLPolicy.sol";
import {SanctionsPolicy} from "../../../contracts/policies/SanctionsPolicy.sol";
import {SourceOfFundsPolicy} from "../../../contracts/policies/SourceOfFundsPolicy.sol";
import {ProfessionalInvestorPolicy} from "../../../contracts/policies/ProfessionalInvestorPolicy.sol";
import {InstitutionalInvestorPolicy} from "../../../contracts/policies/InstitutionalInvestorPolicy.sol";
import {CountryAllowListPolicy} from "../../../contracts/policies/CountryAllowListPolicy.sol";
import {AccreditationPolicy} from "../../../contracts/policies/AccreditationPolicy.sol";

/**
 * @title AllPoliciesTest
 * @notice Unit tests for the 8 Shibui topic policies.
 * @dev Tests each policy against the Investor Eligibility payload:
 *        address identity, uint8 kycStatus, uint8 amlStatus, uint8 sanctionsStatus,
 *        uint8 sourceOfFundsStatus, uint8 accreditationType, uint16 countryCode,
 *        uint64 expirationTimestamp, bytes32 evidenceHash, uint8 verificationMethod
 */
contract AllPoliciesTest is Test {
    address private constant INVESTOR = address(0x1111);
    address private constant OWNER = address(0x9999);

    function _payload(
        uint8 kycStatus,
        uint8 amlStatus,
        uint8 sanctionsStatus,
        uint8 sourceOfFundsStatus,
        uint8 accreditationType,
        uint16 countryCode,
        uint64 expirationTimestamp
    ) internal pure returns (bytes memory) {
        return abi.encode(
            INVESTOR,
            kycStatus,
            amlStatus,
            sanctionsStatus,
            sourceOfFundsStatus,
            accreditationType,
            countryCode,
            expirationTimestamp,
            bytes32(uint256(0xEEE)),
            uint8(1)
        );
    }

    function _att(bytes memory data) internal view returns (Attestation memory a) {
        a.uid = bytes32(uint256(0xABCD));
        a.schema = bytes32(uint256(0x5CE4));
        a.time = uint64(block.timestamp);
        a.expirationTime = 0;
        a.revocationTime = 0;
        a.refUID = bytes32(0);
        a.recipient = INVESTOR;
        a.attester = address(0x2222);
        a.revocable = true;
        a.data = data;
    }

    // ============ KYC ============

    function test_kyc_verified_passes() public {
        KYCStatusPolicy p = new KYCStatusPolicy();
        bytes memory d = _payload(1, 0, 0, 1, 2, 840, uint64(block.timestamp + 1 days));
        assertTrue(this.call_validate_kyc(p, d));
    }

    function test_kyc_pending_rejected() public {
        KYCStatusPolicy p = new KYCStatusPolicy();
        bytes memory d = _payload(4, 0, 0, 1, 2, 840, uint64(block.timestamp + 1 days));
        assertFalse(this.call_validate_kyc(p, d));
    }

    function test_kyc_revoked_in_payload_rejected() public {
        KYCStatusPolicy p = new KYCStatusPolicy();
        bytes memory d = _payload(3, 0, 0, 1, 2, 840, uint64(block.timestamp + 1 days));
        assertFalse(this.call_validate_kyc(p, d));
    }

    function test_kyc_data_expired_rejected() public {
        KYCStatusPolicy p = new KYCStatusPolicy();
        vm.warp(100_000);
        bytes memory d = _payload(1, 0, 0, 1, 2, 840, uint64(block.timestamp - 1));
        assertFalse(this.call_validate_kyc(p, d));
    }

    function test_kyc_short_payload_rejected() public {
        KYCStatusPolicy p = new KYCStatusPolicy();
        bytes memory short_ = abi.encode(INVESTOR, uint8(1));
        assertFalse(this.call_validate_kyc(p, short_));
    }

    function call_validate_kyc(KYCStatusPolicy p, bytes calldata data) external view returns (bool) {
        return p.validate(_att(data));
    }

    // ============ AML ============

    function test_aml_clear_passes() public {
        AMLPolicy p = new AMLPolicy();
        bytes memory d = _payload(1, 0, 0, 1, 2, 840, 0);
        assertTrue(this.call_validate_aml(p, d));
    }

    function test_aml_flagged_rejected() public {
        AMLPolicy p = new AMLPolicy();
        bytes memory d = _payload(1, 1, 0, 1, 2, 840, 0);
        assertFalse(this.call_validate_aml(p, d));
    }

    function call_validate_aml(AMLPolicy p, bytes calldata data) external view returns (bool) {
        return p.validate(_att(data));
    }

    // ============ Sanctions ============

    function test_sanctions_clear_passes() public {
        SanctionsPolicy p = new SanctionsPolicy();
        bytes memory d = _payload(1, 0, 0, 1, 2, 840, 0);
        assertTrue(this.call_validate_sanc(p, d));
    }

    function test_sanctions_hit_rejected() public {
        SanctionsPolicy p = new SanctionsPolicy();
        bytes memory d = _payload(1, 0, 1, 1, 2, 840, 0);
        assertFalse(this.call_validate_sanc(p, d));
    }

    function call_validate_sanc(SanctionsPolicy p, bytes calldata data) external view returns (bool) {
        return p.validate(_att(data));
    }

    // ============ Source of Funds ============

    function test_sof_verified_passes() public {
        SourceOfFundsPolicy p = new SourceOfFundsPolicy();
        bytes memory d = _payload(1, 0, 0, 1, 2, 840, 0);
        assertTrue(this.call_validate_sof(p, d));
    }

    function test_sof_not_verified_rejected() public {
        SourceOfFundsPolicy p = new SourceOfFundsPolicy();
        bytes memory d = _payload(1, 0, 0, 0, 2, 840, 0);
        assertFalse(this.call_validate_sof(p, d));
    }

    function call_validate_sof(SourceOfFundsPolicy p, bytes calldata data) external view returns (bool) {
        return p.validate(_att(data));
    }

    // ============ Professional ============

    function test_professional_any_nonzero_passes() public {
        ProfessionalInvestorPolicy p = new ProfessionalInvestorPolicy();
        for (uint8 t = 1; t <= 4; t++) {
            bytes memory d = _payload(1, 0, 0, 1, t, 840, 0);
            assertTrue(this.call_validate_prof(p, d), "nonzero should pass");
        }
    }

    function test_professional_none_rejected() public {
        ProfessionalInvestorPolicy p = new ProfessionalInvestorPolicy();
        bytes memory d = _payload(1, 0, 0, 1, 0, 840, 0);
        assertFalse(this.call_validate_prof(p, d));
    }

    function call_validate_prof(ProfessionalInvestorPolicy p, bytes calldata data) external view returns (bool) {
        return p.validate(_att(data));
    }

    // ============ Institutional ============

    function test_institutional_only_4_passes() public {
        InstitutionalInvestorPolicy p = new InstitutionalInvestorPolicy();
        for (uint8 t = 0; t <= 3; t++) {
            bytes memory d = _payload(1, 0, 0, 1, t, 840, 0);
            assertFalse(this.call_validate_inst(p, d), "non-institutional must fail");
        }
        bytes memory d4 = _payload(1, 0, 0, 1, 4, 840, 0);
        assertTrue(this.call_validate_inst(p, d4));
    }

    function call_validate_inst(InstitutionalInvestorPolicy p, bytes calldata data) external view returns (bool) {
        return p.validate(_att(data));
    }

    // ============ Country Allow-list ============

    function test_country_allow_list_allow_mode() public {
        uint16[] memory initial = new uint16[](2);
        initial[0] = 840; // US
        initial[1] = 826; // UK
        CountryAllowListPolicy p = new CountryAllowListPolicy(OWNER, CountryAllowListPolicy.Mode.Allow, initial);

        bytes memory us = _payload(1, 0, 0, 1, 2, 840, 0);
        bytes memory uk = _payload(1, 0, 0, 1, 2, 826, 0);
        bytes memory de = _payload(1, 0, 0, 1, 2, 276, 0);
        assertTrue(this.call_validate_country(p, us));
        assertTrue(this.call_validate_country(p, uk));
        assertFalse(this.call_validate_country(p, de));
    }

    function test_country_allow_list_block_mode() public {
        uint16[] memory initial = new uint16[](1);
        initial[0] = 408; // North Korea
        CountryAllowListPolicy p = new CountryAllowListPolicy(OWNER, CountryAllowListPolicy.Mode.Block, initial);

        bytes memory us = _payload(1, 0, 0, 1, 2, 840, 0);
        bytes memory kp = _payload(1, 0, 0, 1, 2, 408, 0);
        assertTrue(this.call_validate_country(p, us));
        assertFalse(this.call_validate_country(p, kp));
    }

    function test_country_add_remove() public {
        uint16[] memory initial = new uint16[](0);
        CountryAllowListPolicy p = new CountryAllowListPolicy(OWNER, CountryAllowListPolicy.Mode.Allow, initial);

        vm.prank(OWNER);
        p.addCountry(840);
        assertTrue(p.isInSet(840));

        vm.prank(OWNER);
        p.removeCountry(840);
        assertFalse(p.isInSet(840));
    }

    function test_country_admin_only() public {
        uint16[] memory initial = new uint16[](0);
        CountryAllowListPolicy p = new CountryAllowListPolicy(OWNER, CountryAllowListPolicy.Mode.Allow, initial);
        vm.expectRevert();
        p.addCountry(840);
    }

    function call_validate_country(CountryAllowListPolicy p, bytes calldata data) external view returns (bool) {
        return p.validate(_att(data));
    }

    // ============ Accreditation ============

    function test_accreditation_allowlist_basic() public {
        uint8[] memory types = new uint8[](2);
        types[0] = 2; // ACCREDITED
        types[1] = 3; // QP
        AccreditationPolicy p = new AccreditationPolicy(OWNER, types);

        assertTrue(this.call_validate_acc(p, _payload(1, 0, 0, 1, 2, 840, 0)));
        assertTrue(this.call_validate_acc(p, _payload(1, 0, 0, 1, 3, 840, 0)));
        assertFalse(this.call_validate_acc(p, _payload(1, 0, 0, 1, 0, 840, 0)));
        assertFalse(this.call_validate_acc(p, _payload(1, 0, 0, 1, 1, 840, 0)));
    }

    function test_accreditation_allow_disallow() public {
        uint8[] memory types = new uint8[](0);
        AccreditationPolicy p = new AccreditationPolicy(OWNER, types);

        vm.prank(OWNER);
        p.allow(4);
        assertTrue(p.isAllowed(4));

        vm.prank(OWNER);
        p.disallow(4);
        assertFalse(p.isAllowed(4));
    }

    function call_validate_acc(AccreditationPolicy p, bytes calldata data) external view returns (bool) {
        return p.validate(_att(data));
    }

    // ============ Metadata ============

    function test_topic_ids_and_names() public {
        KYCStatusPolicy k = new KYCStatusPolicy();
        assertEq(k.topicId(), 1);
        assertEq(k.name(), "KYCStatusPolicy");

        AMLPolicy a = new AMLPolicy();
        assertEq(a.topicId(), 2);

        SanctionsPolicy s = new SanctionsPolicy();
        assertEq(s.topicId(), 13);

        SourceOfFundsPolicy sf = new SourceOfFundsPolicy();
        assertEq(sf.topicId(), 14);

        ProfessionalInvestorPolicy pr = new ProfessionalInvestorPolicy();
        assertEq(pr.topicId(), 9);

        InstitutionalInvestorPolicy inst = new InstitutionalInvestorPolicy();
        assertEq(inst.topicId(), 10);

        uint16[] memory empty16 = new uint16[](0);
        CountryAllowListPolicy c = new CountryAllowListPolicy(OWNER, CountryAllowListPolicy.Mode.Allow, empty16);
        assertEq(c.topicId(), 3);

        uint8[] memory empty8 = new uint8[](0);
        AccreditationPolicy ac = new AccreditationPolicy(OWNER, empty8);
        assertEq(ac.topicId(), 7);
    }
}
