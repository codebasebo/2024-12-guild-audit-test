// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./MockPriceOracle.sol";
import "./AuctionFactory.sol";

/**
 * @title LendingProtocol
 * @dev A decentralized lending protocol with collateralized loans, flash loans, and reward distribution.
 */
contract LendingProtocol is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Constants
    uint256 public constant COLLATERALIZATION_RATIO = 150; // 150%
    uint256 public constant FLASH_LOAN_FEE = 9; // 0.09% (in basis points)
    uint256 public constant TRANSFER_FEE = 800; // 8% transfer fee (in basis points)
    uint256 public constant ANNUAL_INTEREST_RATE = 5; // 5% annual interest rate

    // Oracle and Auction contracts
    MockPriceOracle public priceOracle;
    AuctionFactory public auctionContract;
    address public Admin;

    // Reward pools per token
    mapping(address => uint256) public rewardPool; // Token-specific reward pool
    mapping(address => mapping(address => uint256)) public lastClaimedReward; // token => user => last claim time

    // Token configurations and balances
    mapping(address => bool) public whitelistedTokens; // Whitelisted tokens
    mapping(address => mapping(address => uint256)) public userCollateral; // User collateral by token

    struct BorrowInfo {
        uint256 amount; // Principal borrowed
        uint256 interestAccrued; // Accumulated interest
        uint256 lastBorrowTimestamp; // Last interest accrual timestamp
    }

    mapping(address => mapping(address => BorrowInfo)) public borrowDetails; // User borrow details by token
    uint256 public protocolFeeBalance; // Tracks protocol fees collected

    // Events
    event Deposited(address indexed user, address indexed token, uint256 amount);
    event Borrowed(address indexed user, address indexed token, uint256 amount);
    event Repaid(address indexed user, address indexed token, uint256 amount);
    event Liquidated(address indexed user, address indexed token, uint256 debt);
    event FlashLoanExecuted(address indexed user, address indexed token, uint256 amount);
    event RewardClaimed(address indexed user, address indexed token, uint256 amount);
    event RewardsDistributed(address indexed token, uint256 amount);

    constructor(address _oracle, address _auction, address _admin) Ownable(_admin) ReentrancyGuard() {
        priceOracle = MockPriceOracle(_oracle);
        auctionContract = AuctionFactory(_auction);
    }

    // --- Collateral Management ---
    function deposit(address token, uint256 amount) external nonReentrant {
        require(whitelistedTokens[token], "Token not whitelisted");
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        userCollateral[msg.sender][token] += amount;
        emit Deposited(msg.sender, token, amount);
    }

    // --- Borrowing ---
    function borrow(address token, uint256 amount) external nonReentrant {
        require(whitelistedTokens[token], "Token not whitelisted");

        BorrowInfo storage info = borrowDetails[msg.sender][token];
        require(info.amount == 0 && info.interestAccrued == 0, "Outstanding debt must be repaid first");

        uint256 collateralValue = getCollateralValue(msg.sender, token);
        uint256 maxBorrow = (collateralValue * 100) / COLLATERALIZATION_RATIO;
        require(amount <= maxBorrow, "Exceeds collateralized amount");

        info.amount += amount;
        info.lastBorrowTimestamp = block.timestamp;

        uint256 fee = (amount * TRANSFER_FEE) / 10000;
        protocolFeeBalance += fee;

        IERC20(token).safeTransfer(msg.sender, amount - fee);
        emit Borrowed(msg.sender, token, amount);
    }

    function repay(address token, uint256 amount) external nonReentrant {
        BorrowInfo storage info = borrowDetails[msg.sender][token];
        require(info.amount > 0, "No debt to repay");

        accrueInterest(msg.sender, token);

        uint256 totalDebt = info.amount + info.interestAccrued;
        require(amount <= totalDebt, "Repayment exceeds total debt");

        if (amount <= info.interestAccrued) {
            info.interestAccrued -= amount;
        } else {
            uint256 principalRepayment = amount - info.interestAccrued;
            info.interestAccrued = 0;
            info.amount -= principalRepayment;
        }

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit Repaid(msg.sender, token, amount);
    }

    //-- Liquidation --
    function liquidate(address user, address token) external nonReentrant {
        BorrowInfo storage info = borrowDetails[user][token];
        uint256 totalDebt = info.amount + info.interestAccrued;

        uint256 collateralValue = getCollateralValue(user, token);
        require(totalDebt > collateralValue, "Position is not under-collateralized");

        delete borrowDetails[user][token];

        uint256 collateralAmount = userCollateral[user][token];
        delete userCollateral[user][token];

        auctionContract.startAuction(
            keccak256(abi.encode(user, token, collateralAmount, block.timestamp)), token, collateralAmount, user
        );

        emit Liquidated(user, token, totalDebt);
    }

    // --- Flash Loans ---
    function flashLoan(address token, uint256 amount, bytes calldata data) external nonReentrant {
        require(whitelistedTokens[token], "Token not whitelisted");

        uint256 fee = (amount * FLASH_LOAN_FEE) / 10000;
        uint256 repaymentAmount = amount + fee;
        protocolFeeBalance += fee;

        IERC20(token).safeTransfer(msg.sender, amount);

        (bool success,) = msg.sender.call(data);
        require(success, "Callback execution failed");

        IERC20(token).safeTransferFrom(msg.sender, address(this), repaymentAmount);
        emit FlashLoanExecuted(msg.sender, token, amount);
    }

    // --- Reward Distribution ---
    function distributeFees(address token, uint256 amount) external onlyOwner {
        require(whitelistedTokens[token], "Token not whitelisted");
        require(amount <= protocolFeeBalance, "Insufficient protocol fees");

        protocolFeeBalance -= amount;
        rewardPool[token] += amount;
        emit RewardsDistributed(token, amount);
    }

    function claimRewards(address token) external nonReentrant {
        require(whitelistedTokens[token], "Token not whitelisted");

        uint256 totalSupply = IERC20(token).totalSupply();
        require(totalSupply > 0, "No rewards to distribute");

        uint256 userBalance = IERC20(token).balanceOf(msg.sender);
        uint256 share = (rewardPool[token] * userBalance) / totalSupply;
        require(share > 0, "No rewards to claim");

        rewardPool[token] -= share;
        IERC20(token).safeTransfer(msg.sender, share);
        lastClaimedReward[token][msg.sender] = block.timestamp;

        emit RewardClaimed(msg.sender, token, share);
    }

    // --- Internal Functions ---
    function accrueInterest(address user, address token) internal {
        BorrowInfo storage info = borrowDetails[user][token];
        if (info.amount == 0) return;

        uint256 timeElapsed = block.timestamp - info.lastBorrowTimestamp;
        uint256 interest = (info.amount * ANNUAL_INTEREST_RATE * timeElapsed) / (100 * 365 days);

        info.interestAccrued += interest;
        info.lastBorrowTimestamp = block.timestamp;
    }

    function getCollateralValue(address user, address token) public view returns (uint256) {
        uint256 collateralAmount = userCollateral[user][token];
        uint256 price = priceOracle.getPrice(token);
        return (collateralAmount * price) / 1e18;
    }

    function addWhitelistedToken(address token) external onlyOwner {
        whitelistedTokens[token] = true;
    }

    function removeWhitelistedToken(address token) external onlyOwner {
        whitelistedTokens[token] = false;
    }
}
