// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {AbstractCallback} from "../lib/reactive-lib/src/abstract-base/AbstractCallback.sol";

/// @title Loan.sol
/// @author Brian Fontenot
/// @notice Contract to issue and repay loans on the destination chain
contract Loan is AbstractCallback { 
    uint256 constant public LOAN_FEE = 3;

    address public immutable i_owner;

    mapping(address => uint256) public s_addressToLoanAmount;

    constructor(address callbackAddress) AbstractCallback(callbackAddress) { 
        i_owner = msg.sender;
    }

    event Issue(
        address origin,
        address caller,
        address user,
        uint256 amount
    );

    event Repay(
        address origin,
        address user,
        uint256 amount,
        uint256 chainId
    );

    error Loan__WithdrawFailed();

    error Loan__Balance();

    error Loan__IssueFailed();

    error Loan__FeeFailed();

    error Loan__NotOwner();

    error Loan__LoanAmountExceeded();

    error Loan__IncorrectAmount();

     modifier onlyOwner() {
        if (msg.sender != i_owner) { 
            revert Loan__NotOwner(); 
        }
        _;
    }

    /// @notice Issues a loan when collateral is deposited
    /// @dev When the collateral is deposited on the origin chain, a callback will be emitted
    /// to call this function to issue a loan on the destination chain
    /// @param sender Address of the sender which will be the reactive contract address
    /// @param user Address of the user taking the loan
    /// @param amount Amount of the loan
    function issue(
        address sender,
        address user, 
        uint256 amount
    ) external authorizedSenderOnly { 
        if (sender != i_owner) { 
            revert Loan__NotOwner();
        }

        uint256 fee = (amount * LOAN_FEE) / 1000;
        uint256 amountAfterFee = amount - fee;

        s_addressToLoanAmount[user] += amountAfterFee;

        (bool loanSuccess, ) = user.call{value: amountAfterFee}("");

        if (!loanSuccess) {
            revert Loan__IssueFailed();
        }

        (bool feeSuccess, ) = i_owner.call{value: fee}("");

         if (!feeSuccess) {
            revert Loan__FeeFailed();
        }
        
        emit Issue(
            tx.origin, 
            msg.sender, 
            user, 
            amount
        );
    }

    /// @notice Repays a loan which releases the collateral deposited
    /// @dev When the loan is repayed on the destination chain, a callback will be emitted
    /// to release the collaterall deposited on the origin chain
    /// @param amount Amount of the loan to repay
    function repay(uint256 amount) external payable { 
        if (amount > s_addressToLoanAmount[msg.sender]) { 
            revert Loan__LoanAmountExceeded();
        }
        if (msg.value != amount) { 
            revert Loan__IncorrectAmount();
        }

        s_addressToLoanAmount[msg.sender] -= amount;

        emit Repay( 
            address(this),
            msg.sender, 
            amount,
            block.chainid
        );
    }

    /// @notice Withdraws specified amount of the contract balance to the owner
    /// @param amount Amount of the contract balance to withdraw 
    function withdraw(uint256 amount) external onlyOwner {
        if (amount > address(this).balance) {
            revert Loan__Balance();
        }

        (bool success, ) = i_owner.call{value: amount}("");

        if (!success) { 
            revert Loan__WithdrawFailed();
        }
    } 
}