// SPDX-License-Identifier: GPL-3.0 or above
pragma solidity ^0.8.33;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract Auction is IERC721Receiver {
    error AlreadyFinished();
    error AuctionNotStarted();
    error AuctionEnded();
    error AuctionNotEnded();
    error InsufficientBid();

    address public owner;
    NFT public auctionedToken;
    IERC20 public token;
    IERC721 public coll;
    uint256 public startTime;
    uint256 public endTime;
    bool public finished;
    address public highestBidder;
    uint256 public highestBid;

    struct NFT {
        uint256 tokenId;
    }

    constructor(
        IERC20 _token,
        IERC721 _collection,
        uint256 tokenId,
        address _owner,
        uint256 _startTime,
        uint256 _endTime
    ) {
        require(_collection.ownerOf(tokenId) == msg.sender && msg.sender == _owner && block.timestamp < _endTime);

        owner = _owner;
        token = _token;
        coll = _collection;
        auctionedToken = NFT(tokenId);
        startTime = _startTime;
        endTime = _endTime;
    }

    mapping(address => uint256) public bids;
    mapping(address => bool) public hasBid;

    function bid(uint256 amount) public {
        if (finished) revert AlreadyFinished();
        if (block.timestamp < startTime) revert AuctionNotStarted();
        if (block.timestamp > endTime) revert AuctionEnded();
        if (amount == 0) revert InsufficientBid();

        token.transferFrom(msg.sender, address(this), amount);

        bids[msg.sender] += amount;
        hasBid[msg.sender] = true;

        if (bids[msg.sender] > highestBid) {
            highestBid = bids[msg.sender];
            highestBidder = msg.sender;
        }
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function finishAuction() public returns (address) {
        if (finished) revert AlreadyFinished();
        if (block.timestamp < endTime) revert AuctionNotEnded();

        finished = true;

        if (highestBidder == address(0)) {
            return address(0);
        }

        coll.transferFrom(owner, highestBidder, auctionedToken.tokenId);
        return highestBidder;
    }
}
