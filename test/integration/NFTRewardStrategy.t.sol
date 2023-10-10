// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// std lib
import {Test} from "forge-std/Test.sol";

// Core contracts
import {IAllo} from "allo/contracts/core/interfaces/IAllo.sol";
import {IRegistry} from "allo/contracts/core/interfaces/IRegistry.sol";
import {ISignatureTransfer} from "permit2/ISignatureTransfer.sol";
import {Metadata} from "allo/contracts/core/libraries/Metadata.sol";
import {DonationVotingMerkleDistributionBaseStrategy} from
    "allo/contracts/strategies/donation-voting-merkle-base/DonationVotingMerkleDistributionBaseStrategy.sol";

// Test libraries
import {PermitSignature} from "allo/lib/permit2/test/utils/PermitSignature.sol";
import {DonationVotingMerkleDistributionBaseMockTest} from "allo/test/foundry/strategies/DonationVotingMerkleDistributionBase.t.sol";

// Internal contracts
import {NFTRewardStrategy} from "src/NFTRewardStrategy.sol";
import {INFTs} from "src/externals/INFTs.sol";
import {NFTsSetup} from "../shared/NFTsSetup.sol";

// Mock contracts
import {MockERC20} from "allo/test/utils/MockERC20.sol";
import {DonationVotingMerkleDistributionBaseMock} from "allo/test/utils/DonationVotingMerkleDistributionBaseMock.sol";
import {Permit2} from "allo/test/utils/Permit2Mock.sol";

// opGoerliFork = vm.createFork(vm.envString("OP_GOERLI_RPC_URL"));
// pgnSepoliaFork = vm.createFork(vm.envString("PGN_SEPOLIA_RPC_URL"));
// celoAlfajoresFork = vm.createFork(vm.envString("CELO_ALFAJORES_RPC_URL"));

// allo = IAllo(0xfF65C1D4432D23C45b0730DaeCd03b6B92cd074a);
// registry = IRegistry(0xC5CcdcF78a8a789Ef0DfEcD6f3126D3b91D48fe5);

contract NFTRewardStrategyTest is DonationVotingMerkleDistributionBaseMockTest, NFTsSetup {
    NFTRewardStrategy internal _strategy;
    uint256 internal _initAmount;

    function _deployStrategy() internal override returns (address payable) {
        _strategy = new NFTRewardStrategy(
            address(allo()),
            "NFTRewardStrategy", 
            permit2
        );
        return payable(address(_strategy));
    }

    function setUp() public virtual override {
        __RegistrySetupFull();
        __AlloSetup(address(registry()));
        __NFTsSetup(allo_owner());

        permit2 = ISignatureTransfer(address(new Permit2()));

        registrationStartTime = uint64(block.timestamp + 10);
        registrationEndTime = uint64(block.timestamp + 300);
        allocationStartTime = uint64(block.timestamp + 301);
        allocationEndTime = uint64(block.timestamp + 600);

        useRegistryAnchor = true;
        metadataRequired = true;

        poolMetadata = Metadata({protocol: 1, pointer: "PoolMetadata"});

        strategy = DonationVotingMerkleDistributionBaseMock(_deployStrategy());
        mockERC20 = new MockERC20();

        mockERC20.mint(address(this), 1_000_000 * 1e18);

        allowedTokens = new address[](2);
        allowedTokens[0] = NATIVE;
        allowedTokens[1] = address(mockERC20);

        vm.prank(allo_owner());
        allo().updatePercentFee(0);

        _initAmount = 1 ether;
        vm.deal(pool_admin(), _initAmount);
        vm.prank(pool_admin());
        poolId = allo().createPoolWithCustomStrategy{value: _initAmount}(
            poolProfile_id(),
            address(_strategy),
            abi.encode(
                NFTRewardStrategy.InitializeStrategyData(
                    address(nfts()),
                    DonationVotingMerkleDistributionBaseStrategy.InitializeData(
                        useRegistryAnchor,
                        metadataRequired,
                        registrationStartTime,
                        registrationEndTime,
                        allocationStartTime,
                        allocationEndTime,
                        allowedTokens
                    )
                )
            ),
            NATIVE,
            _initAmount,
            poolMetadata,
            pool_managers()
        );
    }
}