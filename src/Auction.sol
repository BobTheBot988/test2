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
        auctionedToken = NFT({ tokenId: tokenId });
    }

    bool private _finished;

    mapping(address => uint256) public bids;
    mapping(address => bool) public hasBid;
    address[] private _bidderAddresses;

    function bid(uint256 amount) public {
        if (_finished) revert AlreadyFinished();
        require(amount > 0, "ZeroBid");
        require(block.timestamp >= startTime, "NotStarted");
        token.transferFrom(msg.sender, address(this), amount);
        if (!hasBid[msg.sender]) {
            _bidderAddresses.push(msg.sender);
        }
        bids[msg.sender] += amount;
        hasBid[msg.sender] = true;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function finishAuction() public returns (address) {
        if (_finished) revert AlreadyFinished();
        require(block.timestamp > endTime, "NotEnded");
        _finished = true;

        address winner;
        uint256 highestAmount;

        for (uint256 i = 0; i < _bidderAddresses.length; i++) {
            address bidder = _bidderAddresses[i];
            if (bids[bidder] > highestAmount) {
                highestAmount = bids[bidder];
                winner = bidder;
            }
        }

        if (winner != address(0)) {
            coll.safeTransferFrom(owner, winner, auctionedToken.tokenId);
        }

        return winner;
    }
}
