// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Core Contracts
import {DonationVotingMerkleDistributionBaseStrategy} from
    "allo/contracts/strategies/donation-voting-merkle-base/DonationVotingMerkleDistributionBaseStrategy.sol";

// Interfaces
import {INFTs} from "./externals/INFTs.sol";
import {ISignatureTransfer} from "permit2/ISignatureTransfer.sol";

// External
import {ReentrancyGuardUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";

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

    struct ClaimNFT {
        address receiver;
        uint256 tokenId;
        uint256 quantity;
        bytes32[] proofs;
        uint256 deadline;
        bytes signature;
    }

    /// ===============================
    /// =========== Errors ============
    /// ===============================

    error INVALID_TOKEN_ID();

    /// ===============================
    /// =========== Events ============
    /// ===============================

    /// @notice Emitted when a recipient has claimed their allocated funds
    /// @param recipientId Id of the recipient
    /// @param recipientAddress Address of the recipient
    /// @param amount Amount of tokens claimed
    /// @param token Address of the token
    event Claimed(address indexed recipientId, address recipientAddress, uint256 amount, address indexed token);

    /// ===============================
    /// =========== Storage ===========
    /// ===============================

    /// @notice the NFTReward address
    address public nftAddress;

    /// @notice 'recipientId' => 'batchId'.
    mapping(address => uint256) public recipientIdToBatchId;

    /// @notice 'recipientId' => 'token' => 'amount'.
    mapping(address => mapping(address => uint256)) public claims;

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
        (InitializeStrategyData memory initStrategyData) = abi.decode(_data, (InitializeStrategyData));
        // address _nftAddress, InitializeData memory initializeData
        nftAddress = initStrategyData.nftAddress;
        __DonationVotingStrategy_init(_poolId, initStrategyData.initData);

        emit Initialized(_poolId, _data);
    }

    /// ===============================
    /// ========== External ===========
    /// ===============================

    /// @notice Claim allocated tokens for recipients.
    /// @dev Uses the merkle root to verify the claims. Allocation must have ended to claim.
    /// @param _claims Claims to be claimed
    function claim(Claim[] calldata _claims) external nonReentrant onlyAfterAllocation {
        uint256 claimsLength = _claims.length;

        // Loop through the claims
        for (uint256 i; i < claimsLength;) {
            Claim memory singleClaim = _claims[i];
            Recipient memory recipient = _recipients[singleClaim.recipientId];
            uint256 amount = claims[singleClaim.recipientId][singleClaim.token];

            // If the claim amount is zero this will revert
            if (amount == 0) {
                revert INVALID();
            }

            address recipientId = singleClaim.recipientId;
            address token = singleClaim.token;

            /// Delete the claim from the mapping
            delete claims[recipientId][token];

            // Transfer the tokens to the recipient
            _transferAmount(token, recipient.recipientAddress, amount);

            // Emit that the tokens have been claimed and sent to the recipient
            emit Claimed(recipientId, recipient.recipientAddress, amount, token);
            unchecked {
                i++;
            }
        }
    }

    function canAllocateTo(
        address _recipientId,
        uint256 _tokenId,
        uint256 _quantity,
        address _currency,
        uint256 _pricePerToken,
        bytes32[] calldata _proofs
    ) public view onlyActiveAllocation returns (bool canAllocate) {
        return _canAllocateTo(_recipientId, _tokenId, _quantity, _currency, _pricePerToken, _proofs);
    }

    /// ===============================
    /// ========== Internal ===========
    /// ===============================

    function _canAllocateTo(
        address _recipientId,
        uint256 _tokenId,
        uint256 _quantity,
        address _currency,
        uint256 _pricePerToken,
        bytes32[] calldata _proofs
    ) internal view returns (bool canAllocate) {
        uint256 batchId = recipientIdToBatchId[_recipientId];
        if (_tokenId > batchId) {
            return false;
        }

        try INFTs(nftAddress).verifyClaim(msg.sender, _tokenId, _quantity, _currency, _pricePerToken, _proofs) {
            return true;
        } catch {
            return false;
        }
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
            (recipientId, recipientAddress, metadata, amount, fee) =
                abi.decode(_data, (address, address, Metadata, uint256, uint96));
        } else {
            (recipientAddress, registryAnchor, metadata, amount, fee) =
                abi.decode(_data, (address, address, Metadata, uint256, uint96));

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

        // NOTE: the royalty info need to be packed encoded since we decode the data by bytes
        // `_sender` is used to be a royalty recipient, and also authorizer for the batch token
        bytes memory royaltyInfodata = abi.encodePacked(_sender, fee);
        uint256 batchId =
            INFTs(nftAddress).lazyMint(amount, string.concat(protocol, metadata.pointer, "/"), royaltyInfodata);
        recipientIdToBatchId[recipientId] = batchId;
    }

    /// @notice Before allocation hook to check whether caller is eligible for claim the NFT via `verifyClaim` on the NFTs contract
    /// @param _data The data to be decoded.
    /// @param _sender The sender of the allocation
    /// @custom:data (address recipientId, Permit2Data p2data, uint256 tokenId, uint256 qty, bytes32[] proofs)
    function _beforeAllocate(bytes memory _data, address _sender) internal view override {
        (address recipientId, Permit2Data memory p2Data, ClaimNFT memory claimNFTData) =
            abi.decode(_data, (address, Permit2Data, ClaimNFT));

        uint256 batchId = recipientIdToBatchId[recipientId];
        if (claimNFTData.tokenId > batchId) {
            revert INVALID_TOKEN_ID();
        }

        uint256 amount = p2Data.permit.permitted.amount;
        address token = p2Data.permit.permitted.token;
        uint256 price = amount / claimNFTData.quantity;

        // verify claim for amount of tokenId with given value
        INFTs(nftAddress).verifyClaim(_sender, claimNFTData.tokenId, claimNFTData.quantity, token, price, claimNFTData.proofs);
    }

    /// @notice After allocation hook to transfer & lock tokens within the contract, mint NFT back to the caller.
    /// @param _data The encoded recipientId, amount and token
    /// @param _sender The sender of the allocation
    /// @custom:data
    function _afterAllocate(bytes memory _data, address _sender) internal override {
        // Decode the '_data' to get the recipientId, amount and token
        (address recipientId, Permit2Data memory p2Data, ClaimNFT memory claimNFTData) =
            abi.decode(_data, (address, Permit2Data, ClaimNFT));

        // Get the token address
        address token = p2Data.permit.permitted.token;
        uint256 amount = p2Data.permit.permitted.amount;
        uint256 price = amount / claimNFTData.quantity;

        // Update the total payout amount for the claim
        claims[recipientId][token] += amount;

        // Form claim data to be attach with `claim` call
        INFTs.Claim memory claimData = INFTs.Claim({
            sender: _sender,
            receiver: claimNFTData.receiver,
            tokenId: claimNFTData.tokenId,
            quantity: claimNFTData.quantity,
            currency: token,
            pricePerToken: price,
            proofs: claimNFTData.proofs,
            deadline: claimNFTData.deadline
        });

        if (token == NATIVE) {
            if (msg.value < amount) {
                revert AMOUNT_MISMATCH();
            }

            INFTs(nftAddress).claim{value: msg.value}(claimData, claimNFTData.signature);
            SafeTransferLib.safeTransferETH(address(this), amount);
        } else {
            INFTs(nftAddress).claim(claimData, claimNFTData.signature);
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

    // function _registerRecipient(bytes memory _data, address _sender)
    //     internal
    //     override
    //     onlyActiveRegistration
    //     returns (address)
    // {
    //     (address recipientId, address recipientAddress, Metadata memory metadata) =
    //         abi.decode(_data, (address, address, Metadata));
    //     bytes memory registerData = abi.encode(recipientId, recipientAddress, metadata);

    //     return super._registerRecipient(registerData, _sender);
    // }
 
    // function _allocate(bytes memory _data, address _sender) internal override onlyActiveAllocation nonReentrant {
    //     (address recipientId, Permit2Data memory p2Data) = abi.decode(_data, (address, Permit2Data));
    //     bytes memory allocationData = abi.encode(recipientId, p2Data);

    //     super._allocate(allocationData, _sender);
    // }
}
