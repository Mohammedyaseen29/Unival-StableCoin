// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;


import {Script} from "forge-std/Script.sol";
import {UnivalStableCoin} from "../src/UnivalStableCoin.sol";
import {USCEngine} from "../src/USCEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployUSC is Script {
    address[] public tokenAddress;
    address[] public priceFeedAddress; 

    function run() external returns(UnivalStableCoin,USCEngine){
        HelperConfig config = new HelperConfig();
        (address weth_USD_PriceFeed, address wbtc_USD_PriceFeed,address weth,address wbtc,uint256 deployerKey) = config.activeNetworkCongfig();
        tokenAddress = [weth,wbtc];
        priceFeedAddress = [weth_USD_PriceFeed,wbtc_USD_PriceFeed];

        vm.startBroadcast();
        UnivalStableCoin usc = new UnivalStableCoin();
        USCEngine engine = new USCEngine(tokenAddress,priceFeedAddress,usc);
        vm.stopBroadcast();
        return(usc,engine);
    }
}