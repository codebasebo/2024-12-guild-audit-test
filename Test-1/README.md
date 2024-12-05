

## Project: Lending and Borrowing Protocol
Build a  platform where users can:

Deposit tokens as collateral to borrow other tokens.
Execute flash loans to leverage arbitrage, liquidation opportunities, or other DeFi strategies.
Manage lending, borrowing, and collateralization parameters efficiently and securely.

This project should include concepts like:
 -   i. Interest rate calculations and collateral management
 -   ii. Flash loans, providing participants with a deep understanding of lending protocols.

## Task 1: Building

 ### Core Features to Implement
  **Deposit and Collateralization:**

 -  Users can deposit supported ERC20 tokens as collateral.
    Collateral values are assessed using a mock price oracle.
    **Borrowing:**

 -  Users can borrow supported tokens based on their collateral value.
    Enforce a collateralization ratio (e.g., 150%).
    Interest Accumulation:

    Apply a simple time-based interest model to borrowed tokens.

    **Flash Loans:**

 -  Enable users to borrow funds for a single transaction without collateral.
    The fee for flash loans is set at 0.09%. The fee is paid upon loan repayment. 
    Example: If a user borrows 10,000 DAI, the repayment amount will be 10,009 DAI (including the fee).

    **Liquidation**:

 -  The reward pool is funded by a percentage of platform fees and accumulated interest.
    Allow liquidation of under-collateralized positions.
    Reward liquidators with a portion of the collateral.

    **Platform Fees**:

 -  Charge a fee on interest earned and flash loan repayments.
    Distribute fees to token holders as rewards.

## Note: 
- DO NOT COPY AND PASTE AN EXISTING PROTOCOL OR YOU WILL BE DISQUALIFIED. 
- Write quality tests that you think covers every edge cases.
    