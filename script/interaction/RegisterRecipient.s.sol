// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { Config } from "../Config.sol";

import { Allo } from "allo/contracts/core/Allo.sol";
import { IRegistry } from "allo/contracts/core/interfaces/IRegistry.sol";
import { Metadata } from "allo/contracts/core/libraries/Metadata.sol";
import { NFTRewardStrategy } from "src/NFTRewardStrategy.sol";

import { DonationVotingMerkleDistributionBaseStrategy } from
    "allo/contracts/strategies/donation-voting-merkle-base/DonationVotingMerkleDistributionBaseStrategy.sol";

/// @notice This script is used to register recipient with test data for the Allo V2 contracts
/// @dev Use this to run
///      'source .env' if you are using a .env file for your rpc-url
///      'forge script script/interaction/RegisterRecipient.s.sol:RegisterRecipient --rpc-url https://goerli.infura.io/v3/$API_KEY_INFURA --broadcast -vvvv'
contract RegisterRecipient is Script, Config {
    // Initialize the Allo Interface
    Allo allo = Allo(ALLO);

    // Initialize Registry Interface
    IRegistry registry = IRegistry(REGISTRY);

    // Initialize the Strategy contract
    NFTRewardStrategy strategy = NFTRewardStrategy(payable(address(STRATEGY)));

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);

        // IRegistry.Profile memory profile = registry.getProfileById(RECIPIENT_PROFILE_ID);

        console.log("Allo Proxy ==> %s", ALLO);

        // Register 2 recipients
        Metadata memory recipientMetadata1 = Metadata({protocol: 1, pointer: METADATA_POINTER});
        Metadata memory recipientMetadata2 = Metadata({protocol: 1, pointer: METADATA_POINTER});

        // data should be encoded: (recipientId, recipientAddress, metadata, nftAmount, feeBps) this strategy uses the anchor
        bytes memory recipientData1 = abi.encode(RECIPIENT_1_ANCHOR_ID, RECIPIENT_1_MEMBER_1, recipientMetadata1, RECIPIENT_1_NFT_AMOUNT, uint96(500));
        bytes memory recipientData2 = abi.encode(RECIPIENT_2_ANCHOR_ID, RECIPIENT_2_MEMBER_1, recipientMetadata2, RECIPIENT_2_NFT_AMOUNT, uint96(9000));

        // register recipient
        allo.registerRecipient(POOL_ID, recipientData1);
        allo.registerRecipient(POOL_ID, recipientData2);

        DonationVotingMerkleDistributionBaseStrategy.ApplicationStatus[] memory statuses =
            new DonationVotingMerkleDistributionBaseStrategy.ApplicationStatus[](2);

        // Approve 1 recipient
        statuses[0] = DonationVotingMerkleDistributionBaseStrategy.ApplicationStatus({index: 0, statusRow: 1});

        // Reject 1 recipient
        statuses[1] = DonationVotingMerkleDistributionBaseStrategy.ApplicationStatus({index: 1, statusRow: 2});

        strategy.reviewRecipients(statuses);

        vm.stopBroadcast();
    }
}