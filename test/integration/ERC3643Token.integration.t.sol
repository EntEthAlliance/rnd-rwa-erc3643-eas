// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
 * ERC3643Token integration test
 * ---------------------------------------------------------------------------
 * Proves Shibui's EASClaimVerifier plugs behind a standards-aligned ERC-3643
 * Token via the new one-method IIdentityVerifier extension point introduced on
 * EntEthAlliance/ERC-3643 branch feat/pluggable-identity-verifier.
 *
 * Why the weird deploy style?
 *   ERC-3643 contracts pin `pragma solidity =0.8.17` and import OpenZeppelin
 *   4.x, while Shibui is on 0.8.24 / OZ 5.x. We cannot import the ERC-3643
 *   sources directly into this 0.8.24 test file (no common solc version). We
 *   instead deploy them from hardhat-built artifacts via `vm.deployCode` and
 *   interact through minimal ABI-only interfaces declared below.
 *
 *   The submodule is pre-compiled by `cd lib/ERC-3643 && npx hardhat compile`
 *   (run once) which populates `lib/ERC-3643/artifacts/contracts/...`.
 *
 * Scenarios covered:
 *   1. Happy path:        two investors with valid Shibui attestations + wallet
 *                         bindings. Mint to A, transfer A->B succeeds.
 *   2. Revocation blocks: revoke B's KYC via EAS. transfer A->B reverts at token
 *                         level ("Transfer not possible") because isVerified->false.
 *   3. Policy failure:    investor C has all topics attested but accreditationType
 *                         = NONE -> mint reverts ("Identity is not verified.").
 *   4. Fallback:          setIdentityVerifier(0). Without a registered ONCHAINID,
 *                         the default path returns false and mint reverts.
 *                         Confirms the extension's default path.
 *
 * Gas snapshot (captured at end of test run, see docs/integration-gas.md):
 *   - token.transfer (Shibui-delegated) printed by test_happyPath_*
 *   - ERC-3643 upstream baseline: avg ~195_248 gas for ERC20.transfer with the
 *     built-in ONCHAINID path (from hardhat gas reporter on the fork base
 *     branch, pre-extension). After adding the extension, baseline rose to
 *     ~197_367 gas (one extra SLOAD to read _identityVerifier when zero).
 */

import {BridgeHarness} from "../helpers/BridgeHarness.sol";
import {MockAttester} from "../../contracts/mocks/MockAttester.sol";
import {RevocationRequest, RevocationRequestData} from "@eas/IEAS.sol";

// --- Minimal ABI views of the ERC-3643 contracts we drive through vm.deployCode ---

interface IIdentityRegistryView {
    function init(address _trustedIssuersRegistry, address _claimTopicsRegistry, address _identityStorage) external;
    function setIdentityVerifier(address _verifier) external;
    function identityVerifier() external view returns (address);
    function isVerified(address _userAddress) external view returns (bool);
    function addAgent(address _agent) external;
}

interface IIdentityRegistryStorageView {
    function init() external;
    function bindIdentityRegistry(address _identityRegistry) external;
}

interface IClaimTopicsRegistryView {
    function init() external;
}

interface ITrustedIssuersRegistryView {
    function init() external;
}

interface IModularComplianceView {
    function init() external;
}

interface ITokenView {
    function init(
        address _identityRegistry,
        address _compliance,
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _onchainID
    ) external;
    function addAgent(address _agent) external;
    function unpause() external;
    function mint(address _to, uint256 _amount) external;
    function transfer(address _to, uint256 _amount) external returns (bool);
    function balanceOf(address _account) external view returns (uint256);
}

contract ERC3643TokenIntegrationTest is BridgeHarness {
    // Deployed ERC-3643 stack (ABI handles to hardhat-artifact-deployed contracts)
    IIdentityRegistryView internal identityRegistry;
    IIdentityRegistryStorageView internal irs;
    IClaimTopicsRegistryView internal ctr;
    ITrustedIssuersRegistryView internal tir;
    IModularComplianceView internal compliance;
    ITokenView internal token;

    // Actors
    address internal investorA;
    address internal walletA;
    address internal investorB;
    address internal walletB;
    address internal investorC;
    address internal walletC;

    MockAttester internal kycProvider;

    // Artifact paths (relative to project root). These are produced by running
    // `npx hardhat compile` inside lib/ERC-3643 once before running the test.
    string internal constant ART_IR = "lib/ERC-3643/artifacts/contracts/registry/implementation/IdentityRegistry.sol/IdentityRegistry.json";
    string internal constant ART_IRS = "lib/ERC-3643/artifacts/contracts/registry/implementation/IdentityRegistryStorage.sol/IdentityRegistryStorage.json";
    string internal constant ART_CTR = "lib/ERC-3643/artifacts/contracts/registry/implementation/ClaimTopicsRegistry.sol/ClaimTopicsRegistry.json";
    string internal constant ART_TIR = "lib/ERC-3643/artifacts/contracts/registry/implementation/TrustedIssuersRegistry.sol/TrustedIssuersRegistry.json";
    string internal constant ART_MC = "lib/ERC-3643/artifacts/contracts/compliance/modular/ModularCompliance.sol/ModularCompliance.json";
    string internal constant ART_TOKEN = "lib/ERC-3643/artifacts/contracts/token/Token.sol/Token.json";

    function setUp() public {
        _setupBridge();

        investorA = makeAddr("investorA");
        walletA = makeAddr("walletA");
        investorB = makeAddr("investorB");
        walletB = makeAddr("walletB");
        investorC = makeAddr("investorC");
        walletC = makeAddr("walletC");

        kycProvider = _createAttester(
            "KYC",
            _topicsArray(TOPIC_KYC, TOPIC_ACCREDITATION, TOPIC_COUNTRY, TOPIC_SANCTIONS)
        );

        _bindWallet(walletA, investorA);
        _bindWallet(walletB, investorB);
        _bindWallet(walletC, investorC);

        _setRequiredTopics(_topicsArray(TOPIC_KYC, TOPIC_ACCREDITATION, TOPIC_COUNTRY, TOPIC_SANCTIONS));

        // ---- Deploy ERC-3643 stack from hardhat artifacts ----
        vm.startPrank(tokenIssuer);

        irs = IIdentityRegistryStorageView(deployCode(ART_IRS));
        irs.init();

        ctr = IClaimTopicsRegistryView(deployCode(ART_CTR));
        ctr.init();

        tir = ITrustedIssuersRegistryView(deployCode(ART_TIR));
        tir.init();

        identityRegistry = IIdentityRegistryView(deployCode(ART_IR));
        identityRegistry.init(address(tir), address(ctr), address(irs));
        irs.bindIdentityRegistry(address(identityRegistry));

        compliance = IModularComplianceView(deployCode(ART_MC));
        compliance.init();

        token = ITokenView(deployCode(ART_TOKEN));
        token.init(address(identityRegistry), address(compliance), "Shibui Bond", "SBND", 0, address(0));
        token.addAgent(tokenIssuer);
        token.unpause();

        // Wire Shibui's EASClaimVerifier behind the IdentityRegistry.
        identityRegistry.setIdentityVerifier(address(verifier));

        vm.stopPrank();
    }

    // --------------------------------------------------------------------
    // Scenario 1: Happy path — mint then transfer A -> B
    // --------------------------------------------------------------------
    function test_happyPath_mint_and_transfer_delegates_to_shibui() public {
        EligibilityData memory e = _happyPayload(uint64(block.timestamp + 365 days));
        _attestAndRegister(
            kycProvider,
            investorA,
            _topicsArray(TOPIC_KYC, TOPIC_ACCREDITATION, TOPIC_COUNTRY, TOPIC_SANCTIONS),
            e
        );
        _attestAndRegister(
            kycProvider,
            investorB,
            _topicsArray(TOPIC_KYC, TOPIC_ACCREDITATION, TOPIC_COUNTRY, TOPIC_SANCTIONS),
            e
        );

        assertTrue(identityRegistry.isVerified(walletA));
        assertTrue(identityRegistry.isVerified(walletB));

        vm.prank(tokenIssuer);
        token.mint(walletA, 1_000);
        assertEq(token.balanceOf(walletA), 1_000);

        uint256 gasBefore = gasleft();
        vm.prank(walletA);
        token.transfer(walletB, 400);
        uint256 gasUsed = gasBefore - gasleft();
        emit log_named_uint("token.transfer gas (Shibui-delegated)", gasUsed);

        assertEq(token.balanceOf(walletA), 600);
        assertEq(token.balanceOf(walletB), 400);
    }

    // --------------------------------------------------------------------
    // Scenario 2: Revoke B's KYC attestation -> transfer A->B reverts
    // --------------------------------------------------------------------
    function test_revocation_blocks_transfer_through_token_level() public {
        EligibilityData memory e = _happyPayload(uint64(block.timestamp + 365 days));
        _attestAndRegister(
            kycProvider,
            investorA,
            _topicsArray(TOPIC_KYC, TOPIC_ACCREDITATION, TOPIC_COUNTRY, TOPIC_SANCTIONS),
            e
        );
        bytes32 uidB = _attestAndRegister(
            kycProvider,
            investorB,
            _topicsArray(TOPIC_KYC, TOPIC_ACCREDITATION, TOPIC_COUNTRY, TOPIC_SANCTIONS),
            e
        );

        vm.prank(tokenIssuer);
        token.mint(walletA, 1_000);

        vm.prank(address(kycProvider));
        eas.revoke(
            RevocationRequest({schema: SCHEMA_INVESTOR_ELIGIBILITY, data: RevocationRequestData({uid: uidB, value: 0})})
        );

        assertFalse(identityRegistry.isVerified(walletB));

        vm.prank(walletA);
        vm.expectRevert(bytes("Transfer not possible"));
        token.transfer(walletB, 100);

        assertEq(token.balanceOf(walletA), 1_000);
        assertEq(token.balanceOf(walletB), 0);
    }

    // --------------------------------------------------------------------
    // Scenario 3: policy failure — accreditationType NONE blocks mint
    // --------------------------------------------------------------------
    function test_policy_failure_blocks_mint() public {
        EligibilityData memory bad = _happyPayload(uint64(block.timestamp + 365 days));
        bad.accreditationType = 0; // NONE -> AccreditationPolicy rejects
        _attestAndRegister(
            kycProvider,
            investorC,
            _topicsArray(TOPIC_KYC, TOPIC_ACCREDITATION, TOPIC_COUNTRY, TOPIC_SANCTIONS),
            bad
        );

        assertFalse(identityRegistry.isVerified(walletC));

        vm.prank(tokenIssuer);
        vm.expectRevert(bytes("Identity is not verified."));
        token.mint(walletC, 100);
    }

    // --------------------------------------------------------------------
    // Scenario 4: Fallback — clear verifier, default path fails without ONCHAINID
    // --------------------------------------------------------------------
    function test_fallback_clears_verifier_and_built_in_path_blocks_mint() public {
        vm.prank(tokenIssuer);
        identityRegistry.setIdentityVerifier(address(0));
        assertEq(identityRegistry.identityVerifier(), address(0));

        // No ONCHAINID identity registered in the IdentityRegistryStorage for
        // walletA, so the built-in isVerified returns false at the first check.
        assertFalse(identityRegistry.isVerified(walletA));

        vm.prank(tokenIssuer);
        vm.expectRevert(bytes("Identity is not verified."));
        token.mint(walletA, 100);
    }
}

