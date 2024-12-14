const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("LendingProtocol", function () {
  let lendingProtocol;
  let mockToken;
  let priceOracle;
  let auctionFactory;
  let owner, user1, user2;
  let liquidationThreshold;

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();

    // Deploy mock token
    const MockToken = await ethers.getContractFactory("ERC20Mock");
    mockToken = await MockToken.deploy("Mock Token", "MTK");
    await mockToken.deployed();

    // Deploy price oracle
    const MockPriceOracle = await ethers.getContractFactory("MockPriceOracle");
    priceOracle = await MockPriceOracle.deploy();
    await priceOracle.deployed();

    // Deploy auction factory
    const AuctionFactory = await ethers.getContractFactory("AuctionFactory");
    auctionFactory = await AuctionFactory.deploy();
    await auctionFactory.deployed();

    // Set liquidation threshold (75%)
    liquidationThreshold = ethers.utils.parseEther("0.75");

    // Deploy main protocol
    const LendingProtocol = await ethers.getContractFactory("LendingProtocol");
    lendingProtocol = await LendingProtocol.deploy(
      priceOracle.address,
      auctionFactory.address,
      liquidationThreshold,
      owner.address
    );
    await lendingProtocol.deployed();

    // Setup initial token state
    await mockToken.mint(user1.address, ethers.utils.parseEther("1000"));
    await mockToken.connect(user1).approve(lendingProtocol.address, ethers.constants.MaxUint256);
  });

  describe("Deployment", function () {
    it("Should set the correct owner", async function () {
      expect(await lendingProtocol.owner()).to.equal(owner.address);
    });

    it("Should set correct COLLATERALIZATION_RATIO", async function () {
      expect(await lendingProtocol.COLLATERALIZATION_RATIO()).to.equal(150);
    });

    it("Should set correct price oracle", async function () {
      expect(await lendingProtocol.priceOracle()).to.equal(priceOracle.address);
    });

    it("Should set correct auction factory", async function () {
      expect(await lendingProtocol.auctionFactory()).to.equal(auctionFactory.address);
    });
  });

  describe("Collateral Management", function () {
    beforeEach(async function () {
      await priceOracle.setPrice(mockToken.address, ethers.utils.parseEther("1"));
    });

    it("Should accept collateral deposit", async function () {
      const depositAmount = ethers.utils.parseEther("100");
      await lendingProtocol.connect(user1).depositCollateral(mockToken.address, depositAmount);

      const position = await lendingProtocol.getCollateralAmount(user1.address, mockToken.address);
      expect(position).to.equal(depositAmount);
    });

    it("Should prevent depositing zero collateral", async function () {
      await expect(
        lendingProtocol.connect(user1).depositCollateral(mockToken.address, 0)
      ).to.be.revertedWith("Amount must be greater than 0");
    });
  });

  describe("Liquidation Scenarios", function () {
    it("Should identify undercollateralized positions", async function () {
      const depositAmount = ethers.utils.parseEther("100");
      await lendingProtocol.connect(user1).depositCollateral(mockToken.address, depositAmount);

      // Drop price by 50%
      await priceOracle.setPrice(mockToken.address, ethers.utils.parseEther("0.5"));

      expect(await lendingProtocol.isUndercollateralized(user1.address)).to.be.true;
    });
  });

  describe("Access Control", function () {
    it("Should only allow owner to set parameters", async function () {
      await expect(
        lendingProtocol.connect(user1).setLiquidationThreshold(ethers.utils.parseEther("0.8"))
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });
});