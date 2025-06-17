//SPDX-License-Identifier:MIT
pragma solidity 0.8.20;

import {ERC20,ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
/*
 * @title Unival StableCoin
 * @author Mohammed Yaseen
 * Collateral: Exogenous
 * Minting (Stability Mechanism): Decentralized (Algorithmic)
 * Value (Relative Stability): Anchored (Pegged to USD)
 * Collateral Type: Crypto
 *
* This is the contract meant to be owned by USCEngine. It is a ERC20 token that can be minted and burned by the
USCEngine smart contract.
 */

contract UnivalStableCoin is ERC20Burnable, Ownable {
    error UnivalStableCoin__AmountMustBeMoreThanZero();
    error UnivalStableCoin__InsufficientBalance();
    error UnivalStableCoin__InvalidAddress();

    constructor() ERC20("Unival Stable Coin", "USC") Ownable(msg.sender){

    }

    function burn(uint _amount) public override onlyOwner{
        uint balance = balanceOf(msg.sender);
        if(_amount <= 0){
            revert UnivalStableCoin__AmountMustBeMoreThanZero();
        }
        if(_amount > balance){
            revert UnivalStableCoin__InsufficientBalance();
        }
        super.burn(_amount);
    }
    function mint(address _to, uint _amount) external onlyOwner returns(bool){
        if(_to == address(0)){
            revert UnivalStableCoin__InvalidAddress();
        }
        if(_amount <= 0){
            revert UnivalStableCoin__AmountMustBeMoreThanZero();
        }
        _mint(_to,_amount);
        return true;
    }
}