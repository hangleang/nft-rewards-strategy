// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Script } from "forge-std/Script.sol";

import { NFTRewardStrategy } from "src/NFTRewardStrategy.sol";
import { ISignatureTransfer } from "permit2/ISignatureTransfer.sol";

/// @notice A very simple deployment script
contract Deploy is Script {
    /// @notice The main script entrypoint
    /// @return strategy The deployed implementation contract
    function run() external returns (NFTRewardStrategy strategy) {
        address alloProxy = 0xbb6B237a98D907b04682D8567F4a8d0b4b611a3b;
        address permit2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        strategy = new NFTRewardStrategy(alloProxy, "NFTRewardStrategy v1", ISignatureTransfer(permit2));
        vm.stopBroadcast();
    }
}
