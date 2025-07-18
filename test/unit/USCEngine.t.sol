// SPDX-License-Identifier:MIT

pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {USCEngine} from "../../src/USCEngine.sol";
import {UnivalStableCoin} from "../../src/UnivalStableCoin.sol";
import {DeployUSC} from "../../script/DeployUSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract USCEngineTest is Test{
    UnivalStableCoin usc;
    USCEngine engine;
    DeployUSC deployer;
    HelperConfig config;
    address weth_USD_PriceFeed;
    address weth;
    address USER = makeAddr("user");
    uint public constant AMOUNT_COLLATERAL = 10 ether;
    uint public constant STARTING_ERC20_BALANCE = 10 ether;

    function setUp() public{
        deployer = new DeployUSC();
        (usc,engine,config) = deployer.run();
        (weth_USD_PriceFeed, ,weth, , ) = config.activeNetworkCongfig();
        ERC20Mock(weth).mint(USER,STARTING_ERC20_BALANCE);
    }
    function testGetUsdValue() public view{
        //20e18 * 2000/ETH = 40,000e18;
        uint ethAmount = 20e18;
        uint expectedAmount = 40000e18;
        uint actualAmount = engine.getUSDValue(weth,ethAmount);
        assertEq(expectedAmount,actualAmount);
    }
    function testRevertsIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine),AMOUNT_COLLATERAL);
        vm.expectRevert(USCEngine.USCEngine__AmountMustBeMoreThanZero.selector);
        engine.DepositCollateral(weth,0);
        vm.stopPrank();
    }


    
}