//SPDX-Licence-Identifier: MIT

import {UnivalStableCoin} from "./UnivalStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";


contract USCEngine is ReentrancyGuard{

    error USCEngine__TokenAddressesAndPriceFeedAddressesLengthMismatch();
    error USCEngine__TokenNotAllowed(address token);
    error USCEngine__AmountMustBeMoreThanZero();
    error USCEngine__TransferFailed();
    error USCEngine__HealthFactorBroken(uint healthFactor);


    UnivalStableCoin private immutable I_USC;
    mapping (address token => address priceFeed) private s_priceFeeds;
    mapping (address user => mapping (address token => uint amount)) private s_collateralDeposited;
    mapping (address user => uint amountOfUSC) private s_totalUSCMinted;
    uint private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint private constant PRECISSION = 1e18;
    uint private constant LIQUIDATION_THRESHOLD = 50; //50% liquidation threshold
    uint private constant LIQUIDATION_PRECISION = 100;
    uint private constant MIN_HEALTH_FACTOR = 1e18;
    address[] private s_collateralTokens;


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
            s_collateralTokens.push(tokenAddresses[i]);
        }
        I_USC = UnivalStableCoin(USCAddress);
        

    }

    function DepositCollateral(address tokenAddress, uint amount) external MoreThanZero(amount) AllowedToken(tokenAddress) nonReentrant{
        bool success = IERC20(tokenAddress).transferFrom(msg.sender,address(this),amount);
        if(!success){
            revert USCEngine__TransferFailed();
        }
        s_collateralDeposited[msg.sender][tokenAddress] += amount;
        emit CollateralDeposited(msg.sender,tokenAddress,amount);

    }

    function mintUSC(uint amountofUSC) public nonReentrant MoreThanZero(amountofUSC){
        s_totalUSCMinted[msg.sender] += amountofUSC;
    }

    function healthCheck(address user) private view returns(uint){
        (uint mintedUSCToken,uint totalCollateralInUSD) = getUserInformation(user);
        uint CollateralThresholdAmount = (totalCollateralInUSD * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (CollateralThresholdAmount * PRECISSION) / mintedUSCToken;
    }
    function revertIfHealthFactorBroken(address user) internal view{
        uint healthFactor = healthCheck(user);
        if(healthFactor < MIN_HEALTH_FACTOR){
            revert USCEngine__HealthFactorBroken(healthFactor);
        }
    }


    function getUserInformation(address user) private view returns(uint mintedUSCToken,uint totalCollateralInUSD){
        mintedUSCToken = s_totalUSCMinted[user];
        totalCollateralInUSD = getCollateralValueOfUser(user);
        return (mintedUSCToken,totalCollateralInUSD);
    }
    


    function getCollateralValueOfUser(address user) public view returns(uint collaterValueInUSD){
        for(uint i = 0; i<s_collateralTokens.length;i++){
            address token = s_collateralTokens[i];
            uint amount = s_collateralDeposited[user][token];
            collaterValueInUSD += getUSDValue(token,amount);
        }
        return collaterValueInUSD;
    }

    function getUSDValue(address token,uint amount) public view returns(uint){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (,int256 price,,,)= priceFeed.latestRoundData();
        return ((uint(price)*ADDITIONAL_FEED_PRECISION)*amount)/PRECISSION;
    }
}   
