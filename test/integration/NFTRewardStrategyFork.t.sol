// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";

contract NFTRewardStrategyFork is Test {
    // the identifiers of the forks
    uint256 opGoerliFork;
    uint256 pgnSepoliaFork;
    uint256 celoAlfajoresFork;

    // create 3 _different_ forks during setup
    function setUp() public {
        opGoerliFork = vm.createFork(vm.envString("OP_GOERLI_RPC_URL"));
        pgnSepoliaFork = vm.createFork(vm.envString("PGN_SEPOLIA_RPC_URL"));
        celoAlfajoresFork = vm.createFork(vm.envString("CELO_ALFAJORES_RPC_URL"));
    }

    // demonstrate fork ids are unique
    function testForkIdDiffer() public view {
        assert(opGoerliFork != pgnSepoliaFork);
    }

    // select a specific fork
    function testCanSelectFork() public {
        // select the fork
        vm.selectFork(celoAlfajoresFork);
        assertEq(vm.activeFork(), celoAlfajoresFork);

        // from here on data is fetched from the `mainnetFork` if the EVM requests it and written to the storage of `mainnetFork`
    }

    // manage multiple forks in the same test
    function testCanSwitchForks() public {
        vm.selectFork(opGoerliFork);
        assertEq(vm.activeFork(), opGoerliFork);

        vm.selectFork(pgnSepoliaFork);
        assertEq(vm.activeFork(), pgnSepoliaFork);
    }

    // forks can be created at all times
    function testCanCreateAndSelectForkInOneStep() public {
        // creates a new fork and also selects it
        uint256 anotherFork = vm.createSelectFork(vm.envString("OP_GOERLI_RPC_URL"));
        assertEq(vm.activeFork(), anotherFork);
    }

    // set `block.number` of a fork
    function testCanSetForkBlockNumber() public {
        vm.selectFork(opGoerliFork);
        vm.rollFork(1_337_000);

        assertEq(block.number, 1_337_000);
    }
}