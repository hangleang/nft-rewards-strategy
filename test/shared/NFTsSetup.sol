// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import {Accounts} from "allo/test/foundry/shared/Accounts.sol";
import {INFTs} from "src/externals/INFTs.sol";

contract NFTsSetup is Test, Accounts {
    INFTs internal _nfts;

    function __AlloSetup(address _registry) internal {
        vm.startPrank(allo_owner());
        // _nfts = new INFTs();

        // _allo_.initialize(
        //     _registry, // _registry
        //     allo_treasury(), // _treasury
        //     1e16, // _percentFee
        //     0 // _baseFee
        // );
        vm.stopPrank();
    }

    function nfts() public view returns (INFTs) {
        return _nfts;
    }
}