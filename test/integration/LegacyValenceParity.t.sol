// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {EASClaimVerifier} from "../../contracts/EASClaimVerifier.sol";
import {EASTrustedIssuersAdapter} from "../../contracts/EASTrustedIssuersAdapter.sol";
import {EASIdentityProxy} from "../../contracts/EASIdentityProxy.sol";
import {MockEAS} from "../../contracts/mocks/MockEAS.sol";
import {MockClaimTopicsRegistry} from "../../contracts/mocks/MockClaimTopicsRegistry.sol";
import {MockAttester} from "../../contracts/mocks/MockAttester.sol";
import {ValenceEASKernelAdapter} from "../../contracts/valence/ValenceEASKernelAdapter.sol";

contract LegacyValenceParityTest is Test {
    uint256 internal constant TOPIC_KYC = 1;
    uint256 internal constant TOPIC_ACCREDITATION = 2;
    bytes32 internal constant SCHEMA_KYC = keccak256("KYC_SCHEMA");
    bytes32 internal constant SCHEMA_ACCREDITATION = keccak256("ACCREDITATION_SCHEMA");

    address internal owner = address(this);
    address internal wallet = address(0xA11CE);
    address internal identity = address(0xB0B);

    MockEAS internal eas;
    MockClaimTopicsRegistry internal claimTopics;
    MockAttester internal kycAttester;
    MockAttester internal accreditationAttester;

    EASClaimVerifier internal legacy;
    EASTrustedIssuersAdapter internal trustedIssuers;
    EASIdentityProxy internal identityProxy;

    ValenceEASKernelAdapter internal valence;

    function setUp() public {
        eas = new MockEAS();
        claimTopics = new MockClaimTopicsRegistry();
        kycAttester = new MockAttester(address(eas), "KYC");
        accreditationAttester = new MockAttester(address(eas), "Accreditation");

        legacy = new EASClaimVerifier(owner);
        trustedIssuers = new EASTrustedIssuersAdapter(owner);
        identityProxy = new EASIdentityProxy(owner);

        legacy.setEASAddress(address(eas));
        legacy.setTrustedIssuersAdapter(address(trustedIssuers));
        legacy.setIdentityProxy(address(identityProxy));
        legacy.setClaimTopicsRegistry(address(claimTopics));
        legacy.setTopicSchemaMapping(TOPIC_KYC, SCHEMA_KYC);
        legacy.setTopicSchemaMapping(TOPIC_ACCREDITATION, SCHEMA_ACCREDITATION);

        uint256[] memory kycTopic = new uint256[](1);
        kycTopic[0] = TOPIC_KYC;
        trustedIssuers.addTrustedAttester(address(kycAttester), kycTopic);

        uint256[] memory accTopic = new uint256[](1);
        accTopic[0] = TOPIC_ACCREDITATION;
        trustedIssuers.addTrustedAttester(address(accreditationAttester), accTopic);

        identityProxy.registerWallet(wallet, identity);

        ValenceEASKernelAdapter.GovernanceProfile memory profile = ValenceEASKernelAdapter.GovernanceProfile({
            cutMultisig: address(0xA11CE), minApprovals: 2, standardCutTimelock: 24 hours, emergencyCutTimelock: 1 hours
        });
        valence = new ValenceEASKernelAdapter(owner, profile);

        valence.verificationOrbital()
            .setDependencies(
                address(eas),
                address(valence.registryOrbital()),
                address(valence.trustedAttestersOrbital()),
                address(valence.identityMappingOrbital())
            );
        valence.registryOrbital().setTopicSchemaMapping(TOPIC_KYC, SCHEMA_KYC);
        valence.registryOrbital().setTopicSchemaMapping(TOPIC_ACCREDITATION, SCHEMA_ACCREDITATION);
        valence.trustedAttestersOrbital().setTrustedAttester(TOPIC_KYC, address(kycAttester), true);
        valence.trustedAttestersOrbital().setTrustedAttester(TOPIC_ACCREDITATION, address(accreditationAttester), true);
        valence.identityMappingOrbital().setIdentity(wallet, identity);

        uint256[] memory requiredTopics = new uint256[](1);
        requiredTopics[0] = TOPIC_KYC;
        claimTopics.setClaimTopics(requiredTopics);
        valence.verificationOrbital().setRequiredClaimTopics(requiredTopics);
    }

    function test_parity_validAttestation() public {
        bytes32 uid = kycAttester.attestInvestorEligibility(SCHEMA_KYC, identity, identity, 1, 0, 840, 0);
        legacy.registerAttestation(identity, TOPIC_KYC, uid);
        valence.registryOrbital().registerAttestation(identity, TOPIC_KYC, address(kycAttester), uid);

        _assertParity(wallet, true);
    }

    function test_parity_revokedAttestation() public {
        bytes32 uid = kycAttester.attestInvestorEligibility(SCHEMA_KYC, identity, identity, 1, 0, 840, 0);
        legacy.registerAttestation(identity, TOPIC_KYC, uid);
        valence.registryOrbital().registerAttestation(identity, TOPIC_KYC, address(kycAttester), uid);

        eas.forceRevoke(uid);
        _assertParity(wallet, false);
    }

    function test_parity_expiredAttestation() public {
        bytes32 uid = kycAttester.attestInvestorEligibility(
            SCHEMA_KYC, identity, identity, 1, 0, 840, uint64(block.timestamp + 1)
        );
        legacy.registerAttestation(identity, TOPIC_KYC, uid);
        valence.registryOrbital().registerAttestation(identity, TOPIC_KYC, address(kycAttester), uid);

        vm.warp(block.timestamp + 2);
        _assertParity(wallet, false);
    }

    function test_parity_multiTopicRequirement() public {
        uint256[] memory requiredTopics = new uint256[](2);
        requiredTopics[0] = TOPIC_KYC;
        requiredTopics[1] = TOPIC_ACCREDITATION;
        claimTopics.setClaimTopics(requiredTopics);
        valence.verificationOrbital().setRequiredClaimTopics(requiredTopics);

        bytes32 kycUid = kycAttester.attestInvestorEligibility(SCHEMA_KYC, identity, identity, 1, 0, 840, 0);
        legacy.registerAttestation(identity, TOPIC_KYC, kycUid);
        valence.registryOrbital().registerAttestation(identity, TOPIC_KYC, address(kycAttester), kycUid);

        _assertParity(wallet, false);

        bytes32 accUid =
            accreditationAttester.attestInvestorEligibility(SCHEMA_ACCREDITATION, identity, identity, 1, 0, 840, 0);
        legacy.registerAttestation(identity, TOPIC_ACCREDITATION, accUid);
        valence.registryOrbital()
            .registerAttestation(identity, TOPIC_ACCREDITATION, address(accreditationAttester), accUid);

        _assertParity(wallet, true);
    }

    function test_parity_identityRemap() public {
        address remappedIdentity = address(0xD00D);
        identityProxy.removeWallet(wallet);
        identityProxy.registerWallet(wallet, remappedIdentity);
        valence.identityMappingOrbital().setIdentity(wallet, remappedIdentity);

        bytes32 uid =
            kycAttester.attestInvestorEligibility(SCHEMA_KYC, remappedIdentity, remappedIdentity, 1, 0, 840, 0);
        legacy.registerAttestation(remappedIdentity, TOPIC_KYC, uid);
        valence.registryOrbital().registerAttestation(remappedIdentity, TOPIC_KYC, address(kycAttester), uid);

        _assertParity(wallet, true);
    }

    function _assertParity(address subject, bool expected) internal view {
        bool legacyResult = legacy.isVerified(subject);
        bool valenceResult = valence.verificationOrbital().isVerified(subject);

        assertEq(legacyResult, expected, "legacy mismatch");
        assertEq(valenceResult, expected, "valence mismatch");
    }
}
