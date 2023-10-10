// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "charii-contract/ChariiNFTs.sol";
contract MockNFTs is ChariiNFTs {
    constructor(address owner) ChariiNFTs("ChariiNFTs", "CHARII", owner, owner, 500) {}
}