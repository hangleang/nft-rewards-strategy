// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Script } from "forge-std/Script.sol";
import { Config } from "./Config.sol";

import { NFTRewardStrategy } from "src/NFTRewardStrategy.sol";
import { ISignatureTransfer } from "permit2/ISignatureTransfer.sol";

/// @notice A very simple deployment script
contract Deploy is Script, Config {
    /// @notice The main script entrypoint
    /// @return strategy The deployed implementation contract
    function run() external returns (NFTRewardStrategy strategy) {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        strategy = new NFTRewardStrategy(ALLO, "NFTRewardStrategy v1", ISignatureTransfer(PERMIT2));
        vm.stopBroadcast();
    }
}
