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
        if (_pullNft) {
            _collection.safeTransferFrom(_owner, address(this), tokenId);
        }
    }

    bool internal _pullNft;

    mapping(address => uint256) public bids;
    mapping(address => bool) public hasBid;
    address public highestBidder;

    function bid(uint256 amount) public {
        if (block.timestamp > endTime) {
            revert AlreadyFinished();
        }
        if (highestBidder != address(0) && !hasBid[msg.sender] && amount <= bids[highestBidder]) {
            revert();
        }
        hasBid[msg.sender] = true;
        bids[msg.sender] += amount;
        token.transferFrom(msg.sender, address(this), amount);
        if (highestBidder == address(0) || bids[msg.sender] > bids[highestBidder]) {
            highestBidder = msg.sender;
        }
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    bool public finished;

    function finishAuction() public returns (address) {
        if (finished) {
            revert AlreadyFinished();
        }
        if (block.timestamp <= endTime) {
            revert();
        }
        finished = true;
        address winner = highestBidder;
        if (!_pullNft) {
            coll.transferFrom(owner, winner, auctionedToken.tokenId);
        } else {
            coll.transferFrom(address(this), winner, auctionedToken.tokenId);
        }
        return winner;
    }
}
