// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {AttestationRequest, AttestationRequestData} from "@eas/IEAS.sol";
import {MockEAS} from "../../contracts/mocks/MockEAS.sol";
import {RegistryOrbital} from "../../contracts/valence/modules/RegistryOrbital.sol";
import {TrustedAttestersOrbital} from "../../contracts/valence/modules/TrustedAttestersOrbital.sol";
import {IdentityMappingOrbital} from "../../contracts/valence/modules/IdentityMappingOrbital.sol";
import {VerificationOrbital} from "../../contracts/valence/modules/VerificationOrbital.sol";

contract ValenceVerificationOrbitalTest is Test {
    uint256 internal constant TOPIC_KYC = 7;
    bytes32 internal constant SCHEMA_KYC = keccak256("kyc.schema.v1");

    address internal owner = address(this);
    address internal wallet = address(0xA11CE);
    address internal identity = address(0xB0B);
    address internal trustedAttester = address(0xCAFE);

    MockEAS internal eas;
    RegistryOrbital internal registry;
    TrustedAttestersOrbital internal trusted;
    IdentityMappingOrbital internal identityMap;
    VerificationOrbital internal verification;

    function setUp() public {
        eas = new MockEAS();
        registry = new RegistryOrbital(owner);
        trusted = new TrustedAttestersOrbital(owner);
        identityMap = new IdentityMappingOrbital(owner);
        verification =
            new VerificationOrbital(owner, address(eas), address(registry), address(trusted), address(identityMap));

        registry.setTopicSchemaMapping(TOPIC_KYC, SCHEMA_KYC);
        trusted.setTrustedAttester(TOPIC_KYC, trustedAttester, true);
        identityMap.setIdentity(wallet, identity);

        uint256[] memory topics = new uint256[](1);
        topics[0] = TOPIC_KYC;
        verification.setRequiredClaimTopics(topics);
    }

    function test_isVerified_returnsTrueForValidAttestation() public {
        bytes32 uid = _attest(identity, trustedAttester, SCHEMA_KYC, uint64(block.timestamp + 30 days));
        registry.registerAttestation(identity, TOPIC_KYC, trustedAttester, uid);

        assertTrue(verification.isVerified(wallet));
    }

    function test_isVerified_returnsFalseForRevokedAttestation() public {
        bytes32 uid = _attest(identity, trustedAttester, SCHEMA_KYC, uint64(block.timestamp + 30 days));
        registry.registerAttestation(identity, TOPIC_KYC, trustedAttester, uid);
        eas.forceRevoke(uid);

        assertFalse(verification.isVerified(wallet));
    }

    function test_isVerified_returnsFalseWithoutTrustedAttester() public {
        address untrustedAttester = address(0xBAD);
        bytes32 uid = _attest(identity, untrustedAttester, SCHEMA_KYC, uint64(block.timestamp + 30 days));
        registry.registerAttestation(identity, TOPIC_KYC, untrustedAttester, uid);

        assertFalse(verification.isVerified(wallet));
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
