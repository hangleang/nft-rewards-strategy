// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// std lib
import {Test} from "forge-std/Test.sol";

// external lib
import {IAllo} from "allo/contracts/core/interfaces/IAllo.sol";
import {IRegistry} from "allo/contracts/core/interfaces/IRegistry.sol";
import {ISignatureTransfer} from "permit2/ISignatureTransfer.sol";

// Test libraries
import {PermitSignature} from "allo/lib/permit2/test/utils/PermitSignature.sol";
import {DonationVotingMerkleDistributionBaseMockTest} from "allo/test/foundry/strategies/DonationVotingMerkleDistributionBase.t.sol";

// internal
import {NFTRewardStrategy} from "src/NFTRewardStrategy.sol";
import {INFTs} from "src/externals/INFTs.sol";

contract NFTRewardStrategyTest is DonationVotingMerkleDistributionBaseMockTest {
    NFTRewardStrategy internal _strategy;
    // INFTs internal nfts;

    function _deployStrategy() internal override returns (address payable) {
        _strategy = new NFTRewardStrategy(
            address(allo()),
            "NFTRewardStrategy", permit2
        );
        return payable(address(_strategy));
    }

    // create 3 _different_ forks during setup
    // function setUp() public virtual override {
    //     // opGoerliFork = vm.createFork(vm.envString("OP_GOERLI_RPC_URL"));
    //     // pgnSepoliaFork = vm.createFork(vm.envString("PGN_SEPOLIA_RPC_URL"));
    //     // celoAlfajoresFork = vm.createFork(vm.envString("CELO_ALFAJORES_RPC_URL"));

    //     // allo = IAllo(0xfF65C1D4432D23C45b0730DaeCd03b6B92cd074a);
    //     // registry = IRegistry(0xC5CcdcF78a8a789Ef0DfEcD6f3126D3b91D48fe5);
    //     // nfts = INFTs(0x0);

    //     // permit2 = ISignatureTransfer(address(new Permit2()));
    //     // strategyImpl = new NFTRewardStrategy(address(allo), "NFTRewardStrategy", permit2);
    // }
}