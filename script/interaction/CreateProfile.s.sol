// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { Config } from "../Config.sol";

import { IRegistry } from "allo/contracts/core/interfaces/IRegistry.sol";
import { Metadata } from "allo/contracts/core/libraries/Metadata.sol";

/// @notice This script is used to create profile with test data for the Allo V2 contracts
/// @dev Use this to run
///      'source .env' if you are using a .env file for your rpc-url
///      'forge script script/interaction/CreateProfile.s.sol:CreateProfile --rpc-url
/// https://goerli.infura.io/v3/$API_KEY_INFURA --broadcast -vvvv'
contract CreateProfile is Script, Config {
    // Adding a nonce for reusability
    uint256 nonce = block.timestamp;

    // Initialize Registry Interface
    IRegistry registry = IRegistry(REGISTRY);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console.log("Registry ==> %s", REGISTRY);

        // Prepare the members array
        address deployer = vm.addr(deployerPrivateKey);
        address[] memory members = new address[](2);

        // create profile for recipient 1
        // members[0] = RECIPIENT_1_MEMBER_1;
        // members[1] = RECIPIENT_1_MEMBER_2;

        // create profile for recipient 2
        members[0] = RECIPIENT_2_MEMBER_1;
        members[1] = RECIPIENT_2_MEMBER_2;

        // create profile for pool managers
        members[0] = address(deployer);
        members[1] = POOL_MANAGER;

        // Create a profile
        bytes32 profileId = registry.createProfile(
            nonce++, "Test Profile", Metadata({ protocol: 1, pointer: METADATA_POINTER }), deployer, members
        );
        IRegistry.Profile memory profile = registry.getProfileById(profileId);
        console.log("Profile created");
        console.logBytes32(profileId);
        console.log("Anchor ==> %s", profile.anchor);

        vm.stopBroadcast();
    }
}
