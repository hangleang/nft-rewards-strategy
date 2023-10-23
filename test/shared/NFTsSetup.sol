// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import { Accounts } from "allo/test/foundry/shared/Accounts.sol";
// import {INFTs} from "src/externals/INFTs.sol";
import { MockNFTs } from "../mocks/MockNFTs.sol";

contract NFTsSetup is Test, Accounts {
    MockNFTs internal _nfts;

    function __NFTsSetup(address owner) internal {
        vm.startPrank(owner);
        _nfts = new MockNFTs(owner);
        vm.stopPrank();
    }

    function nfts() public view returns (MockNFTs) {
        return _nfts;
    }

    function lazyMintAmount() public pure returns (uint256) {
        return 123;
    }

    function defaultRoyaltyFee() public pure returns (uint96) {
        return 500;
    }
}
