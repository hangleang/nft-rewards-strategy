// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Script } from "forge-std/Script.sol";
import { Config } from "../Config.sol";

import { NFTRewardStrategy } from "src/NFTRewardStrategy.sol";

/// @notice This script is used to update pool registration & allocation timestamps with test data for the Allo V2 contracts
/// @dev Use this to run
///      'source .env' if you are using a .env file for your rpc-url
///      'forge script script/interaction/UpdatePoolTimestamps.s.sol:UpdatePoolTimestamps --rpc-url https://goerli.infura.io/v3/$API_KEY_INFURA --broadcast -vvvv'
contract UpdatePoolTimestamps is Script, Config {
    // Initialize the Strategy contract
    NFTRewardStrategy strategy = NFTRewardStrategy(payable(address(STRATEGY)));

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);

        strategy.updatePoolTimestamps(
            uint64(block.timestamp + 10),
            uint64(block.timestamp + 2 hours),
            uint64(block.timestamp + 10 minutes),
            uint64(block.timestamp + 3 days)
        );

        vm.stopBroadcast();
    }
}