// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { Config } from "../Config.sol";

import { Allo } from "allo/contracts/core/Allo.sol";
import { Metadata } from "allo/contracts/core/libraries/Metadata.sol";

/// @notice This script is used to register recipient with test data for the Allo V2 contracts
/// @dev Use this to run
///      'source .env' if you are using a .env file for your rpc-url
///      'forge script script/interaction/RegisterRecipient.s.sol:RegisterRecipient --rpc-url
/// https://goerli.infura.io/v3/$API_KEY_INFURA --broadcast -vvvv'
contract RegisterRecipient is Script, Config {
    // Initialize the Allo Interface
    Allo allo = Allo(ALLO);

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);

        console.log("Allo Proxy ==> %s", ALLO);

        // Register 2 recipients
        Metadata memory recipientMetadata1 = Metadata({ protocol: 1, pointer: METADATA_POINTER });
        Metadata memory recipientMetadata2 = Metadata({ protocol: 1, pointer: METADATA_POINTER });
        Metadata memory recipientMetadata3 = Metadata({ protocol: 1, pointer: METADATA_POINTER });

        // data should be encoded: (recipientId, recipientAddress, metadata, nftAmount, feeBps) this strategy uses the
        // anchor
        bytes memory recipientData1 = abi.encode(
            RECIPIENT_1_ANCHOR_ID, RECIPIENT_1_MEMBER_1, recipientMetadata1, RECIPIENT_1_NFT_AMOUNT, uint96(500)
        );
        bytes memory recipientData2 = abi.encode(
            RECIPIENT_2_ANCHOR_ID, RECIPIENT_2_MEMBER_1, recipientMetadata2, RECIPIENT_2_NFT_AMOUNT, uint96(100)
        );
        bytes memory recipientData3 = abi.encode(POOL_ANCHOR_ID, POOL_MANAGER, recipientMetadata3, 1, uint96(9000));

        // register recipient
        allo.registerRecipient(POOL_ID, recipientData1);
        allo.registerRecipient(POOL_ID, recipientData2);
        allo.registerRecipient(POOL_ID, recipientData3);

        vm.stopBroadcast();
    }
}
