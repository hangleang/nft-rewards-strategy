// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { Config } from "../Config.sol";

import { Allo } from "allo/contracts/core/Allo.sol";
import { Clone } from "allo/contracts/core/libraries/Clone.sol";
import { Metadata } from "allo/contracts/core/libraries/Metadata.sol";
import { DonationVotingMerkleDistributionBaseStrategy } from
    "allo/contracts/strategies/donation-voting-merkle-base/DonationVotingMerkleDistributionBaseStrategy.sol";

/// @notice This script is used to create pool with test data for the Allo V2 contracts
/// @dev Use this to run
///      'source .env' if you are using a .env file for your rpc-url
///      'forge script script/interaction/CreatePool.s.sol:CreatePool --rpc-url
/// https://goerli.infura.io/v3/$API_KEY_INFURA --broadcast -vvvv'
contract CreatePool is Script, Config {
    // Initialize the Allo Interface
    Allo allo = Allo(ALLO);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console.log("Allo Proxy ==> %s", ALLO);

        // Create A Pool using Donation Voting Merkle Distribution V1
        address[] memory allowedTokens = new address[](1);
        allowedTokens[0] = address(NATIVE);

        // struct InitializeData {
        //     bool useRegistryAnchor;
        //     bool metadataRequired;
        //     uint64 registrationStartTime;
        //     uint64 registrationEndTime;
        //     uint64 allocationStartTime;
        //     uint64 allocationEndTime;
        //     address[] allowedTokens;
        // }
        bytes memory encodedStrategyData = abi.encode(
            DonationVotingMerkleDistributionBaseStrategy.InitializeData(
                true,
                true,
                uint64(block.timestamp + 1 minutes),
                uint64(block.timestamp + 1 days),
                uint64(block.timestamp + 1 hours),
                uint64(block.timestamp + 1 weeks),
                allowedTokens
            ),
            address(NFT)
        );

        Metadata memory metadata = Metadata({ protocol: 1, pointer: METADATA_POINTER });

        address deployer = vm.addr(deployerPrivateKey);
        address[] memory managers = new address[](1);
        managers[0] = deployer;

        // manually clone the strategy contract
        address strategy = Clone.createClone(address(STRATEGY_IMPL), NONCE);
        console.log("Strategy cloned");
        console.log(strategy);

        uint256 initFunding = 0.01 ether;
        uint256 poolId = allo.createPoolWithCustomStrategy{ value: initFunding }(
            POOL_CREATOR_PROFILE_ID, strategy, encodedStrategyData, NATIVE, initFunding, metadata, managers
        );

        console.log("Pool created");
        console.log(poolId);

        vm.stopBroadcast();
    }
}
