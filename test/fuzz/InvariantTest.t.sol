//SPDX-License-Identifier:MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {UnivalStableCoin} from "../../src/UnivalStableCoin.sol";
import {USCEngine} from "../../src/USCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployUSC} from "../../script/DeployUSC.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract InvariantTest is StdInvariant,Test{
    DeployUSC deployer;
    HelperConfig config;
    UnivalStableCoin usc;
    USCEngine engine;
    address weth;
    address wbtc;
    

    constructor(){
        deployer = new DeployUSC();
        (usc,engine,config) = deployer.run();
        (,,weth,wbtc,) = config.activeNetworkCongfig();
        targetContract(address(engine));
    }

    function invariant_protocolValueMustBeMoreThanTotalSupply() public view{
        uint totalSupply = usc.totalSupply();
        uint totalWethDeposited = IERC20(weth).balanceOf(address(engine));
        uint totalWbtcDeposited = IERC20(wbtc).balanceOf(address(engine));

        uint wethValue = engine.getUSDValue(weth,totalWethDeposited);
        uint wbtcValue = engine.getUSDValue(wbtc,totalWbtcDeposited);


        assert(wethValue + wbtcValue >= totalSupply);
        
        
    }
}