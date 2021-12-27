pragma solidity ^0.6.10;
pragma experimental "ABIEncoderV2";

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/SafeCast.sol";

import { IController } from "./interfaces/IController.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISOFIProxyAdapter } from "./interfaces/ISOFIProxyAdapter.sol";
import { IIntegrationRegistry } from "./interfaces/IIntegrationRegistry.sol";
import { Invoke } from "./lib/Invoke.sol";
import { IPortfolio } from "./interfaces/IPortfolio.sol";
import { ModuleBase } from "./lib/ModuleBase.sol";
import { Position } from "./lib/Position.sol";
import { PreciseUnitMath } from "./lib/PreciseUnitMath.sol";


contract ManagerModule is ModuleBase, ReentrancyGuard {
    using SafeCast for int256;
    using SafeMath for uint256;

    using Invoke for IPortfolio;
    using Position for IPortfolio;
    using PreciseUnitMath for uint256;

    

    struct TradeInfo {
        IPortfolio portfolio;                             // Instance of portfolio
        ISOFIProxyAdapter exchangeAdapter;               // Instance of exchange adapter contract
        address router;                                 // Instance of exchange adapter contract
        address sendToken;                              // Address of token being sold
        address receiveToken;                           // Address of token being bought
        uint256 portfolioTotalSupply;                   // Total supply of portfolio in Precise Units (10^18)
        uint256 totalSendQuantity;                      // Total quantity of sold token (position unit x total supply)
        uint256 totalMinReceiveQuantity;                // Total minimum quantity of token to receive back
        uint256 preTradeSendTokenBalance;               // Total initial balance of token being sold
        uint256 preTradeReceiveTokenBalance;            // Total initial balance of token being bought
    }


    event ComponentExchanged(
        IPortfolio indexed _portfolio,
        address indexed _sendToken,
        address indexed _receiveToken,
        ISOFIProxyAdapter _exchangeAdapter,
        uint256 _totalSendAmount,
        uint256 _totalReceiveAmount
    );



    constructor(IController _controller) public ModuleBase(_controller) {}


    function initialize(
        IPortfolio _portfolio
    )
        external
        onlyValidAndPendingPortfolio(_portfolio)
        onlyPortfolioManager(_portfolio, msg.sender)
    {
        _portfolio.initializeModule();
    }

  
    function trade(
        IPortfolio _portfolio,
        string memory _exchangeName,
        address _router,
        address _sendToken,
        uint256 _sendQuantity,
        address _receiveToken,
        uint256 _minReceiveQuantity,
        bytes memory _data
    )
        external
        nonReentrant
        onlyManagerAndValidPortfolio(_portfolio)
    {
        TradeInfo memory tradeInfo = _createTradeInfo(
            _portfolio,
            _exchangeName,
            _router,
            _sendToken,
            _receiveToken,
            _sendQuantity,
            _minReceiveQuantity
        );

        _validatePreTradeData(tradeInfo, _sendQuantity);

        _executeTrade(tradeInfo, _data);

        _validatePostTrade(tradeInfo);


        (
            uint256 netSendAmount,
            uint256 netReceiveAmount
        ) = _updatePortfolioPositions(tradeInfo);

        emit ComponentExchanged(
            _portfolio,
            _sendToken,
            _receiveToken,
            tradeInfo.exchangeAdapter,
            netSendAmount,
            netReceiveAmount
        );
    }


    function removeModule() external override {}

 
    function _createTradeInfo(
        IPortfolio _portfolio,
        string memory _exchangeName,
        address _router,
        address _sendToken,
        address _receiveToken,
        uint256 _sendQuantity,
        uint256 _minReceiveQuantity
    )
        internal
        view
        returns (TradeInfo memory)
    {
        TradeInfo memory tradeInfo;

        tradeInfo.portfolio = _portfolio;

        tradeInfo.exchangeAdapter = ISOFIProxyAdapter(getAndValidateAdapter(_exchangeName));

        tradeInfo.router = _router;

        tradeInfo.sendToken = _sendToken;
        tradeInfo.receiveToken = _receiveToken;

        tradeInfo.portfolioTotalSupply = _portfolio.totalSupply();

        tradeInfo.totalSendQuantity = Position.getDefaultTotalNotional(tradeInfo.portfolioTotalSupply, _sendQuantity);

        tradeInfo.totalMinReceiveQuantity = Position.getDefaultTotalNotional(tradeInfo.portfolioTotalSupply, _minReceiveQuantity);

        tradeInfo.preTradeSendTokenBalance = IERC20(_sendToken).balanceOf(address(_portfolio));
        tradeInfo.preTradeReceiveTokenBalance = IERC20(_receiveToken).balanceOf(address(_portfolio));

        return tradeInfo;
    }


    function _validatePreTradeData(TradeInfo memory _tradeInfo, uint256 _sendQuantity) internal view {
        require(_tradeInfo.totalSendQuantity > 0, "Token to sell must be nonzero");

        require(
            _tradeInfo.portfolio.hasSufficientDefaultUnits(_tradeInfo.sendToken, _sendQuantity),
            "Unit cant be greater than existing"
        );
    }

    function _executeTrade(
        TradeInfo memory _tradeInfo,
        bytes memory _data
    )
        internal
    {
        
        _tradeInfo.portfolio.invokeApprove(
            _tradeInfo.sendToken,
            _tradeInfo.exchangeAdapter.getSpender(),
            _tradeInfo.totalSendQuantity
        );

        (
            address targetExchange,
            uint256 callValue,
            bytes memory methodData
        ) = _tradeInfo.exchangeAdapter.getTradeCalldata(
            _tradeInfo.router,
            _tradeInfo.sendToken,
            _tradeInfo.receiveToken,
            _tradeInfo.totalSendQuantity,
            _tradeInfo.totalMinReceiveQuantity,
            address(_tradeInfo.portfolio)
        );

        _tradeInfo.portfolio.invoke(targetExchange, callValue, methodData);
    }


    function _validatePostTrade(TradeInfo memory _tradeInfo) internal view returns (uint256) {
        uint256 exchangedQuantity = IERC20(_tradeInfo.receiveToken)
            .balanceOf(address(_tradeInfo.portfolio))
            .sub(_tradeInfo.preTradeReceiveTokenBalance);

        require(
            exchangedQuantity >= _tradeInfo.totalMinReceiveQuantity,
            "Slippage greater than allowed"
        );

        return exchangedQuantity;
    }


    function _updatePortfolioPositions(TradeInfo memory _tradeInfo) internal returns (uint256, uint256) {
        (uint256 currentSendTokenBalance,,) = _tradeInfo.portfolio.calculateAndEditDefaultPosition(
            _tradeInfo.sendToken,
            _tradeInfo.portfolioTotalSupply,
            _tradeInfo.preTradeSendTokenBalance
        );

        (uint256 currentReceiveTokenBalance,,) = _tradeInfo.portfolio.calculateAndEditDefaultPosition(
            _tradeInfo.receiveToken,
            _tradeInfo.portfolioTotalSupply,
            _tradeInfo.preTradeReceiveTokenBalance
        );

        return (
            _tradeInfo.preTradeSendTokenBalance.sub(currentSendTokenBalance),
            currentReceiveTokenBalance.sub(_tradeInfo.preTradeReceiveTokenBalance)
        );
    }
}