// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract Config {
    address public constant ALLO = 0xbb6B237a98D907b04682D8567F4a8d0b4b611a3b;
    address public constant REGISTRY = 0xBC23124Ed2655A1579291f7ADDE581fF18327D41;
    address public constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address public constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // contract-specific configs
    address public constant NFT = 0x775986Df55900AF1C572eCB7fB9E03387DdbF8D2;
    string public constant METADATA_POINTER = "bafybeif43xtcb7zfd6lx7rfq42wjvpkbqgoo7qxrczbj4j4iwfl5aaqv2q";
    address public constant STRATEGY_IMPL = 0x67FD4c6fD422805E162cdA354ACcE9Ce32A6153B;

    // NOTE: increase the `NONCE` before create new pool
    // TODO: update this when we deploy new strategy/strategies
    uint256 public constant NONCE = 1;
    address public constant STRATEGY = 0xCf1EBf2af339bDDA6214f484cb11831B81B40d1B;
    uint256 public constant POOL_ID = 20;

    // pool creator profile ID & anchor address
    bytes32 public constant POOL_CREATOR_PROFILE_ID = 0x17239d14834b393602080aa284d039185c79f5ccc6e7abd1afdc37cf8c97f374;
    address public constant POOL_ANCHOR_ID = 0x363CEE91d57154311A374a31b9b0f24e508F33ae;
    address public constant POOL_MANAGER = 0x36615Cf349d7F6344891B1e7CA7C72883F5dc049;

    // first recipient profile ID & anchor address
    bytes32 public constant RECIPIENT_1_PROFILE_ID = 0x98b5ae29bd2a6c36242ce4511ca01f6820bdc3af2b5e16731619dc66485fa518;
    address public constant RECIPIENT_1_ANCHOR_ID = 0x4Ad1AbB68BE7516EEC21963C9CC03D3D1D837E39;
    address public constant RECIPIENT_1_MEMBER_1 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public constant RECIPIENT_1_MEMBER_2 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;

    // second recipient profile ID & anchor address
    bytes32 public constant RECIPIENT_2_PROFILE_ID = 0x9edcb4e6ca3f0b71640c69356783b7e43103b2935e2109614515c1b404d876ba;
    address public constant RECIPIENT_2_ANCHOR_ID = 0xe5ddA83918BCc5b59bD7c1347Bf9f4d32E147f26;
    address public constant RECIPIENT_2_MEMBER_1 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    address public constant RECIPIENT_2_MEMBER_2 = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;

    uint256 public constant RECIPIENT_1_TOKEN_ID = 1;
    uint256 public constant RECIPIENT_1_NFT_AMOUNT = 10;
    uint256 public constant RECIPIENT_2_TOKEN_ID = 11;
    uint256 public constant RECIPIENT_2_NFT_AMOUNT = 100;
    uint256 public constant TOKEN_PRICE = 0.001 ether;
}
