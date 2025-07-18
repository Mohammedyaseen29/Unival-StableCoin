// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/Mock/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";


contract HelperConfig is Script {

    uint8 public constant DECIMALS = 8;
    int public constant ETH_USD_PRICE = 2000e8;
    int public constant BTC_USD_PRICE = 1000e8;
    uint private constant DEFAULT_ANVIL_PRIVATEKEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;


    struct NetworkConfig {
        address weth_USD_PriceFeed;
        address wbtc_USD_PriceFeed;
        address weth;
        address wbtc;
        uint256 deployerKey;
    }
    NetworkConfig public activeNetworkCongfig;



    constructor(){
        if(block.chainid == 11155111){
            activeNetworkCongfig = getSepoliaEthConfig();
        } else {
            activeNetworkCongfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public view returns(NetworkConfig memory SepoliaConfig){
        SepoliaConfig = NetworkConfig({
            weth_USD_PriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            wbtc_USD_PriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            weth: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            wbtc: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
        return SepoliaConfig;
    }

    function getOrCreateAnvilEthConfig() public returns(NetworkConfig memory AnvilConfig){
        if(activeNetworkCongfig.weth_USD_PriceFeed != address(0)){
            return activeNetworkCongfig;
        }

        vm.startBroadcast();
        MockV3Aggregator ethUSDpriceFeed = new MockV3Aggregator(DECIMALS,ETH_USD_PRICE);
        ERC20Mock wethMock = new ERC20Mock("WETH","WETH",msg.sender,1000e8);
        ERC20Mock wbtcMock = new ERC20Mock("WBTC","WBTC",msg.sender,1000e8);
        MockV3Aggregator btcUSDpriceFeed = new MockV3Aggregator(DECIMALS,BTC_USD_PRICE);
        vm.stopBroadcast();


        AnvilConfig = NetworkConfig({
            weth_USD_PriceFeed:address(ethUSDpriceFeed),
            wbtc_USD_PriceFeed:address(btcUSDpriceFeed),
            weth:address(wethMock),
            wbtc:address(wbtcMock),
            deployerKey:DEFAULT_ANVIL_PRIVATEKEY
        });
        return AnvilConfig;
    }
}