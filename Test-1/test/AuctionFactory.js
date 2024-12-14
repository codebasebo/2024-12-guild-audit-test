const { expect } = require("chai");
const { ethers } = require("hardhat");



describe("AuctionFactory", function () {
    let AuctionFactory, auctionFactory, Token, token;
    let owner, bidder1, bidder2;

    beforeEach(async () => {
        [owner, bidder1, bidder2] = await ethers.getSigners();

        // Deploy mock ERC20 token
        Token = await ethers.getContractFactory("ERC20Mock");
        token = await Token.deploy("TestToken", "TT", owner.address, ethers.utils.parseEther("1000"));
        await token.deployed();

        // Deploy auction factory
        AuctionFactory = await ethers.getContractFactory("AuctionFactory");
        auctionFactory = await AuctionFactory.deploy();
        await auctionFactory.deployed();

        // Allocate tokens to bidders
        await token.transfer(bidder1.address, ethers.utils.parseEther("100"));
        await token.transfer(bidder2.address, ethers.utils.parseEther("100"));
    });

    it("should allow bids and end auction correctly", async function () {
        const auctionId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("auction1"));
        const collateralAmount = ethers.utils.parseEther("50");

        // Approve and start auction
        await token.connect(owner).approve(auctionFactory.address, collateralAmount);
        await auctionFactory.startAuction(auctionId, token.address, collateralAmount, owner.address);

        // Place bids
        const bid1 = ethers.utils.parseEther("20");
        await token.connect(bidder1).approve(auctionFactory.address, bid1);
        await auctionFactory.connect(bidder1).placeBid(auctionId, bid1);

        const bid2 = ethers.utils.parseEther("30");
        await token.connect(bidder2).approve(auctionFactory.address, bid2);
        await auctionFactory.connect(bidder2).placeBid(auctionId, bid2);

        // Assert bids
        const auction = await auctionFactory.auctions(auctionId);
        expect(auction.currentBid.toString()).to.equal(bid2.toString());
        expect(auction.highestBidder).to.equal(bidder2.address);

        // End auction
        await ethers.provider.send("evm_increaseTime", [24 * 60 * 60]); // Fast forward time
        await auctionFactory.endAuction(auctionId);

        // Check final state
        expect((await auctionFactory.auctions(auctionId)).isActive).to.be.false;
        expect(await token.balanceOf(bidder2.address)).to.equal(collateralAmount);
    });

});