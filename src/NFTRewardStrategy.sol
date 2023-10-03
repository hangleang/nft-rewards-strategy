// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Core Contracts
import {DonationVotingMerkleDistributionBaseStrategy} from "allo/contracts/strategies/donation-voting-merkle-base/DonationVotingMerkleDistributionBaseStrategy.sol";

// Interfaces
import {INFTs} from "./externals/INFTs.sol";
import {ISignatureTransfer} from "permit2/ISignatureTransfer.sol";

// External
import {ReentrancyGuardUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";

// Libraries
import {Metadata} from "allo/contracts/core/libraries/Metadata.sol";
import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";

contract NFTRewardStrategy is DonationVotingMerkleDistributionBaseStrategy, ReentrancyGuardUpgradeable {
    struct InitializeStrategyData {
        address nftAddress;
        InitializeData initData;
    }

    /// @notice Stores the details of the allocations to claim.
    struct Claim {
        address recipientId;
        address token;
    }

    /// ===============================
    /// ========== Events =============
    /// ===============================

    /// @notice Emitted when a recipient has claimed their allocated funds
    /// @param recipientId Id of the recipient
    /// @param recipientAddress Address of the recipient
    /// @param amount Amount of tokens claimed
    /// @param token Address of the token
    event Claimed(address indexed recipientId, address recipientAddress, uint256 amount, address indexed token);

    /// ===============================
    /// ========= Storage ==========
    /// ===============================

    /// @notice the NFTReward address
    address public nftAddress;

    /// @notice 'recipientId' => 'batchId'.
    mapping (address => uint256) public recipientIdToBatchId;

    /// @notice 'recipientId' => 'token' => 'amount'.
    mapping (address => mapping(address => uint256)) public claims;

    /// ===============================
    /// ========= Initialize ==========
    /// ===============================

    constructor(address _allo, string memory _name, ISignatureTransfer _permit2) 
        DonationVotingMerkleDistributionBaseStrategy(_allo, _name, _permit2) 
    {}

    /// @notice Initializes the strategy
    /// @dev This will revert if the strategy is already initialized and 'msg.sender' is not the 'Allo' contract.
    /// @param _poolId The 'poolId' to initialize
    /// @param _data The data to be decoded to initialize the strategy
    /// @custom:data  address _nftAddress, InitializeData(bool _useRegistryAnchor, bool _metadataRequired, uint64 _registrationStartTime,
    ///               uint64 _registrationEndTime, uint64 _allocationStartTime, uint64 _allocationEndTime,
    ///               address[] memory _allowedTokens)
    function initialize(uint256 _poolId, bytes memory _data) external virtual override onlyAllo {
        (address _nftAddress, InitializeData memory initializeData) = abi.decode(_data, (address, InitializeData));
        nftAddress = _nftAddress;
        __DonationVotingStrategy_init(_poolId, initializeData);

        emit Initialized(_poolId, _data);
    }

    /// ===============================
    /// ============ Hooks ============
    /// ===============================

    /// @notice After recipient registration hook to lazy mint amount of NFT with metadata and royalty info for the batch NFT
    /// @param _data The data to be decoded.
    /// @custom:data if 'useRegistryAnchor' is 'true' (address recipientId, address recipientAddress, Metadata metadata, uint256 amount, uint96 fee)
    /// @custom:data if 'useRegistryAnchor' is 'false' (address recipientAddress, address registryAnchor, Metadata metadata, uint256 amount, uint96 fee)
    /// @param _sender The sender of the transaction
    function _afterRegisterRecipient(bytes memory _data, address _sender) internal override {
        // bool isUsingRegistryAnchor;
        address recipientAddress;
        address registryAnchor;
        address recipientId;
        Metadata memory metadata;
        uint256 amount;
        uint96 fee;

        // decode data custom to this strategy
        if (useRegistryAnchor) {
            (recipientId, recipientAddress, metadata, amount, fee) = abi.decode(_data, (address, address, Metadata, uint256, uint96));
        } else {
            (recipientAddress, registryAnchor, metadata, amount, fee) = abi.decode(_data, (address, address, Metadata, uint256, uint96));

            // Set this to 'true' if the registry anchor is not the zero address
            bool isUsingRegistryAnchor = registryAnchor != address(0);

            // If using the 'registryAnchor' we set the 'recipientId' to the 'registryAnchor', otherwise we set it to the 'msg.sender'
            recipientId = isUsingRegistryAnchor ? registryAnchor : _sender;
        }

        // If the metadata is required and the metadata is invalid this will revert
        if (metadataRequired && (bytes(metadata.pointer).length == 0 || metadata.protocol == 0)) {
            revert INVALID_METADATA();
        }

        string memory protocol;
        if (metadata.protocol == 1) {
            protocol = "ipfs://";
        }

        bytes memory data = abi.encodePacked(_sender, fee);
        uint256 batchId = INFTs(nftAddress).lazyMint(amount, string.concat(protocol, metadata.pointer, "/"), data);
        recipientIdToBatchId[recipientId] = batchId;
    }

    /// @notice Before allocation hook to check whether caller is eligible for claim the NFT via `verifyClaim` on the NFTs contract
    /// @param _data The data to be decoded.
    /// @param _sender The sender of the allocation
    /// @custom:data (address recipientId, Permit2Data p2data, uint256 tokenId, uint256 qty, bytes32[] proofs)
    function _beforeAllocate(bytes memory _data, address _sender) internal override {
        (, Permit2Data memory p2Data, uint256 tokenId, uint256 qty, bytes32[] memory proofs) = abi.decode(_data, (address, Permit2Data, uint256, uint256, bytes32[]));
        uint256 amount = p2Data.permit.permitted.amount;
        address token = p2Data.permit.permitted.token;
        uint256 price = amount / qty;

        // verify claim for amount of tokenId
        // INFTs(nftAddress).verifyClaim(tokenId, _sender, qty, token, price, proofs);
        if (token == NATIVE) {
            INFTs(nftAddress).claim{value: msg.value}(_sender, tokenId, qty, proofs, bytes(""));
        } else {
            INFTs(nftAddress).claim(_sender, tokenId, qty, token, price, proofs, bytes(""));
        }
    }

    /// @notice After allocation hook to transfer & lock tokens within the contract, mint NFT back to the caller.
    /// @param _data The encoded recipientId, amount and token
    /// @param _sender The sender of the allocation
    /// @custom:data 
    function _afterAllocate(bytes memory _data, address _sender) internal override {
        // Decode the '_data' to get the recipientId, amount and token
        (address recipientId, Permit2Data memory p2Data) = abi.decode(_data, (address, Permit2Data));

        // Get the token address
        address token = p2Data.permit.permitted.token;
        uint256 amount = p2Data.permit.permitted.amount;

        // Update the total payout amount for the claim
        claims[recipientId][token] += amount;

        if (token == NATIVE) {
            if (msg.value < amount) {
                revert AMOUNT_MISMATCH();
            }
            SafeTransferLib.safeTransferETH(address(this), amount);
        } else {
            PERMIT2.permitTransferFrom(
                // The permit message.
                p2Data.permit,
                // The transfer recipient and amount.
                ISignatureTransfer.SignatureTransferDetails({to: address(this), requestedAmount: amount}),
                // Owner of the tokens and signer of the message.
                _sender,
                // The packed signature that was the result of signing
                // the EIP712 hash of `_permit`.
                p2Data.signature
            );
        }
    }

    /// ===============================
    /// ========== Override ===========
    /// ===============================

    function _registerRecipient(bytes memory _data, address _sender) internal override onlyActiveRegistration returns (address) {
        (address recipientId, address recipientAddress, Metadata memory metadata, ) = abi.decode(_data, (address, address, Metadata, bytes));
        bytes memory registerData = abi.encode(recipientId, recipientAddress, metadata);

        return super._registerRecipient(registerData, _sender);
    }

    function _allocate(bytes memory _data, address _sender) internal override onlyActiveAllocation {
        (address recipientId, Permit2Data memory p2Data, ) = abi.decode(_data, (address, Permit2Data, bytes));
        bytes memory allocationData = abi.encode(recipientId, p2Data);

        super._allocate(allocationData, _sender);
    }
}