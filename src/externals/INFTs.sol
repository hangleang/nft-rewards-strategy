// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface INFTs {
    struct Claim {
        address sender;
        address receiver;
        uint256 tokenId;
        uint256 quantity;
        address currency;
        uint256 pricePerToken;
        bytes32[] proofs;
        uint256 deadline;
    }

    function lazyMint(uint256 amount, string calldata baseURIForTokens, bytes calldata extraData)
        external
        returns (uint256 batchId);

    function authorizerForBatch(uint256 _batchId) external view returns (address);

    function saleRecipientForBatch(uint256 _batchId) external view returns (address);

    function claim(Claim calldata claim, bytes calldata signature) external payable;

    function verifyClaim(
        address claimer,
        uint256 tokenId,
        uint256 quantity,
        address currency,
        uint256 pricePerToken,
        bytes32[] calldata proofs
    )
        external
        view;

    function getSupplyClaimedByWallet(uint256 _tokenId, address _claimer) external view returns (uint256);

    function getActiveClaimConditionId(uint256 _tokenId) external view returns (bytes32);
}
