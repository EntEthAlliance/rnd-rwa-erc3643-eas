// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AttestationRequest, AttestationRequestData} from "@eas/IEAS.sol";
import {MockEAS} from "../../contracts/mocks/MockEAS.sol";
import {MockValenceKernelRouting} from "../../contracts/mocks/MockValenceKernelRouting.sol";
import {ValenceEASKernelAdapter, IValenceKernelRouting} from "../../contracts/valence/ValenceEASKernelAdapter.sol";
import {VerificationOrbital} from "../../contracts/valence/modules/VerificationOrbital.sol";

contract ValenceUpgradePersistenceTest is Test {
    uint256 internal constant TOPIC_KYC = 7;
    bytes32 internal constant SCHEMA_KYC = keccak256("kyc.schema.v1");

    address internal wallet = address(0xA11CE);
    address internal identity = address(0xB0B);
    address internal trustedAttester = address(0xCAFE);

    MockEAS internal eas;
    MockValenceKernelRouting internal kernel;
    ValenceEASKernelAdapter internal adapter;

    function setUp() public {
        ValenceEASKernelAdapter.GovernanceProfile memory profile = ValenceEASKernelAdapter.GovernanceProfile({
            cutMultisig: address(0xA11CE), minApprovals: 2, standardCutTimelock: 24 hours, emergencyCutTimelock: 1 hours
        });

        adapter = new ValenceEASKernelAdapter(address(this), profile);
        eas = new MockEAS();
        kernel = new MockValenceKernelRouting();

        adapter.applyRoutesToKernel(address(kernel));
        adapter.verificationOrbital()
            .setDependencies(
                address(eas),
                address(adapter.registryOrbital()),
                address(adapter.trustedAttestersOrbital()),
                address(adapter.identityMappingOrbital())
            );
    }

    function test_stateSurvivesSelectorReplacementAndRestore() public {
        _seedVerificationState();
        bytes4 selector = VerificationOrbital.isVerified.selector;
        address originalModule = address(adapter.verificationOrbital());

        assertEq(kernel.moduleForSelector(selector), originalModule);
        assertTrue(adapter.verificationOrbital().isVerified(wallet));

        IValenceKernelRouting.SelectorRoute[] memory replacements = new IValenceKernelRouting.SelectorRoute[](1);
        replacements[0] = IValenceKernelRouting.SelectorRoute({selector: selector, module: address(0xD00D)});
        bytes4[] memory removals = new bytes4[](0);
        kernel.applySelectorRouteDelta(replacements, removals);

        assertEq(kernel.moduleForSelector(selector), address(0xD00D));

        replacements[0] = IValenceKernelRouting.SelectorRoute({selector: selector, module: originalModule});
        kernel.applySelectorRouteDelta(replacements, removals);

        assertEq(kernel.moduleForSelector(selector), originalModule);
        assertTrue(adapter.verificationOrbital().isVerified(wallet));
        assertEq(adapter.identityMappingOrbital().getIdentity(wallet), identity);
    }

    function test_stateSurvivesEmergencyRemoveAndReAddRoute() public {
        _seedVerificationState();
        bytes4 selector = VerificationOrbital.isVerified.selector;

        IValenceKernelRouting.SelectorRoute[] memory replacements = new IValenceKernelRouting.SelectorRoute[](0);
        bytes4[] memory removals = new bytes4[](1);
        removals[0] = selector;

        kernel.applySelectorRouteDelta(replacements, removals);
        assertEq(kernel.moduleForSelector(selector), address(0));

        replacements = new IValenceKernelRouting.SelectorRoute[](1);
        replacements[0] =
            IValenceKernelRouting.SelectorRoute({selector: selector, module: address(adapter.verificationOrbital())});
        removals = new bytes4[](0);
        kernel.applySelectorRouteDelta(replacements, removals);

        assertEq(kernel.moduleForSelector(selector), address(adapter.verificationOrbital()));
        assertTrue(adapter.verificationOrbital().isVerified(wallet));
    }

    function _seedVerificationState() internal {
        adapter.registryOrbital().setTopicSchemaMapping(TOPIC_KYC, SCHEMA_KYC);
        adapter.trustedAttestersOrbital().setTrustedAttester(TOPIC_KYC, trustedAttester, true);
        adapter.identityMappingOrbital().setIdentity(wallet, identity);

        uint256[] memory topics = new uint256[](1);
        topics[0] = TOPIC_KYC;
        adapter.verificationOrbital().setRequiredClaimTopics(topics);

        bytes32 uid = _attest(identity, trustedAttester, SCHEMA_KYC, uint64(block.timestamp + 30 days));
        adapter.registryOrbital().registerAttestation(identity, TOPIC_KYC, trustedAttester, uid);
    }

    function _attest(address recipient, address attester, bytes32 schema, uint64 expirationTime)
        internal
        returns (bytes32 uid)
    {
        AttestationRequest memory request = AttestationRequest({
            schema: schema,
            data: AttestationRequestData({
                recipient: recipient,
                expirationTime: expirationTime,
                revocable: true,
                refUID: bytes32(0),
                data: abi.encode(recipient, uint8(1), uint8(1), uint16(840), uint64(block.timestamp + 30 days)),
                value: 0
            })
        });

        uid = eas.attestFrom(request, attester);
    }
}
