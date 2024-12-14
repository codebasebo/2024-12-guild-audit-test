// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract MockPriceOracle {
    mapping(address => uint256) public tokenPrices;

    function setPrice(address token, uint256 price) external {
        tokenPrices[token] = price;
    }

    function getPrice(address token) external view returns (uint256) {
        return tokenPrices[token];
    }
}
