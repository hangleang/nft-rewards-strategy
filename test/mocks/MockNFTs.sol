// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "charii-contract/ChariiNFTs.sol";

contract MockNFTs is ChariiNFTs {
    // 5% in default royalty, 1% in platform fee
    constructor(address owner) ChariiNFTs("ChariiNFTs", "CHARII", owner, owner, owner, 500, 100) { }
}
