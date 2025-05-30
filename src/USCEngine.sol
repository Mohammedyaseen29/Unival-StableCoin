//SPDX-Licence-Identifier: MIT

import {UnivalStableCoin} from "./UnivalStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract USCEngine is ReentrancyGuard{

    error USCEngine__TokenAddressesAndPriceFeedAddressesLengthMismatch();
    error USCEngine__TokenNotAllowed(address token);
    error USCEngine__AmountMustBeMoreThanZero();
    error USCEngine__TransferFailed();


    UnivalStableCoin private immutable I_USC;
    mapping (address token => address priceFeed) private s_priceFeeds;
    mapping (address user => mapping (address token => uint amount)) private s_collateralDeposited;


    event CollateralDeposited(address indexed user, address indexed token , uint indexed amount);


    modifier AllowedToken(address token) {
        if(s_priceFeeds[token] == address(0)){
            revert USCEngine__TokenNotAllowed(token);
        }
        _;
    }
    modifier MoreThanZero(uint amount){
        if(amount <= 0){
            revert USCEngine__AmountMustBeMoreThanZero();
        }
        _;
    }

    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses,address USCAddress){
        if(tokenAddresses.length != priceFeedAddresses.length){
            revert USCEngine__TokenAddressesAndPriceFeedAddressesLengthMismatch();
        }
        for(uint i = 0; i<tokenAddresses.length;i++){
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
        }
        I_USC = UnivalStableCoin(USCAddress);
        

    }

    function DepositCollateral(address tokenAddress, uint amount) external MoreThanZero(amount) AllowedToken(tokenAddress) nonReentrant{
        s_collateralDeposited[msg.sender][tokenAddress] += amount;
        emit CollateralDeposited(msg.sender,tokenAddress,amount);
        bool success = IERC20(tokenAddress).transferFrom(msg.sender,address(this),amount);
        if(!success){
            revert USCEngine__TransferFailed();
        }

    }
}