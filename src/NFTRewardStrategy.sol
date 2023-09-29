// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

import {DonationVotingMerkleDistributionBaseStrategy} from "allo/contracts/strategies/donation-voting-merkle-base/DonationVotingMerkleDistributionBaseStrategy.sol";
import {ReentrancyGuardUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";

contract NFTRewardStrategy is DonationVotingMerkleDistributionBaseStrategy, ReentrancyGuardUpgradeable {
    
}