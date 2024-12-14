// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract AuctionFactory is ReentrancyGuard {
    struct Auction {
        bool isActive;
        uint256 collateralAmount;
        address collateralToken;
        address highestBidder;
        uint256 currentBid;
        address initiator;
        uint256 endTime;
    }

    struct Bid {
        address bidder;
        uint256 amount;
    }

    mapping(bytes32 => Auction) public auctions;
    mapping(bytes32 => Bid[]) public auctionBids; // Tracks all bids for an auction

    event AuctionStarted(
        bytes32 indexed auctionId,
        address indexed initiator,
        address indexed collateralToken,
        uint256 collateralAmount,
        uint256 endTime
    );
    event BidPlaced(bytes32 indexed auctionId, address indexed bidder, uint256 amount);
    event AuctionEnded(
        bytes32 indexed auctionId, address indexed winner, uint256 winningBid, uint256 collateralClaimed
    );

    uint256 public constant AUCTION_DURATION = 1 days; // Default auction duration

    function startAuction(bytes32 auctionId, address collateralToken, uint256 collateralAmount, address initiator)
        external
    {
        require(auctions[auctionId].isActive == false, "Auction already exists");

        // Transfer collateral to the auction contract
        IERC20(collateralToken).transferFrom(msg.sender, address(this), collateralAmount);

        auctions[auctionId] = Auction({
            isActive: true,
            collateralAmount: collateralAmount,
            collateralToken: collateralToken,
            highestBidder: address(0),
            currentBid: 0,
            initiator: initiator,
            endTime: block.timestamp + AUCTION_DURATION
        });

        emit AuctionStarted(auctionId, initiator, collateralToken, collateralAmount, auctions[auctionId].endTime);
    }

    function placeBid(bytes32 auctionId, uint256 bidAmount) external nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(auction.isActive, "Auction not active");
        require(block.timestamp < auction.endTime, "Auction has ended");
        require(bidAmount > auction.currentBid, "Bid amount must be higher than the current bid");

        // Refund the previous highest bidder, if applicable
        if (auction.highestBidder != address(0)) {
            IERC20(auction.collateralToken).transfer(auction.highestBidder, auction.currentBid);
        }

        // Accept the new bid
        IERC20(auction.collateralToken).transferFrom(msg.sender, address(this), bidAmount);
        auction.currentBid = bidAmount;
        auction.highestBidder = msg.sender;

        // Record the bid
        auctionBids[auctionId].push(Bid({bidder: msg.sender, amount: bidAmount}));

        emit BidPlaced(auctionId, msg.sender, bidAmount);
    }

    function endAuction(bytes32 auctionId) external nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(auction.isActive, "Auction not active");
        require(block.timestamp >= auction.endTime, "Auction is still ongoing");

        auction.isActive = false;

        // If there is a winning bidder, transfer collateral to them
        if (auction.highestBidder != address(0)) {
            IERC20(auction.collateralToken).transfer(auction.highestBidder, auction.collateralAmount);
        } else {
            // If no bids, return collateral to the initiator
            IERC20(auction.collateralToken).transfer(auction.initiator, auction.collateralAmount);
        }

        emit AuctionEnded(auctionId, auction.highestBidder, auction.currentBid, auction.collateralAmount);
    }

    function getAllBids(bytes32 auctionId) external view returns (Bid[] memory) {
        return auctionBids[auctionId];
    }
}
