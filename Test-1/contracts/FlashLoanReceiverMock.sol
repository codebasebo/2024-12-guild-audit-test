// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILendingProtocol {
    function flashLoan(address token, uint256 amount, bytes calldata data) external;
}

contract FlashLoanReceiverMock {
    address public lendingProtocol;

    constructor(address _lendingProtocol) {
        lendingProtocol = _lendingProtocol;
    }

    function executeOperation(address token, uint256 amount) external {
        uint256 fee = (amount * 9) / 10000; // Match FLASH_LOAN_FEE
        uint256 repaymentAmount = amount + fee;
        IERC20(token).approve(lendingProtocol, repaymentAmount); // Approve repayment
    }

    function initiateFlashLoan(address token, uint256 amount) external {
        ILendingProtocol(lendingProtocol).flashLoan(
            token, amount, abi.encodeWithSignature("executeOperation(address,uint256)", token, amount)
        );
    }
}
