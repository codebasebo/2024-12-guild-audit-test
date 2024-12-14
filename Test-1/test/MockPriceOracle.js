const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("MockPriceOracle", function () {
    let mockPriceOracle, token;

    beforeEach(async function () {
        const MockPriceOracle = await ethers.getContractFactory("MockPriceOracle");
        mockPriceOracle = await MockPriceOracle.deploy();
        await mockPriceOracle.deployed();

        const MockERC20 = await ethers.getContractFactory("ERC20Mock");
        token = await MockERC20.deploy("MockToken", "MTK", owner.address, ethers.utils.parseEther("100000"));
        await token.deployed();
    });

    it("Should set and get token prices", async function () {
        await mockPriceOracle.setPrice(token.address, ethers.utils.parseEther("1"));
        const price = await mockPriceOracle.getPrice(token.address);
        expect(price).to.equal(ethers.utils.parseEther("1"));
    });
});

