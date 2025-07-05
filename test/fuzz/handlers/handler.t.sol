//SPDX-License-Identifier:MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {UnivalStableCoin} from "../../../src/UnivalStableCoin.sol";
import {USCEngine} from "../../../src/USCEngine.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract Handler is Test{

    UnivalStableCoin usc;
    USCEngine engine;
    ERC20Mock weth;
    ERC20Mock wbtc;
    uint MAX_DEPOSIT_SIZE = type(uint96).max;

    constructor(UnivalStableCoin _usc,USCEngine _engine){
        usc = _usc;
        engine = _engine;
        address[] memory collateralTokens = engine.getCollateralToken();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);
    }

    function getCollateralFromSeed(uint seed) private view returns(ERC20Mock){
        return seed % 2 == 0 ? weth : wbtc;
    }

    function depositCollateral(uint seed,uint amount) public{
        amount = bound(amount,1,MAX_DEPOSIT_SIZE);
        ERC20Mock collateral = getCollateralFromSeed(seed);

        vm.startPrank(msg.sender);
        collateral.mint(msg.sender,amount);
        collateral.approve(address(engine),amount);
        engine.DepositCollateral(address(collateral),amount);
        vm.stopPrank();
    }

    function redeemCollateral(uint seed,uint amount) public{
        // amount = bound(amount,1,MAX_DEPOSIT_SIZE);
        // ERC20Mock collateral = getCollateralFromSeed(seed);
    }
}