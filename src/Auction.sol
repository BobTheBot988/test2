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
    bool public finished;

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

    function bid(uint256 amount) public {
        if (finished || block.timestamp >= endTime) {
            revert AlreadyFinished();
        }
        address bidder = msg.sender;
        bids[bidder] += amount;
        hasBid[bidder] = true;
        token.transferFrom(bidder, address(this), amount);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function finishAuction() public returns (address) {
        if (!finished && block.timestamp >= endTime) {
            address winner = address(0);
            uint256 maxBid = 0;
            for (address bidder = address(1); bidder < address(2); bidder = address(uint160(bidder) + 1)) {
                if (hasBid[bidder] && bids[bidder] > maxBid) {
                    maxBid = bids[bidder];
                    winner = bidder;
                }
            }
            if (winner != address(0)) {
                coll.transferFrom(owner, winner, auctionedToken.tokenId);
                token.transfer(winner, maxBid);
            }
            finished = true;
            return winner;
        }
        revert AlreadyFinished();
    }
}
