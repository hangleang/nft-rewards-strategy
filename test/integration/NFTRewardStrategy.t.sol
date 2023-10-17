// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// std lib
import {Test} from "forge-std/Test.sol";

// External lib
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IClaimEligibility} from "charii-contract/interfaces/IClaimEligibility.sol";

// Core contracts
import {IAllo} from "allo/contracts/core/interfaces/IAllo.sol";
import {IRegistry} from "allo/contracts/core/interfaces/IRegistry.sol";
import {IStrategy} from "allo/contracts/core/interfaces/IStrategy.sol";
import {ISignatureTransfer} from "permit2/ISignatureTransfer.sol";
import {Metadata} from "allo/contracts/core/libraries/Metadata.sol";
import {DonationVotingMerkleDistributionBaseStrategy} from
    "allo/contracts/strategies/donation-voting-merkle-base/DonationVotingMerkleDistributionBaseStrategy.sol";

// Test libraries
import {PermitSignature} from "allo/lib/permit2/test/utils/PermitSignature.sol";
import {DonationVotingMerkleDistributionBaseMockTest} from "allo/test/foundry/strategies/DonationVotingMerkleDistributionBase.t.sol";

// Internal contracts
import {NFTRewardStrategy} from "src/NFTRewardStrategy.sol";
import {INFTs} from "src/externals/INFTs.sol";
import {NFTsSetup} from "../shared/NFTsSetup.sol";

// Mock contracts
import {MockERC20} from "allo/test/utils/MockERC20.sol";
import {DonationVotingMerkleDistributionBaseMock} from "allo/test/utils/DonationVotingMerkleDistributionBaseMock.sol";
import {Permit2} from "allo/test/utils/Permit2Mock.sol";

import {console2 as console} from "forge-std/console2.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

// opGoerliFork = vm.createFork(vm.envString("OP_GOERLI_RPC_URL"));
// pgnSepoliaFork = vm.createFork(vm.envString("PGN_SEPOLIA_RPC_URL"));
// celoAlfajoresFork = vm.createFork(vm.envString("CELO_ALFAJORES_RPC_URL"));

// allo = IAllo(0xfF65C1D4432D23C45b0730DaeCd03b6B92cd074a);
// registry = IRegistry(0xC5CcdcF78a8a789Ef0DfEcD6f3126D3b91D48fe5);

contract NFTRewardStrategyTest is DonationVotingMerkleDistributionBaseMockTest, NFTsSetup {
    using Strings for uint256;

    NFTRewardStrategy internal _strategy;
    uint256 internal _initAmount;

    // explicit set privateKey
    uint256 internal bobPK;
    address internal bob;

    function _deployStrategy() internal override returns (address payable) {
        _strategy = new NFTRewardStrategy(
            address(allo()),
            "DonationVotingMerkleDistributionBaseMock", // leave this sample here to bypass testcase
            permit2
        );
        return payable(address(_strategy));
    }

    function setUp() public virtual override {
        bobPK = 0xB0B;
        bob = vm.addr(bobPK);
        vm.deal(bob, 1000 ether);

        __RegistrySetupFull();
        __AlloSetup(address(registry()));
        __NFTsSetup(allo_owner());

        permit2 = ISignatureTransfer(address(new Permit2()));

        registrationStartTime = uint64(block.timestamp + 10);
        registrationEndTime = uint64(block.timestamp + 300);
        allocationStartTime = uint64(block.timestamp + 301);
        allocationEndTime = uint64(block.timestamp + 600);

        useRegistryAnchor = true;
        metadataRequired = true;

        poolMetadata = Metadata({protocol: 1, pointer: "PoolMetadata"});

        strategy = DonationVotingMerkleDistributionBaseMock(_deployStrategy());
        mockERC20 = new MockERC20();

        mockERC20.mint(address(this), 1_000_000 * 1e18);

        allowedTokens = new address[](2);
        allowedTokens[0] = NATIVE;
        allowedTokens[1] = address(mockERC20);

        vm.prank(allo_owner());
        allo().updatePercentFee(0);

        _initAmount = 1 ether;
        vm.deal(pool_admin(), _initAmount);
        vm.prank(pool_admin());
        poolId = allo().createPoolWithCustomStrategy{value: _initAmount}(
            poolProfile_id(),
            address(_strategy),
            abi.encode(
                NFTRewardStrategy.InitializeStrategyData(
                    address(_nfts),
                    DonationVotingMerkleDistributionBaseStrategy.InitializeData(
                        useRegistryAnchor,
                        metadataRequired,
                        registrationStartTime,
                        registrationEndTime,
                        allocationStartTime,
                        allocationEndTime,
                        allowedTokens
                    )
                )
            ),
            NATIVE,
            _initAmount,
            poolMetadata,
            pool_managers()
        );
    }

    function testRevert_initializeStrategy_ALREADY_INITIALIZED() public {
        vm.expectRevert(ALREADY_INITIALIZED.selector);

        vm.prank(address(allo()));
        strategy.initialize(
            poolId,
            abi.encode(
                NFTRewardStrategy.InitializeStrategyData(
                    address(_nfts),
                    DonationVotingMerkleDistributionBaseStrategy.InitializeData(
                        useRegistryAnchor,
                        metadataRequired,
                        registrationStartTime,
                        registrationEndTime,
                        allocationStartTime,
                        allocationEndTime,
                        allowedTokens
                    )
                )
            )
        );
    }

    /** 
     * ===============================
     * ========== Register ===========
     * ===============================
    **/

    function test_registerRecipientWithLazyMint() public {
        uint256 startTokenId = _nfts.tokenId();
        uint256 amount = lazyMintAmount();
        uint256 expectedBatchId = startTokenId + amount;
        address recipientId = __register_recipient_with_lazyMint(amount);

        // check strategy states
        __checkRecipientInfo(
            recipientId,
            true,
            recipientAddress(),
            1,
            "basecidhash",
            expectedBatchId,
            IStrategy.Status.Pending
        );

        // check NFTs states
        __checkBatchNFT(
            expectedBatchId, 
            startTokenId, 
            expectedBatchId, 
            string.concat("ipfs://basecidhash/", startTokenId.toString()),
            address(_strategy),
            profile1_member1(),
            profile1_member1(),
            defaultRoyaltyFee()
        );
    }

    function test_appealRejectedApplication() public {
        uint256 amount = lazyMintAmount();
        address recipientId = __register_recipient_with_lazyMint2(amount);

        address[] memory recipientIds = new address[](1);
        recipientIds[0] = recipientId;
        __update_recipient_status(recipientIds, IStrategy.Status.Rejected);

        bytes memory data = __generate_recipient_with_lazyMint_data(profile1_anchor(), recipientAddress(), amount);

        vm.expectEmit(address(_strategy));
        emit UpdatedRegistration(profile1_anchor(), data, profile1_member1(), 4);

        vm.prank(address(allo()));
        strategy.registerRecipient(data, profile1_member1());

        IStrategy.Status recipientStatus = strategy.getRecipientStatus(recipientId);
        assertEq(uint8(recipientStatus), uint8(IStrategy.Status.Appealed));
    }

    function test_acceptProjectApplication() public {
        uint256 amount = lazyMintAmount();
        address recipientId = __register_recipient_with_lazyMint(amount);

        address[] memory recipientIds = new address[](1);
        recipientIds[0] = recipientId;
        __update_recipient_status(recipientIds, IStrategy.Status.Accepted);

        // check if the recipient status has been updated to Accepted (2)
        assertEq(strategy.statusesBitMap(0), 2);
    }

    /** 
     * ===============================
     * ========== Allocate ===========
     * ===============================
    **/

    function test_allocate() public override {
        uint256 tokenId = _nfts.tokenId();
        address recipientId = __register_recipient_with_lazyMint(lazyMintAmount());

        address[] memory recipientIds = new address[](1);
        recipientIds[0] = recipientId;
        __update_recipient_status(recipientIds, IStrategy.Status.Accepted);

        // use `project owner` to set claimCondition on `tokenId`
        uint256 amount = 1 ether * 10;
        __set_claim_condition(profile1_member1(), tokenId, NATIVE, 1 ether, 100);

        // mint the allocate amount
        vm.deal(bob, amount);

        // get balance before allocation
        (uint256 _allocatedBalance, uint256 _totalLockedBalance, uint256 _allocatorBalance, uint256 _nftBalance) = 
            __getBalance(recipientId, bob, recipientAddress(), tokenId, NATIVE);
        
        // allocate to `recipientId`
        bytes32[] memory proofs;
        __allocate(recipientId, tokenId, 10, NATIVE, 1 ether, proofs, bobPK, "");

        // check balance after allocation
        __checkBalanceAfterAllocate(
            recipientId, bob, recipientAddress(), tokenId, NATIVE, _allocatedBalance + amount, _totalLockedBalance + amount,
            _allocatorBalance - amount, _nftBalance + 10
        );
    }

    function test_allocate_ERC20() public {
        uint256 tokenId = _nfts.tokenId();
        address recipientId = __register_recipient_with_lazyMint(lazyMintAmount());

        address[] memory recipientIds = new address[](1);
        recipientIds[0] = recipientId;
        __update_recipient_status(recipientIds, IStrategy.Status.Accepted);

        // use `project owner` to set claimCondition on `tokenId`
        uint256 amount = 1 ether * 10;
        address erc20Address = address(mockERC20);
        __set_claim_condition(profile1_member1(), tokenId, erc20Address, 1 ether, 100);

        // mint and approve the allocate amount
        mockERC20.mint(bob, amount);
        vm.prank(bob);
        mockERC20.approve(address(permit2), type(uint256).max);

        // get balance before allocation
        (uint256 _allocatedBalance, uint256 _totalLockedBalance, uint256 _allocatorBalance, uint256 _nftBalance) = 
            __getBalance(recipientId, bob, recipientAddress(), tokenId, erc20Address);
        
        // allocate to `recipientId`
        bytes32[] memory proofs;
        __allocate(recipientId, tokenId, 10, erc20Address, 1 ether, proofs, bobPK, "");

        // check balance after allocation
        __checkBalanceAfterAllocate(
            recipientId, bob, recipientAddress(), tokenId, erc20Address, _allocatedBalance + amount, _totalLockedBalance + amount,
            _allocatorBalance - amount, _nftBalance + 10
        );
    }

    function testRevert_allocate_ERC20_InvalidSigner() public {
        uint256 tokenId = _nfts.tokenId();
        address recipientId = __register_recipient_with_lazyMint(lazyMintAmount());

        address[] memory recipientIds = new address[](1);
        recipientIds[0] = recipientId;
        __update_recipient_status(recipientIds, IStrategy.Status.Accepted);

        // use `project owner` to set claimCondition on `tokenId`
        uint256 amount = 1 ether * 10;
        address erc20Address = address(mockERC20);
        __set_claim_condition(profile1_member1(), tokenId, erc20Address, 1 ether, 100);

        // mint and approve the allocate amount
        mockERC20.mint(bob, amount);
        vm.prank(bob);
        mockERC20.approve(address(permit2), type(uint256).max);

        // get balance before allocation
        (uint256 _allocatedBalance, uint256 _totalLockedBalance, uint256 _allocatorBalance, uint256 _nftBalance) = 
            __getBalance(recipientId, bob, recipientAddress(), tokenId, erc20Address);
        
        // allocate to `recipientId` with fault PK
        bytes32[] memory proofs;
        __allocate(recipientId, tokenId, 10, erc20Address, 1 ether, proofs, bobPK, abi.encodePacked(InvalidSigner.selector)); 

        // check balance after fail allocation, should be the same as before
        __checkBalanceAfterAllocate(
            recipientId, bob, recipientAddress(), tokenId, erc20Address, _allocatedBalance, _totalLockedBalance,
            _allocatorBalance, _nftBalance
        );
    }

    function testRevert_allocate_ERC20_SignatureExpired() public {
        uint256 tokenId = _nfts.tokenId();
        address recipientId = __register_recipient_with_lazyMint(lazyMintAmount());

        address[] memory recipientIds = new address[](1);
        recipientIds[0] = recipientId;
        __update_recipient_status(recipientIds, IStrategy.Status.Accepted);

        // use `project owner` to set claimCondition on `tokenId`
        uint256 amount = 1 ether * 10;
        address erc20Address = address(mockERC20);
        __set_claim_condition(profile1_member1(), tokenId, erc20Address, 1 ether, 100);

        // mint and approve the allocate amount
        mockERC20.mint(bob, amount);
        vm.prank(bob);
        mockERC20.approve(address(permit2), type(uint256).max);

        // get balance before allocation
        (uint256 _allocatedBalance, uint256 _totalLockedBalance, uint256 _allocatorBalance, uint256 _nftBalance) = 
            __getBalance(recipientId, bob, recipientAddress(), tokenId, erc20Address);
        
        // allocate to `recipientId` with fault PK
        bytes32[] memory proofs;
        __allocate(recipientId, tokenId, 10, erc20Address, 1 ether, proofs, bobPK, abi.encodePacked(SignatureExpired.selector, uint256(0))); 

        // check balance after fail allocation, should be the same as before
        __checkBalanceAfterAllocate(
            recipientId, bob, recipientAddress(), tokenId, erc20Address, _allocatedBalance, _totalLockedBalance,
            _allocatorBalance, _nftBalance
        );
    }

    /** 
     * ===============================
     * ========== Internal ===========
     * ===============================
    **/

    function __generate_recipient_with_lazyMint_data(address _recipientId, address _recipientAddress, uint256 amountNFTs) internal pure returns (bytes memory) {
        Metadata memory metadata = Metadata({protocol: 1, pointer: "basecidhash"});
        return abi.encode(_recipientId, _recipientAddress, metadata, amountNFTs, defaultRoyaltyFee());
    }

    function __register_recipient_with_lazyMint(uint256 amountNFTs) internal returns (address recipientId) {
        vm.warp(registrationStartTime + 10);
        vm.prank(address(allo()));
        bytes memory data = __generate_recipient_with_lazyMint_data(profile1_anchor(), recipientAddress(), amountNFTs);
        recipientId = strategy.registerRecipient(data, profile1_member1());
    }

    function __register_recipient_with_lazyMint2(uint256 amountNFTs) internal returns (address recipientId) {
        vm.warp(registrationStartTime + 10);
        vm.prank(address(allo()));
        bytes memory data = __generate_recipient_with_lazyMint_data(profile2_anchor(), randomAddress(), amountNFTs);
        recipientId = strategy.registerRecipient(data, profile2_member1());
    }

    function __update_recipient_status(address[] memory recipientIds, IStrategy.Status _status) internal {
        uint256 length = recipientIds.length;
        DonationVotingMerkleDistributionBaseStrategy.ApplicationStatus[] memory statuses =
            new DonationVotingMerkleDistributionBaseStrategy.ApplicationStatus[](length);
        
        for (uint256 i=0; i<length;) {
            statuses[i] = __buildStatusRow(i, uint8(_status));

            vm.expectEmit(address(_strategy));
            emit RecipientStatusUpdated(statuses[i].index, statuses[i].statusRow, pool_admin());

            unchecked {
                i++;
            }
        }

        vm.prank(pool_admin());
        strategy.reviewRecipients(statuses);
    }

    function __set_claim_condition(address _sender, uint256 tokenId, address currency, uint256 price, uint256 supply) internal {
        if (supply < 10) {
            supply = 10;
        }
        IClaimEligibility.ClaimCondition memory condition = IClaimEligibility.ClaimCondition({
            startTimestamp: allocationStartTime,
            endTimestamp: allocationEndTime,
            maxClaimableSupply: supply,
            supplyClaimed: 0,
            quantityLimitPerWallet: supply / 10,
            merkleRoot: bytes32(""),
            pricePerToken: price,
            currency: currency,
            metadata: ""
        });

        vm.prank(_sender);
        _nfts.setClaimConditions(tokenId, condition, false);
    }

    function __generate_allocate_with_claim_nfts_data(
        address recipientId, 
        address nftReceiver,
        uint256 tokenId,
        uint256 qty,
        address currency, 
        uint256 price, 
        bytes32[] memory proofs,
        bytes memory claimSignature,
        uint256 deadline,
        uint256 claimerPK
    ) internal view returns (bytes memory) {
        uint256 amount = qty * price;

        DonationVotingMerkleDistributionBaseStrategy.Permit2Data memory permit2Data =
            DonationVotingMerkleDistributionBaseStrategy.Permit2Data({
                permit: ISignatureTransfer.PermitTransferFrom({
                    permitted: ISignatureTransfer.TokenPermissions({token: currency, amount: amount}),
                    nonce: 0,
                    deadline: deadline
                }),
                signature: ""
            });
        if (currency != NATIVE) {
            permit2Data.signature = __getPermitTransferSignature(
                permit2Data.permit, 
                claimerPK, 
                permit2.DOMAIN_SEPARATOR(), 
                address(_strategy)
            );
        }

        NFTRewardStrategy.ClaimNFT memory claimData = NFTRewardStrategy.ClaimNFT({
            receiver: nftReceiver,
            tokenId: tokenId,
            quantity: qty,
            proofs: proofs,
            deadline: allocationStartTime + 10000,
            signature: claimSignature
        });

        return abi.encode(recipientId, permit2Data, claimData);
    }

    function __allocate(
        address recipientId, 
        uint256 tokenId, 
        uint256 qty,
        address currency, 
        uint256 price, 
        bytes32[] memory proofs,
        uint256 claimerPK,
        bytes memory errSelector
    ) internal {
        uint256 amount = qty * price;
        address claimer = vm.addr(claimerPK);
        // uint256 deadline = allocationStartTime + 10000;

        // get claim signature for validation on NFT contract
        bytes32 claimHash = _getClaimHash(_getClaimStruct(
            claimer,
            recipientAddress(),
            tokenId,
            qty,
            currency,
            price,
            proofs,
            allocationStartTime + 10000
        ));

        // generate the custom allocation with claim NFTs data
        vm.warp(allocationStartTime + 1);
        bytes memory data = __generate_allocate_with_claim_nfts_data(
            recipientId,
            recipientAddress(),
            tokenId,
            qty,
            currency,
            price,
            proofs,
            _generateEIP712Signature(claimHash, claimerPK),
            bytes4(errSelector) == SignatureExpired.selector ? 0 : allocationStartTime + 10000,
            bytes4(errSelector) == InvalidSigner.selector ? 0x12345 : claimerPK
        );

        if (errSelector.length == 0) {
            vm.expectEmit(address(_strategy));
            emit Allocated(recipientId, amount, currency, claimer);
        } else if (errSelector.length == 4) {
            vm.expectRevert(bytes4(errSelector));
        } else {
            vm.expectRevert(errSelector);
        }

        vm.prank(claimer);
        if (currency == NATIVE) {
            allo().allocate{value: amount}(poolId, data);
        } else {
            allo().allocate(poolId, data);
        }
    }

    function __checkRecipientInfo(
        address recipientId,
        bool _useRegistryAnchor,
        address _recipientAddress,
        uint256 _baseURIProtocol,
        string memory _baseURICID,
        uint256 _batchId,
        IStrategy.Status _status
    ) internal {
        DonationVotingMerkleDistributionBaseStrategy.Recipient memory _recipient = strategy.getRecipient(recipientId);
        assertEq(_recipient.useRegistryAnchor, _useRegistryAnchor);
        assertEq(_recipient.recipientAddress, _recipientAddress);
        assertEq(_recipient.metadata.protocol, _baseURIProtocol);
        assertEq(keccak256(abi.encode(_recipient.metadata.pointer)), keccak256(abi.encode(_baseURICID)));
        assertEq(_strategy.recipientIdToBatchId(recipientId), _batchId);

        IStrategy.Status recipientStatus = strategy.getRecipientStatus(recipientId);
        assertEq(uint8(recipientStatus), uint8(_status));
    }

    function __checkBatchNFT(
        uint256 batchId, 
        uint256 tokenId, 
        uint256 nextTokenId, 
        string memory uri, 
        address saleRecipient, 
        address authorizer, 
        address royaltyReceiver, 
        uint96 royaltyFeeFraction
    ) internal {
        ERC2981.RoyaltyInfo memory royaltyInfo = _nfts.royaltyInfoForBatch(batchId);
        assertEq(_nfts.tokenId(), nextTokenId);
        assertEq(_nfts.uri(tokenId), uri);
        assertEq(_nfts.saleRecipientForBatch(batchId), saleRecipient);
        assertEq(_nfts.authorizerForBatch(batchId), authorizer);
        assertEq(royaltyInfo.receiver, royaltyReceiver);
        assertEq(royaltyInfo.royaltyFraction, royaltyFeeFraction);
    }

    function __getBalance(
        address recipientId,
        address allocator, 
        address nftReceiver, 
        uint256 tokenId, 
        address currency
    ) internal view returns (
        uint256 allocatedBalance, 
        uint256 totalLockedBalance,
        uint256 allocatorBalance,
        uint256 nftBalance
    ) {
        if (currency == NATIVE) {
            totalLockedBalance = address(_strategy).balance;
            allocatorBalance = allocator.balance;
        } else {
            IERC20 _token = IERC20(currency);
            totalLockedBalance = _token.balanceOf(address(_strategy));
            allocatorBalance = _token.balanceOf(allocator);
        }
        // console.log(totalLockedBalance, allocatorBalance);
        allocatedBalance = _strategy.claims(recipientId, currency);
        nftBalance = _nfts.balanceOf(nftReceiver, tokenId);
    }

    function __checkBalanceAfterAllocate(
        address recipientId,
        address allocator, 
        address nftReceiver, 
        uint256 tokenId, 
        address currency, 
        uint256 allocatedBalance,
        uint256 lockedBalance,
        uint256 allocatorBalance,
        uint256 nftBalance
    ) internal {
        (uint256 _allocatedBalance, uint256 _totalLockedBalance, uint256 _allocatorBalance, uint256 _nftBalance) = 
            __getBalance(recipientId, allocator, nftReceiver, tokenId, currency);
        assertEq(_nftBalance, nftBalance);
        assertEq(_allocatorBalance, allocatorBalance);
        assertEq(_allocatedBalance, allocatedBalance);
        assertEq(_totalLockedBalance, lockedBalance);
    }

    /** 
     * ===============================
     * ========== Signature ==========
     * ===============================
    **/

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

    function _getClaimHash(IClaimEligibility.Claim memory claimData) internal view returns (bytes32 structHash) {
        return keccak256(
            abi.encode(
                _nfts.CLAIM_TYPEHASH(),
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
        bytes32 digest = _hashTypedDataV4(address(_nfts), "ChariiNFTs", "1.0.0", claimHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(claimerPK, digest);
        signature = abi.encodePacked(r, s, v);
    }
}