// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {EASClaimVerifierUpgradeable} from "../../contracts/upgradeable/EASClaimVerifierUpgradeable.sol";
import {EASTrustedIssuersAdapterUpgradeable} from "../../contracts/upgradeable/EASTrustedIssuersAdapterUpgradeable.sol";
import {EASIdentityProxyUpgradeable} from "../../contracts/upgradeable/EASIdentityProxyUpgradeable.sol";
import {MockEAS} from "../../contracts/mocks/MockEAS.sol";
import {MockClaimTopicsRegistry} from "../../contracts/mocks/MockClaimTopicsRegistry.sol";
import {IEASClaimVerifier} from "../../contracts/interfaces/IEASClaimVerifier.sol";
import {AttestationRequest, AttestationRequestData} from "@eas/IEAS.sol";

/**
 * @title UpgradeableContractsTest
 * @notice Unit tests for UUPS-upgradeable bridge contracts
 */
contract UpgradeableContractsTest is Test {
    EASClaimVerifierUpgradeable public verifierImpl;
    EASClaimVerifierUpgradeable public verifier;
    ERC1967Proxy public verifierProxy;

    EASTrustedIssuersAdapterUpgradeable public adapterImpl;
    EASTrustedIssuersAdapterUpgradeable public adapter;
    ERC1967Proxy public adapterProxy;

    EASIdentityProxyUpgradeable public identityProxyImpl;
    EASIdentityProxyUpgradeable public identityProxy;
    ERC1967Proxy public identityProxyProxy;

    MockEAS public eas;
    MockClaimTopicsRegistry public topicsRegistry;

    address public owner = address(this);
    address public nonOwner = makeAddr("nonOwner");
    address public attester1 = makeAddr("attester1");
    address public user1 = makeAddr("user1");

    uint256 public constant TOPIC_KYC = 1;
    bytes32 public schemaKYC = keccak256("InvestorEligibilityKYC");

    function setUp() public {
        // Deploy mocks
        eas = new MockEAS();
        topicsRegistry = new MockClaimTopicsRegistry();

        // Deploy adapter implementation and proxy
        adapterImpl = new EASTrustedIssuersAdapterUpgradeable();
        bytes memory adapterInitData = abi.encodeCall(EASTrustedIssuersAdapterUpgradeable.initialize, (owner));
        adapterProxy = new ERC1967Proxy(address(adapterImpl), adapterInitData);
        adapter = EASTrustedIssuersAdapterUpgradeable(address(adapterProxy));

        // Deploy identity proxy implementation and proxy
        identityProxyImpl = new EASIdentityProxyUpgradeable();
        bytes memory identityProxyInitData = abi.encodeCall(EASIdentityProxyUpgradeable.initialize, (owner));
        identityProxyProxy = new ERC1967Proxy(address(identityProxyImpl), identityProxyInitData);
        identityProxy = EASIdentityProxyUpgradeable(address(identityProxyProxy));

        // Deploy verifier implementation and proxy
        verifierImpl = new EASClaimVerifierUpgradeable();
        bytes memory verifierInitData = abi.encodeCall(EASClaimVerifierUpgradeable.initialize, (owner));
        verifierProxy = new ERC1967Proxy(address(verifierImpl), verifierInitData);
        verifier = EASClaimVerifierUpgradeable(address(verifierProxy));

        // Configure verifier
        verifier.setEASAddress(address(eas));
        verifier.setTrustedIssuersAdapter(address(adapter));
        verifier.setIdentityProxy(address(identityProxy));
        verifier.setClaimTopicsRegistry(address(topicsRegistry));
        verifier.setTopicSchemaMapping(TOPIC_KYC, schemaKYC);

        // Add trusted attester
        uint256[] memory topics = new uint256[](1);
        topics[0] = TOPIC_KYC;
        adapter.addTrustedAttester(attester1, topics);

        // Authorize this test contract as an identity-proxy agent
        identityProxy.addAgent(address(this));
    }

    // ============ Initialization Tests ============

    function test_initialize_setsOwner() public view {
        assertEq(verifier.owner(), owner);
        assertEq(adapter.owner(), owner);
        assertEq(identityProxy.owner(), owner);
    }

    function test_initialize_revertsOnReinitialization() public {
        vm.expectRevert();
        verifier.initialize(nonOwner);

        vm.expectRevert();
        adapter.initialize(nonOwner);

        vm.expectRevert();
        identityProxy.initialize(nonOwner);
    }

    function test_implementation_disabledInitializers() public {
        vm.expectRevert();
        verifierImpl.initialize(owner);

        vm.expectRevert();
        adapterImpl.initialize(owner);

        vm.expectRevert();
        identityProxyImpl.initialize(owner);
    }

    // ============ Verifier Functional Tests ============

    function test_verifier_setConfiguration() public {
        address newEAS = makeAddr("newEAS");
        verifier.setEASAddress(newEAS);
        assertEq(verifier.getEASAddress(), newEAS);

        address newAdapter = makeAddr("newAdapter");
        verifier.setTrustedIssuersAdapter(newAdapter);
        assertEq(verifier.getTrustedIssuersAdapter(), newAdapter);

        address newProxy = makeAddr("newProxy");
        verifier.setIdentityProxy(newProxy);
        assertEq(verifier.getIdentityProxy(), newProxy);
    }

    function test_verifier_isVerified_withValidAttestation() public {
        topicsRegistry.addClaimTopic(TOPIC_KYC);

        bytes memory data = abi.encode(user1, uint8(1), uint8(0), uint16(840), uint64(0));
        AttestationRequest memory request = AttestationRequest({
            schema: schemaKYC,
            data: AttestationRequestData({
                recipient: user1,
                expirationTime: 0,
                revocable: true,
                refUID: bytes32(0),
                data: data,
                value: 0
            })
        });
        bytes32 uid = eas.attestFrom(request, attester1);

        verifier.registerAttestation(user1, TOPIC_KYC, uid);
        assertTrue(verifier.isVerified(user1));
    }

    function test_verifier_onlyOwnerCanConfigure() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        verifier.setEASAddress(address(0x123));
    }

    // ============ Adapter Functional Tests ============

    function test_adapter_addTrustedAttester() public {
        address attester2 = makeAddr("attester2");
        uint256[] memory topics = new uint256[](1);
        topics[0] = TOPIC_KYC;

        adapter.addTrustedAttester(attester2, topics);
        assertTrue(adapter.isTrustedAttester(attester2));
        assertTrue(adapter.isAttesterTrusted(attester2, TOPIC_KYC));
    }

    function test_adapter_removeTrustedAttester() public {
        adapter.removeTrustedAttester(attester1);
        assertFalse(adapter.isTrustedAttester(attester1));
    }

    function test_adapter_onlyOwnerCanModify() public {
        address attester2 = makeAddr("attester2");
        uint256[] memory topics = new uint256[](1);
        topics[0] = TOPIC_KYC;

        vm.prank(nonOwner);
        vm.expectRevert();
        adapter.addTrustedAttester(attester2, topics);
    }

    // ============ Identity Proxy Functional Tests ============

    function test_identityProxy_registerWallet() public {
        address wallet = makeAddr("wallet");
        address identity = makeAddr("identity");

        identityProxy.registerWallet(wallet, identity);
        assertEq(identityProxy.getIdentity(wallet), identity);
        assertTrue(identityProxy.isRegistered(wallet));
    }

    function test_identityProxy_removeWallet() public {
        address wallet = makeAddr("wallet");
        address identity = makeAddr("identity");

        identityProxy.registerWallet(wallet, identity);
        identityProxy.removeWallet(wallet);
        assertFalse(identityProxy.isRegistered(wallet));
    }

    function test_identityProxy_agentManagement() public {
        address agent = makeAddr("agent");

        identityProxy.addAgent(agent);
        assertTrue(identityProxy.isAgent(agent));

        identityProxy.removeAgent(agent);
        assertFalse(identityProxy.isAgent(agent));
    }

    // ============ UUPS Upgrade Tests ============

    function test_verifier_upgradeToAndCall_onlyOwner() public {
        EASClaimVerifierUpgradeable newImpl = new EASClaimVerifierUpgradeable();

        vm.prank(nonOwner);
        vm.expectRevert();
        verifier.upgradeToAndCall(address(newImpl), "");
    }

    function test_verifier_upgradeToAndCall_preservesState() public {
        // Set some state
        topicsRegistry.addClaimTopic(TOPIC_KYC);
        verifier.setTopicSchemaMapping(99, keccak256("CustomSchema"));

        // Deploy new implementation
        EASClaimVerifierUpgradeable newImpl = new EASClaimVerifierUpgradeable();

        // Upgrade
        verifier.upgradeToAndCall(address(newImpl), "");

        // Verify state is preserved
        assertEq(verifier.getSchemaUID(TOPIC_KYC), schemaKYC);
        assertEq(verifier.getSchemaUID(99), keccak256("CustomSchema"));
        assertEq(verifier.getEASAddress(), address(eas));
        assertEq(verifier.owner(), owner);
    }

    function test_adapter_upgradeToAndCall_onlyOwner() public {
        EASTrustedIssuersAdapterUpgradeable newImpl = new EASTrustedIssuersAdapterUpgradeable();

        vm.prank(nonOwner);
        vm.expectRevert();
        adapter.upgradeToAndCall(address(newImpl), "");
    }

    function test_adapter_upgradeToAndCall_preservesState() public {
        // Add another attester before upgrade
        address attester2 = makeAddr("attester2");
        uint256[] memory topics = new uint256[](1);
        topics[0] = TOPIC_KYC;
        adapter.addTrustedAttester(attester2, topics);

        // Deploy new implementation
        EASTrustedIssuersAdapterUpgradeable newImpl = new EASTrustedIssuersAdapterUpgradeable();

        // Upgrade
        adapter.upgradeToAndCall(address(newImpl), "");

        // Verify state is preserved
        assertTrue(adapter.isTrustedAttester(attester1));
        assertTrue(adapter.isTrustedAttester(attester2));
        assertEq(adapter.owner(), owner);
    }

    function test_identityProxy_upgradeToAndCall_onlyOwner() public {
        EASIdentityProxyUpgradeable newImpl = new EASIdentityProxyUpgradeable();

        vm.prank(nonOwner);
        vm.expectRevert();
        identityProxy.upgradeToAndCall(address(newImpl), "");
    }

    function test_identityProxy_upgradeToAndCall_preservesState() public {
        // Register wallets before upgrade
        address wallet1 = makeAddr("wallet1");
        address wallet2 = makeAddr("wallet2");
        address identity = makeAddr("identity");

        identityProxy.registerWallet(wallet1, identity);
        identityProxy.registerWallet(wallet2, identity);

        // Deploy new implementation
        EASIdentityProxyUpgradeable newImpl = new EASIdentityProxyUpgradeable();

        // Upgrade
        identityProxy.upgradeToAndCall(address(newImpl), "");

        // Verify state is preserved
        assertEq(identityProxy.getIdentity(wallet1), identity);
        assertEq(identityProxy.getIdentity(wallet2), identity);
        assertTrue(identityProxy.isRegistered(wallet1));
        assertTrue(identityProxy.isRegistered(wallet2));
        assertEq(identityProxy.owner(), owner);
    }

    // ============ Edge Case Tests ============

    function test_verifier_upgradeToAndCall_withInitializerData() public {
        // Upgrading with data should work (even if empty)
        EASClaimVerifierUpgradeable newImpl = new EASClaimVerifierUpgradeable();
        verifier.upgradeToAndCall(address(newImpl), "");

        // Contract should still function
        assertEq(verifier.owner(), owner);
    }

    function test_multipleUpgrades_preservesState() public {
        // Initial state
        address wallet = makeAddr("wallet");
        address identity = makeAddr("identity");
        identityProxy.registerWallet(wallet, identity);

        // First upgrade
        EASIdentityProxyUpgradeable newImpl1 = new EASIdentityProxyUpgradeable();
        identityProxy.upgradeToAndCall(address(newImpl1), "");

        // Verify state
        assertEq(identityProxy.getIdentity(wallet), identity);

        // Second upgrade
        EASIdentityProxyUpgradeable newImpl2 = new EASIdentityProxyUpgradeable();
        identityProxy.upgradeToAndCall(address(newImpl2), "");

        // Verify state still preserved
        assertEq(identityProxy.getIdentity(wallet), identity);
        assertEq(identityProxy.owner(), owner);
    }

    // ============ Integration Test with Upgrades ============

    function test_fullFlow_afterUpgrade() public {
        // Setup initial state
        topicsRegistry.addClaimTopic(TOPIC_KYC);

        // Create and register attestation
        bytes memory data = abi.encode(user1, uint8(1), uint8(0), uint16(840), uint64(0));
        AttestationRequest memory request = AttestationRequest({
            schema: schemaKYC,
            data: AttestationRequestData({
                recipient: user1,
                expirationTime: 0,
                revocable: true,
                refUID: bytes32(0),
                data: data,
                value: 0
            })
        });
        bytes32 uid = eas.attestFrom(request, attester1);
        verifier.registerAttestation(user1, TOPIC_KYC, uid);

        // Verify before upgrade
        assertTrue(verifier.isVerified(user1));

        // Upgrade all contracts
        EASClaimVerifierUpgradeable newVerifierImpl = new EASClaimVerifierUpgradeable();
        verifier.upgradeToAndCall(address(newVerifierImpl), "");

        EASTrustedIssuersAdapterUpgradeable newAdapterImpl = new EASTrustedIssuersAdapterUpgradeable();
        adapter.upgradeToAndCall(address(newAdapterImpl), "");

        EASIdentityProxyUpgradeable newIdentityProxyImpl = new EASIdentityProxyUpgradeable();
        identityProxy.upgradeToAndCall(address(newIdentityProxyImpl), "");

        // Verify after upgrade - everything should still work
        assertTrue(verifier.isVerified(user1));
        assertTrue(adapter.isTrustedAttester(attester1));
        assertEq(verifier.getRegisteredAttestation(user1, TOPIC_KYC, attester1), uid);
    }

    // ============ Ownership Transfer Tests ============

    function test_verifier_transferOwnership() public {
        address newOwner = makeAddr("newOwner");
        verifier.transferOwnership(newOwner);
        assertEq(verifier.owner(), newOwner);
    }

    function test_adapter_transferOwnership() public {
        address newOwner = makeAddr("newOwner");
        adapter.transferOwnership(newOwner);
        assertEq(adapter.owner(), newOwner);
    }

    function test_identityProxy_transferOwnership() public {
        address newOwner = makeAddr("newOwner");
        identityProxy.transferOwnership(newOwner);
        assertEq(identityProxy.owner(), newOwner);
    }

    function test_newOwner_canUpgrade() public {
        address newOwner = makeAddr("newOwner");
        verifier.transferOwnership(newOwner);

        EASClaimVerifierUpgradeable newImpl = new EASClaimVerifierUpgradeable();

        // Old owner can't upgrade
        vm.expectRevert();
        verifier.upgradeToAndCall(address(newImpl), "");

        // New owner can upgrade
        vm.prank(newOwner);
        verifier.upgradeToAndCall(address(newImpl), "");
    }
}
