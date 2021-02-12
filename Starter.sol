// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
//pragma experimental ABIEncoderV2;

import "./Include.sol";

contract Starter is Configurable {
    using SafeMath for uint;
    using SafeERC20 for IERC20;
    
    address public currency;
    address public underlying;
    uint public price;
    uint public time;
    uint public totalPurchasedCurrency;
    mapping (address => uint) public purchasedCurrencyOf;
    bool public completed;
    uint public totalSettledUnderlying;
    mapping (address => uint) public settledUnderlyingOf;
    uint public settleRate;
    
    function __Starter_init(address governor_, address currency_, address underlying_, uint price_, uint time_) external initializer {
		__Governable_init_unchained(governor_);
		__Starter_init_unchained(currency_, underlying_, price_, time_);
	}
	
    function __Starter_init_unchained(address currency_, address underlying_, uint price_, uint time_) public governance {
        currency    = currency_;
        underlying  = underlying_;
        price       = price_;
        time        = time_;
    }
    
    function purchase(uint amount) external {
        require(now < time, 'expired');
        IERC20(currency).safeTransferFrom(msg.sender, address(this), amount);
        purchasedCurrencyOf[msg.sender] = purchasedCurrencyOf[msg.sender].add(amount);
        totalPurchasedCurrency = totalPurchasedCurrency.add(amount);
        emit Purchase(msg.sender, amount, totalPurchasedCurrency);
    }
    event Purchase(address indexed acct, uint amount, uint totalCurrency);
    
    function totalSettleable() public view  returns (bool completed_, uint amount, uint volume, uint rate) {
        return settleable(address(0));
    }
    
    function settleable(address acct) public view returns (bool completed_, uint amount, uint volume, uint rate) {
        completed_ = completed;
        if(completed_) {
            rate = settleRate;
            if(settledUnderlyingOf[acct] > 0)
                return (completed_, 0, 0, rate);
        } else {
            uint totalCurrency = IERC20(currency).balanceOf(address(this));
            uint totalUnderlying = IERC20(underlying).balanceOf(address(this));
            if(totalUnderlying.mul(price) < totalCurrency.mul(1e18))
                rate = totalUnderlying.mul(price).div(totalCurrency);
            else
                rate = 1 ether;
        }
        uint purchasedCurrency = acct == address(0) ? totalPurchasedCurrency : purchasedCurrencyOf[acct];
        uint settleAmount = purchasedCurrency.mul(rate).div(1e18);
        amount = purchasedCurrency.sub(settleAmount);
        volume = settleAmount.mul(1e18).div(price);
    }
    
    function settle() external {
        require(now >= time, "It's not time yet");
        (bool completed_, uint amount, uint volume, uint rate) = settleable(msg.sender);
        if(!completed_) {
            completed = true;
            settleRate = rate;
        }
        settledUnderlyingOf[msg.sender] = volume;
        totalSettledUnderlying = totalSettledUnderlying.add(volume);
        IERC20(currency).safeTransfer(msg.sender, amount);
        IERC20(underlying).safeTransfer(msg.sender, volume);
        emit Settle(msg.sender, amount, volume, rate);
    }
    event Settle(address indexed acct, uint amount, uint volume, uint rate);
    
    function withdrawable() public view returns (uint amt, uint vol) {
        if(!completed)
            return (0, 0);
        amt = IERC20(currency).balanceOf(address(this)).add(totalSettledUnderlying.mul(price).div(settleRate).mul(uint(1e18).sub(settleRate)).div(1e18)).sub(totalPurchasedCurrency.mul(uint(1e18).sub(settleRate)).div(1e18));
        vol = IERC20(underlying).balanceOf(address(this)).add(totalSettledUnderlying).sub(totalPurchasedCurrency.mul(settleRate).div(price));
    }
    
    function withdraw(address to, uint amount, uint volume) external governance {
        require(completed, "uncompleted");
        (uint amt, uint vol) = withdrawable();
        amount = Math.min(amount, amt);
        volume = Math.min(volume, vol);
        IERC20(currency).safeTransfer(to, amount);
        IERC20(underlying).safeTransfer(to, volume);
        emit Withdrawn(to, amount, volume);
    }
    event Withdrawn(address to, uint amount, uint volume);
}
