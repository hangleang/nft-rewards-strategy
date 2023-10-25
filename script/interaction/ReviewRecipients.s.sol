// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { Config } from "../Config.sol";

import { NFTRewardStrategy } from "src/NFTRewardStrategy.sol";

import { DonationVotingMerkleDistributionBaseStrategy } from
    "allo/contracts/strategies/donation-voting-merkle-base/DonationVotingMerkleDistributionBaseStrategy.sol";

/// @notice This script is used to review recipients with test data for the Allo V2 contracts
/// @dev Use this to run
///      'source .env' if you are using a .env file for your rpc-url
///      'forge script script/interaction/ReviewRecipients.s.sol:ReviewRecipients --rpc-url
/// https://goerli.infura.io/v3/$API_KEY_INFURA --broadcast -vvvv'
contract ReviewRecipients is Script, Config {
    // Initialize the Strategy contract
    NFTRewardStrategy strategy = NFTRewardStrategy(payable(address(STRATEGY)));

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);
        console.log("Strategy proxy ==> %s", address(strategy));

        DonationVotingMerkleDistributionBaseStrategy.ApplicationStatus[] memory statuses =
            new DonationVotingMerkleDistributionBaseStrategy.ApplicationStatus[](3);

        // Approve the first 2 recipient
        statuses[0] = __buildStatusRow(0, 2);
        statuses[1] = __buildStatusRow(1, 2);
        // Reject the last recipient
        statuses[2] = __buildStatusRow(2, 3);

        strategy.reviewRecipients(statuses);

        vm.stopBroadcast();
    }

    function __buildStatusRow(
        uint256 _recipientIndex,
        uint256 _status
    )
        internal
        pure
        returns (DonationVotingMerkleDistributionBaseStrategy.ApplicationStatus memory applicationStatus)
    {
        uint256 colIndex = (_recipientIndex % 64) * 4;
        uint256 currentRow = 0;

        uint256 newRow = currentRow & ~(15 << colIndex);
        uint256 statusRow = newRow | (_status << colIndex);

        applicationStatus = DonationVotingMerkleDistributionBaseStrategy.ApplicationStatus({
            index: _recipientIndex,
            statusRow: statusRow
        });
    }
}
