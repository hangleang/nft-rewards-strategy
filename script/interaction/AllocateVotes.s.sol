// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { Config } from "../Config.sol";

import { Allo } from "allo/contracts/core/Allo.sol";
import { ISignatureTransfer } from "permit2/ISignatureTransfer.sol";
import { IClaimEligibility } from "charii-contract/interfaces/IClaimEligibility.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import { DonationVotingMerkleDistributionBaseStrategy } from
    "allo/contracts/strategies/donation-voting-merkle-base/DonationVotingMerkleDistributionBaseStrategy.sol";
import { NFTRewardStrategy } from "src/NFTRewardStrategy.sol";

/// @notice This script is used to allocate vote to recipient with test data for the Allo V2 contracts
/// @dev Use this to run
///      'source .env' if you are using a .env file for your rpc-url
///      'forge script script/interaction/AllocateVotes.s.sol:AllocateVotes --rpc-url https://goerli.infura.io/v3/$API_KEY_INFURA --broadcast -vvvv'
contract AllocateVotes is Script, Config {
    // Initialize the Allo Interface
    Allo allo = Allo(ALLO);

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);
        address sender = vm.addr(privateKey);

        console.log("Allo Proxy ==> %s", ALLO);

        // init permit transfer & sign claim NFTs
        uint256 pricePerToken = 0.001 ether;
        uint256 qty = 1;
        uint256 deadline = block.timestamp + 10 minutes;
        ISignatureTransfer.TokenPermissions memory tokenPermissions =
            ISignatureTransfer.TokenPermissions({token: address(NATIVE), amount: qty * pricePerToken});
        ISignatureTransfer.PermitTransferFrom memory permit =
            ISignatureTransfer.PermitTransferFrom({permitted: tokenPermissions, nonce: 0, deadline: deadline});
        DonationVotingMerkleDistributionBaseStrategy.Permit2Data memory permit2Data =
        DonationVotingMerkleDistributionBaseStrategy.Permit2Data({
            permit: permit,
            signature: ""
            // signature: abi.encodePacked(
            //     uint8(1), uint8(27), address(0x1fD06f088c720bA3b7a3634a8F021Fdd485DcA42), uint8(0), uint8(0)
            //     )
        });

        IClaimEligibility.Claim memory claimData = _getClaimStruct(
            sender, sender, RECIPIENT_1_TOKEN_ID, qty, NATIVE, pricePerToken, new bytes32[](0), deadline
        );
        bytes32 claimHash = _getClaimHash(claimData);
        NFTRewardStrategy.ClaimNFT memory claimNFTFromRecipient1 = NFTRewardStrategy.ClaimNFT({
            receiver: claimData.receiver,
            tokenId: claimData.tokenId,
            quantity: claimData.quantity,
            proofs: claimData.proofs,
            deadline: claimData.deadline,
            signature: _generateEIP712Signature(claimHash, privateKey)
        });
        
        // encode data for allocations
        bytes[] memory allocateData = new bytes[](1);
        allocateData[0] = abi.encode(RECIPIENT_1_ANCHOR_ID, permit2Data, claimNFTFromRecipient1);
        // allocateData[1] = abi.encode(POOL_ANCHOR_ID, permit2Data);
        uint256[] memory poolIds = new uint256[](1);
        poolIds[0] = POOL_ID;
        // poolIds[1] = POOL_ID;

        // call batchAllocate with those allocations
        allo.allocate{value: qty * pricePerToken}(poolIds[0], allocateData[0]);

        vm.stopBroadcast();
    }

    function _getClaimStruct(
        address sender,
        address receiver,
        uint256 tokenId,
        uint256 quantity,
        address currency,
        uint256 pricePerToken,
        bytes32[] memory proofs,
        uint256 deadline
    )
        internal
        view
        returns (IClaimEligibility.Claim memory claimData)
    {
        if (deadline == 0) {
            deadline = block.timestamp;
        }

        return IClaimEligibility.Claim({
            sender: sender,
            receiver: receiver,
            tokenId: tokenId,
            quantity: quantity,
            currency: currency,
            pricePerToken: pricePerToken,
            proofs: proofs,
            deadline: deadline
        });
    }

    function _getClaimHash(IClaimEligibility.Claim memory claimData) internal pure returns (bytes32 structHash) {
        return keccak256(
            abi.encode(
                0xab87cbadbc76f60ec344640b7ab0c6516a7a051c1823c727a720b74862452841,
                claimData.sender,
                claimData.receiver,
                claimData.tokenId,
                claimData.quantity,
                claimData.currency,
                claimData.pricePerToken,
                keccak256(abi.encodePacked(claimData.proofs)),
                claimData.deadline
            )
        );
    }

    function _generateEIP712Signature(
        bytes32 claimHash,
        uint256 claimerPK
    )
        internal
        view
        returns (bytes memory signature)
    {
        bytes32 digest = _hashTypedDataV4(NFT, "ChariiNFTs", "1.0.0", claimHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(claimerPK, digest);
        signature = abi.encodePacked(r, s, v);
    }

    function _hashTypedDataV4(
        address target,
        string memory name,
        string memory version,
        bytes32 structHash
    )
        internal
        view
        virtual
        returns (bytes32)
    {
        bytes32 hashedName = keccak256(bytes(name));
        bytes32 hashedVersion = keccak256(bytes(version));
        bytes32 typeHash =
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
        bytes32 domainSeperator = keccak256(abi.encode(typeHash, hashedName, hashedVersion, block.chainid, target));
        return ECDSA.toTypedDataHash(domainSeperator, structHash);
    }
}