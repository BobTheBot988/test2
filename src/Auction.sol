// SPDX-License-Identifier: GPL-3.0 or above
pragma solidity ^0.8.33;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract Auction is IERC721Receiver {
    error AlreadyFinished();
    error AlreadyBid();
    error BidTooLow();
    error AuctionNotFinished();
    error NoBids();

    address public owner;
    NFT public auctionedToken;
    IERC20 public token;
    IERC721 public coll;
    uint256 public startTime;
    uint256 public endTime;
    bool public finished;

    address public highestBidder;
    address public secondHighestBidder;
    uint256 public secondHighestBid;

    struct NFT {
        uint256 tokenId;
    }

    event BidPlaced(address indexed bidder, uint256 amount);
    event AuctionFinished(address indexed winner, uint256 amount);

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
        auctionedToken = NFT(tokenId);
        token = _token;
        coll = _collection;
        startTime = _startTime;
        endTime = _endTime;
    }

    mapping(address => uint256) public bids;
    mapping(address => bool) public hasBid;

    function bid(uint256 amount) public {
        if (hasBid[msg.sender]) revert AlreadyBid();
        if (amount <= bids[highestBidder]) revert BidTooLow();

        token.transferFrom(msg.sender, address(this), amount);

        if (bids[highestBidder] > 0) {
            secondHighestBidder = highestBidder;
            secondHighestBid = bids[highestBidder];
        }
        highestBidder = msg.sender;
        bids[msg.sender] = amount;
        hasBid[msg.sender] = true;

        emit BidPlaced(msg.sender, amount);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function finishAuction() public returns (address) {
        if (finished) revert AlreadyFinished();
        if (block.timestamp < endTime) revert AuctionNotFinished();

        finished = true;

        if (highestBidder == address(0)) {
            return address(0);
        }

        address winner = highestBidder;
        uint256 winningBid = bids[winner];

        coll.transferFrom(owner, winner, auctionedToken.tokenId);

        if (secondHighestBidder != address(0)) {
            token.transfer(secondHighestBidder, secondHighestBid);
        }

        token.transfer(owner, winningBid);

        emit AuctionFinished(winner, winningBid);
        return winner;
    }
}
