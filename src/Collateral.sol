// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {AbstractCallback} from "../lib/reactive-lib/src/abstract-base/AbstractCallback.sol";

/// @title Collateral.sol
/// @author Brian Fontenot
/// @notice Contract to manage collateral deposited and released on the origin chain
contract Collateral is AbstractCallback { 
    uint256 constant public MINIMUM_DEPOSIT = 0.001 ether;

    address public immutable i_owner;

    mapping(address => uint256) public s_addressToCollateralAmount;

    constructor(address callbackAddress) AbstractCallback(callbackAddress) { 
        i_owner = msg.sender;
    }
    
    event DepositCallback(
        address origin,
        address user,
        uint256 amount,
        uint256 chainId
    );

     event Release(
        address origin,
        address caller,
        address user,
        uint256 amount
    );

    error Collateral__NotOwner();

    error Collateral__InsufficientDeposit();

    error Collateral__WithdrawFailed();

    error Collateral__Balance();

    error Collateral__ReleaseFailed();

    modifier onlyOwner() {
        if (msg.sender != i_owner) { 
            revert Collateral__NotOwner(); 
        }
        _;
    }
    
    /// @notice Deposits collateral on the origin chain
    /// @param amount The amount of collateral to deposit
    /// @dev When a user deposits collateral on the origin chain, a callback 
    /// from the reactive contract issues a loan on the destination chain
    function deposit(uint256 amount) external payable { 
        if (amount < MINIMUM_DEPOSIT) { 
            revert Collateral__InsufficientDeposit();
        }

        s_addressToCollateralAmount[msg.sender] += amount;  

        emit DepositCallback({
            origin: address(this),
            user: msg.sender,
            amount: amount,
            chainId: block.chainid
        });
    }

    /// @notice Releases collateral back to the user on the origin chain
    /// @param sender Sender's address
    /// @param user User's address
    /// @param amount The amount of collateral to release back to the user
    /// @dev When a user repays a loan on the destination chain, a callback from 
    /// the reactive contract releases collateral back to the user on the origin chain
    function release(
        address sender, 
        address user, 
        uint256 amount
    ) external authorizedSenderOnly { 
        if (sender != i_owner) { 
            revert("Sender Is Not Owner");
        }

        s_addressToCollateralAmount[user] -= amount;

        (bool success, ) = user.call{value: amount}("");

        if (!success) { 
            revert Collateral__ReleaseFailed();
        }

        emit Release(
            tx.origin,
            msg.sender,
            user,
            amount
        );
    }

    /// @notice Withdraws specified amount of the contract balance to the owner
    /// @param amount Amount of the contract balance to withdraw 
    function withdraw(uint256 amount) external onlyOwner {
        if (amount > address(this).balance) {
            revert Collateral__Balance();
        }

        (bool success, ) = i_owner.call{value: amount}("");

        if (!success) { 
            revert Collateral__WithdrawFailed();
        }
    }
}