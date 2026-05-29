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
        token = _token;
        coll = _collection;
        owner = _owner;
        startTime = _startTime;
        endTime = _endTime;
        auctionedToken = NFT({tokenId: tokenId});
    }

    mapping(address => uint256) public bids;
    mapping(address => bool) public hasBid;
    address[] private _bidders;
    bool private _finished;

    function bid(uint256 amount) public {
        if (_finished) revert AlreadyFinished();
        require(block.timestamp >= startTime && block.timestamp <= endTime, "invalid time");
        token.transferFrom(msg.sender, address(this), amount);
        if (!hasBid[msg.sender]) {
            _bidders.push(msg.sender);
            hasBid[msg.sender] = true;
        }
        bids[msg.sender] += amount;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function finishAuction() public returns (address) {
        if (_finished) revert AlreadyFinished();
        require(block.timestamp > endTime, "auction not ended");
        address winner = _highestBidder();
        require(winner != address(0), "no bids");
        coll.safeTransferFrom(owner, winner, auctionedToken.tokenId);
        owner = winner;
        _finished = true;
        return winner;
    }

    function _highestBidder() internal view returns (address) {
        address best;
        uint256 bestBid;
        for (uint256 i = 0; i < _bidders.length; i++) {
            address b = _bidders[i];
            uint256 amt = bids[b];
            if (amt > bestBid) {
                bestBid = amt;
                best = b;
            }
        }
        return best;
    }
}
