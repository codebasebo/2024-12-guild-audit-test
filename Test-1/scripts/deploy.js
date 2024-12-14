import { ethers } from "hardhat";

async function main() {
    // Max NFTs
    const MAX_NFTS = 100;

    // Deploy the CryptoDevsNFT contract first
    const AuctionFactory = await ethers.getContractFactory("AuctionFactory");
    const auctionFactory = await AuctionFactory.deploy(MAX_NFTS);
    await auctionFactory.deployed();
    console.log("Deployed AuctionEngine contract at address:", auctionFactory.address);

    // Deploy the NFTMarketplace contract
    const MockPriceOracle = await ethers.getContractFactory("MockPriceOracle");
    const mockPriceOracle = await MockPriceOracle.deploy();
    await mockPriceOracle.deployed();
    console.log("Deployed MockPriceOracle at address:", mockPriceOracle.address);

    // Deploy the DAO Contract
    const LendingProtocol = await ethers.getContractFactory("LendingProtocol");
    const lendingProtocol = await LendingProtocol.deploy(
        mockPriceOracle.address,
        auctionFactory.address
    );
    await lendingProtocol.deployed();
    console.log("Deployed CryptoDevsDAO at address:", lendingProtocol.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
