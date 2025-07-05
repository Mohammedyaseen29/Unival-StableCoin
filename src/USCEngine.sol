//SPDX-Licence-Identifier: MIT
pragma solidity 0.8.20;

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
    error USCEngine__MintFailed();
    error USCEngine__HealthFactorFine();
    error USCEngine__HealthFactorNotImproved();
    error USCEngine__InsufficientUSCBalance();
    error USCEngine__InsufficientTokenBalance();
    error USCEngine__HealthFactorTooLow();
    error USCEngine__InsufficientMintedBalance();
    error USCEngine__NotEnoughCollateral();


    UnivalStableCoin private immutable I_USC;
    mapping (address token => address priceFeed) private s_priceFeeds;
    mapping (address user => mapping (address token => uint amount)) private s_collateralDeposited;
    mapping (address user => uint amountOfUSC) private s_totalUSCMinted;
    uint private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint private constant PRECISSION = 1e18;
    uint private constant LIQUIDATION_THRESHOLD = 50; //50% liquidation threshold
    uint private constant LIQUIDATION_PRECISION = 100;
    uint private constant MIN_HEALTH_FACTOR = 1e18;
    uint private constant LIQUIDATION_BONUS = 10;
    address[] private s_collateralTokens;


    event CollateralDeposited(address indexed user, address indexed token , uint indexed amount);
    event CollateralRedeemed(address indexed collateralReedeemedFrom,address indexed collateralReedeemedTo,address indexed token, uint amount);


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

    function DepositCollateral(address tokenAddress, uint amount) public MoreThanZero(amount) AllowedToken(tokenAddress) nonReentrant{
        bool success = IERC20(tokenAddress).transferFrom(msg.sender,address(this),amount);
        if(!success){
            revert USCEngine__TransferFailed();
        }
        s_collateralDeposited[msg.sender][tokenAddress] += amount;
        emit CollateralDeposited(msg.sender,tokenAddress,amount);
    }

    function mintUSC(uint amountofUSC) public nonReentrant MoreThanZero(amountofUSC){
        s_totalUSCMinted[msg.sender] += amountofUSC;
        revertIfHealthFactorBroken(msg.sender);
        bool minted = I_USC.mint(msg.sender,amountofUSC);
        if(!minted){
            revert USCEngine__MintFailed();
        }
    }

    function DepositCollateralAndMintUSC(address collateralTokenAddress,uint collateralAmount, uint amountToMint) external {
        DepositCollateral(collateralTokenAddress,collateralAmount);
        mintUSC(amountToMint);
    }
    
    function healthCheck(address user) private view returns(uint){
        if(s_totalUSCMinted[user] == 0) return type(uint).max;
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
    
    function getCollateralToken() public view returns(address[] memory){
        return s_collateralTokens;
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
    function getTokenAmountFromUSD(address token,uint USDAmountinWei) public view returns(uint){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (,int256 price,,,) = priceFeed.latestRoundData();
        return((USDAmountinWei * PRECISSION)/(uint(price)*ADDITIONAL_FEED_PRECISION));
        
    }

    function redeemCollateral(address collateralTokenAddress,uint CollateralAmount,address debtor,address liquidator)public MoreThanZero(CollateralAmount) nonReentrant{
        if(CollateralAmount > s_collateralDeposited[debtor][collateralTokenAddress]){
            revert USCEngine__InsufficientTokenBalance();
        }
        s_collateralDeposited[debtor][collateralTokenAddress] -= CollateralAmount;
        emit CollateralRedeemed(debtor,liquidator,collateralTokenAddress,CollateralAmount);

        bool success = IERC20(collateralTokenAddress).transfer(liquidator,CollateralAmount);
        if(!success){
            revert USCEngine__TransferFailed();
        }
        revertIfHealthFactorBroken(debtor);
    }

    function BurnUSC(uint amountOfUSC,address debtor,address liquidator) public MoreThanZero(amountOfUSC){
        if(amountOfUSC > s_totalUSCMinted[debtor]){
            revert USCEngine__InsufficientUSCBalance();
        }
        s_totalUSCMinted[debtor] -= amountOfUSC;
        bool success = I_USC.transferFrom(liquidator,address(this),amountOfUSC);
        if(!success){
            revert USCEngine__TransferFailed();
        }
        I_USC.burn(amountOfUSC);
    }
    function redeemReward(address collateralTokenAddress,uint collateralAmount,uint AmountOfUSCtoBurn,address user)public{
        BurnUSC(AmountOfUSCtoBurn,user,msg.sender);
        redeemCollateral(collateralTokenAddress,collateralAmount,user,msg.sender);
    }
    function liquidate(address collateral,address user,uint debtToCover) external MoreThanZero(debtToCover) nonReentrant{
        uint startingHealthFactor = healthCheck(user);
        if(startingHealthFactor > MIN_HEALTH_FACTOR){
            revert USCEngine__HealthFactorFine();
        }
        uint totalAmountToCoverDebt = getTokenAmountFromUSD(collateral,debtToCover);
        uint bonusCollateral = (totalAmountToCoverDebt * LIQUIDATION_BONUS)/LIQUIDATION_PRECISION;
        uint totalCollateralRedeemed = totalAmountToCoverDebt + bonusCollateral;
        redeemReward(collateral,totalCollateralRedeemed,debtToCover,user);

        uint endingHealthFactor = healthCheck(user);
        if(endingHealthFactor <= MIN_HEALTH_FACTOR){
            revert USCEngine__HealthFactorNotImproved();
        }

        revertIfHealthFactorBroken(msg.sender);
    }
    function redeemCollateralAsUser(address collateralTokenAddress,uint256 collateralAmount,uint256 uscToBurn) external nonReentrant MoreThanZero(collateralAmount) MoreThanZero(uscToBurn) {
        uint256 startingHealthFactor = healthCheck(msg.sender);
        if (startingHealthFactor < MIN_HEALTH_FACTOR) {
            revert USCEngine__HealthFactorTooLow();
        }

        if (uscToBurn > s_totalUSCMinted[msg.sender]) {
            revert USCEngine__InsufficientMintedBalance();
        }

        if (collateralAmount > s_collateralDeposited[msg.sender][collateralTokenAddress]) {
            revert USCEngine__NotEnoughCollateral();
        }

        // Burn USC from sender
        s_totalUSCMinted[msg.sender] -= uscToBurn;
        bool success = I_USC.transferFrom(msg.sender, address(this), uscToBurn);
        if (!success) revert USCEngine__TransferFailed();
        I_USC.burn(uscToBurn);

        // Return collateral
        s_collateralDeposited[msg.sender][collateralTokenAddress] -= collateralAmount;
        success = IERC20(collateralTokenAddress).transfer(msg.sender, collateralAmount);
        if (!success) revert USCEngine__TransferFailed();

        // Ensure HF remains healthy after redemption
        revertIfHealthFactorBroken(msg.sender);
    }
    function getMaxLiquidatableDebt(address user) public view returns (uint256) {
        uint256 hf = healthCheck(user);
        if (hf >= MIN_HEALTH_FACTOR) return 0;

        uint256 debt = s_totalUSCMinted[user];
        return (debt * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
    }
    function getLiquidationQuote(address user,address collateralToken) public view returns (uint256 uscToRepay,uint256 collateralToRedeem,uint256 bonusCollateral,uint256 healthFactorBefore,uint256 healthFactorAfter) {
        healthFactorBefore = healthCheck(user);
        if (healthFactorBefore >= MIN_HEALTH_FACTOR) {
            return (0, 0, 0, healthFactorBefore, healthFactorBefore);
        }

        uscToRepay = getMaxLiquidatableDebt(user);
        uint256 baseCollateral = getTokenAmountFromUSD(collateralToken, uscToRepay);
        bonusCollateral = (baseCollateral * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        collateralToRedeem = baseCollateral + bonusCollateral;

        // Simulate state after liquidation
        uint256 newDebt = s_totalUSCMinted[user] - uscToRepay;
        uint256 newCollateral = s_collateralDeposited[user][collateralToken] - collateralToRedeem;

        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[collateralToken]);
        (, int256 price,,,) = priceFeed.latestRoundData();

        uint256 collateralValue = (uint256(price) * newCollateral * LIQUIDATION_THRESHOLD)/ (1e8 * LIQUIDATION_PRECISION);

        if (newDebt == 0) {
            healthFactorAfter = type(uint256).max; // Infinity
        } else {
            healthFactorAfter = (collateralValue * 1e18) / newDebt;
        }
    }




}   