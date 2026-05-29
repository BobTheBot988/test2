// SPDX-License-Identifier: GPL-3.0 or above
pragma solidity ^0.8.33;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract Auction is IERC721Receiver {
    error AlreadyFinished();

    address public owner;
    NFT public auctionedToken;
    IERC20 public token;
    IERC721 public coll;
    uint256 public startTime;
    uint256 public endTime;

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
        startTime = _startTime;
        endTime = _endTime;
        auctionedToken = NFT({tokenId: tokenId});
    }

    mapping(address => uint256) public bids;
    mapping(address => bool) public hasBid;
    bool public finished;
    address[] public bidders;

    function bid(uint256 amount) public {
        if (finished) revert AlreadyFinished();
        require(block.timestamp < endTime, "Auction ended");

        require(!hasBid[msg.sender], "Already bid");

        hasBid[msg.sender] = true;
        bids[msg.sender] += amount;

        bidders.push(msg.sender);

        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function finishAuction() public returns (address) {
        if (finished) revert AlreadyFinished();
        require(block.timestamp >= endTime, "Auction not ended");

        address highestBidder = address(0);
        uint256 highestBid = 0;

        for (uint256 i = 0; i < bidders.length; i++) {
            address bidder = bidders[i];
            if (bids[bidder] > highestBid) {
                highestBid = bids[bidder];
                highestBidder = bidder;
            }
        }

        require(highestBidder != address(0), "No bids");

        finished = true;

        coll.safeTransferFrom(address(this), highestBidder, auctionedToken.tokenId);

        return highestBidder;
    }
}
