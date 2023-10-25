// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Script } from "forge-std/Script.sol";
import { Config } from "../Config.sol";

import { INFTs } from "src/externals/INFTs.sol";
import { NFTRewardStrategy } from "src/NFTRewardStrategy.sol";
// import { IMulticall3 } from "forge-std/interfaces/IMulticall3.sol";

// struct ClaimCondition {
//     uint256 startTimestamp;
//     uint256 endTimestamp;
//     uint256 maxClaimableSupply;
//     uint256 supplyClaimed;
//     uint256 quantityLimitPerWallet;
//     bytes32 merkleRoot;
//     uint256 pricePerToken;
//     address currency;
//     string metadata;
//     address onlyFrom;
//     bool collectPrice;
// }

/// @notice This script is used to set claim condition for a tokenId with test data for the Allo V2 contracts
/// @dev Use this to run
///      'source .env' if you are using a .env file for your rpc-url
///      'forge script script/interaction/SetClaimCondition.s.sol:SetClaimCondition --rpc-url https://goerli.infura.io/v3/$API_KEY_INFURA --broadcast -vvvv'
contract SetClaimCondition is Script, Config {
    // Initialize the NFTs contract
    INFTs nfts = INFTs(NFT);

    // Initialize the Strategy contract
    NFTRewardStrategy strategy = NFTRewardStrategy(payable(address(STRATEGY)));

    // IMulticall3 multicall3 = IMulticall3(address(MULTICALL3_ADDRESS));

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);

        nfts.setClaimConditions(
            RECIPIENT_1_TOKEN_ID, 
            INFTs.ClaimCondition(
                strategy.allocationStartTime(),
                strategy.allocationEndTime(),
                1000,
                0,
                10,
                bytes32(0),
                0.001 ether,
                NATIVE,
                string.concat("ipfs://", METADATA_POINTER),
                STRATEGY,
                false
            ), 
            false
        );

        // IMulticall3.Call3[] memory calls = new IMulticall3.Call3[](RECIPIENT_1_NFT_AMOUNT - 1);

        // for (uint256 i=1; i<RECIPIENT_1_NFT_AMOUNT - 1;) {
        //     calls[i] = IMulticall3.Call3({
        //         target: NFT,
        //         allowFailure: false,
        //         callData: abi.encodeWithSelector(
        //             INFTs.setClaimConditions.selector, 
        //             RECIPIENT_1_TOKEN_ID + i, 
        //             INFTs.ClaimCondition(
        //                 strategy.allocationStartTime(),
        //                 strategy.allocationEndTime(),
        //                 1000,
        //                 0,
        //                 10,
        //                 bytes32(0),
        //                 0.001 ether,
        //                 NATIVE,
        //                 string.concat("ipfs://", METADATA_POINTER),
        //                 STRATEGY,
        //                 false
        //             ), 
        //             false
        //         )
        //     });

        //     unchecked {
        //         ++i;
        //     }
        // }

        // multicall3.aggregate3(calls);

        vm.stopBroadcast();
    }
}