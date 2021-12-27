pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IUniswapV2Factory } from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import { IUniswapV2Router02 } from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import { Math } from "@openzeppelin/contracts/math/Math.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { IPortfolioModule } from "./interfaces/IPortfolioModule.sol";
import { IController } from "./interfaces/IController.sol";
import { IPortfolio } from "./interfaces/IPortfolio.sol";
import { ISOFIProxy } from "./interfaces/ISOFIProxy.sol";
import { IWETH } from "./interfaces/IWETH.sol";
import { PreciseUnitMath } from "./lib/PreciseUnitMath.sol";
import { UniSushiV2Library } from "./lib/UniSushiV2Library.sol";



contract SOFITrading is ReentrancyGuard {

    using Address for address payable;
    using SafeMath for uint256;
    using PreciseUnitMath for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for IPortfolio;

    uint256 constant private MAX_UINT96 = 2**96 - 1;

    address public WETH;

    ISOFIProxy public immutable sofiProxy;
    IController public immutable controller;
    IPortfolioModule public immutable portfolioModule;


    event TradingBuy(
        address indexed _buyer,
        address indexed _portfolio, 
        address indexed _inputToken,
        uint256 _amountWETHSpent,
        uint256 _amountPortfolio
    );

    event TradingSell(
        address indexed _seller,
        address indexed _portfolio,
        address indexed _outputToken,
        uint256 _amountPortfolio,
        uint256 _amountOutputToken
    );

    modifier isPortfolio(IPortfolio _portfolio) {
         require(controller.isPortfolio(address(_portfolio)), "SOFITrading: INVALID Portfolio");
         _;
    }

    constructor(
        address _weth,
        ISOFIProxy _sofiProxy,
        IController _controller,
        IPortfolioModule _portfolioModule
    )
        public
    {   
        sofiProxy = _sofiProxy;

        controller = _controller;
        portfolioModule = _portfolioModule;

        WETH = _weth;
    }


    function approveToken(IERC20 _token) public {
        _safeApprove(_token, address(sofiProxy), MAX_UINT96);
        _safeApprove(_token, address(portfolioModule), MAX_UINT96);
    }

    receive() external payable {
        require(msg.sender == WETH, "SOFITrading: Direct deposits not allowed");
    }

    function approveTokens(IERC20[] calldata _tokens) external {
        for (uint256 i = 0; i < _tokens.length; i++) {
            approveToken(_tokens[i]);
        }
    }


    function buyExactPortfolioFromETH(
        IPortfolio _portfolio,
        uint256 _amountPortfolio
    )
        isPortfolio(_portfolio)
        external
        payable
        nonReentrant
        returns (uint256)
    {
        require(msg.value > 0 && _amountPortfolio > 0, "SOFITrading: INVALID INPUTS");

        IWETH(WETH).deposit{value: msg.value}();

        uint256 amountWETHSpent = _buyExactPortfolioFromWETH(_portfolio, _amountPortfolio, msg.value);

        uint256 amountEthReturn = msg.value.sub(amountWETHSpent);

        if (amountEthReturn > 0) {
            IWETH(WETH).withdraw(amountEthReturn);
            (payable(msg.sender)).sendValue(amountEthReturn);
        }

        emit TradingBuy(msg.sender, address(_portfolio), address(0), amountWETHSpent, _amountPortfolio);
        return amountEthReturn;
    }


    function buyExactPortfolioFromToken(
        IPortfolio _portfolio,
        IERC20 _inputToken,
        uint256 _amountPortfolio,
        uint256 _maxAmountInputToken
    )
        isPortfolio(_portfolio)
        external
        nonReentrant
        returns (uint256)
    {
        require(_amountPortfolio > 0 && _maxAmountInputToken > 0, "SOFITrading: INVALID INPUTS");

        _inputToken.safeTransferFrom(msg.sender, address(this), _maxAmountInputToken);

        uint256 initETHAmount = address(_inputToken) == WETH
            ? _maxAmountInputToken
            : _tradeTokenByExactToken(_inputToken, WETH, _maxAmountInputToken);

        uint256 amountWETHSpent = _buyExactPortfolioFromWETH(_portfolio, _amountPortfolio, initETHAmount);

        uint256 amountEthReturn = initETHAmount.sub(amountWETHSpent);
        if (amountEthReturn > 0) {
            IWETH(WETH).withdraw(amountEthReturn);
            (payable(msg.sender)).sendValue(amountEthReturn);
        }

        emit TradingBuy(msg.sender, address(_portfolio), address(_inputToken), amountWETHSpent, _amountPortfolio);
        return amountEthReturn;
    }


    function sellExactPortfolioForETH(
        IPortfolio _portfolio,
        uint256 _amountPortfolio,
        uint256 _minEthOut
    )
        isPortfolio(_portfolio)
        external
        nonReentrant
        returns (uint256)
    {
        require(_amountPortfolio > 0, "SOFITrading: INVALID INPUTS");

        address[] memory components = _portfolio.getComponents();
        (
            uint256 totalEth,
            uint256[] memory amountComponents,
            address[] memory routers
        ) =  _getAmountETHForRedemption(_portfolio, components, _amountPortfolio);

        require(totalEth > _minEthOut, "SOFITrading: INSUFFICIENT_OUTPUT_AMOUNT");

        _redeemExactPortfolio(_portfolio, _amountPortfolio);

        uint256 amountEthOut = _liquidateComponentsForWETH(components, amountComponents, routers);

        IWETH(WETH).withdraw(amountEthOut);
        (payable(msg.sender)).sendValue(amountEthOut);

        emit TradingSell(msg.sender, address(_portfolio), address(0), _amountPortfolio, amountEthOut);
        return amountEthOut;
    }


    function sellExactPortfolioForToken(
        IPortfolio _portfolio,
        address _outputToken,
        uint256 _amountPortfolio,
        uint256 _minOutputReceive
    )
        isPortfolio(_portfolio)
        external
        nonReentrant
        returns (uint256)
    {
        require(_amountPortfolio > 0, "SOFITrading: INVALID INPUTS");

        address[] memory components = _portfolio.getComponents();
        (
            uint256 totalEth,
            uint256[] memory amountComponents,
            address[] memory routers
        ) =  _getAmountETHForRedemption(_portfolio, components, _amountPortfolio);

        _redeemExactPortfolio(_portfolio, _amountPortfolio);

        uint256 outputAmount;
        uint256 outputWETHAmount = _liquidateComponentsForWETH(components, amountComponents, routers);

        if (_outputToken == WETH) {
            outputAmount = outputWETHAmount;
        } else {
            outputAmount = _tradeTokenByExactToken(IWETH(WETH), _outputToken, outputWETHAmount);
        }

        require(outputAmount > _minOutputReceive, "SOFITrading: INSUFFICIENT_OUTPUT_AMOUNT");

        IERC20(_outputToken).safeTransfer(msg.sender, outputAmount);
        emit TradingSell(msg.sender, address(_portfolio), _outputToken, _amountPortfolio, outputAmount);
        return outputAmount;
    }


    function _redeemExactPortfolio(IPortfolio _portfolio, uint256 _amount) internal returns (uint256) {
        _portfolio.safeTransferFrom(msg.sender, address(this), _amount);
        portfolioModule.redeem(_portfolio, _amount, address(this));
    }


    function _liquidateComponentsForWETH(address[] memory _components, uint256[] memory _amountComponents, address[] memory _routers)
        internal
        returns (uint256)
    {
        uint256 sumEth = 0;
        for (uint256 i = 0; i < _components.length; i++) {
            sumEth = _routers[i] == address(0)
                ? sumEth.add(_amountComponents[i])
                : sumEth.add(sofiProxy.tradeTokenByExactToken(_routers[i], _components[i], WETH, _amountComponents[i], 0, address(this)));
        }
        return sumEth;
    }


    function _getAmountETHForRedemption(IPortfolio _portfolio, address[] memory _components, uint256 _amountPortfolio)
        internal
        view
        returns (uint256, uint256[] memory, address[] memory)
    {
        uint256 sumEth = 0;
        uint256 amountEth = 0;

        uint256[] memory amountComponents = new uint256[](_components.length);
        address[] memory routers = new address[](_components.length);

        for (uint256 i = 0; i < _components.length; i++) {
            require(
                _portfolio.getExternalPositionModules(_components[i]).length == 0,
                "SOFITrading: EXTERNAL_POSITIONS_NOT_ALLOWED"
            );

            uint256 unit = uint256(_portfolio.getDefaultPositionRealUnit(_components[i]));
            amountComponents[i] = unit.preciseMul(_amountPortfolio);

            (amountEth, routers[i], ) = sofiProxy.getMaxAmountOut(amountComponents[i], _components[i], WETH);
            sumEth = sumEth.add(amountEth);
        }
        return (sumEth, amountComponents, routers);
    }

    function _tradeTokenByExactToken(IERC20 _tokenIn, address _tokenOut, uint256 _amountIn) internal returns (uint256) {
        (, address _router, ) = sofiProxy.getMaxAmountOut(_amountIn, address(_tokenIn), _tokenOut);
        _safeApprove(_tokenIn, address(sofiProxy), _amountIn);
        return sofiProxy.tradeTokenByExactToken(_router, address(_tokenIn), _tokenOut, _amountIn, 0, address(this));
    }

    function _safeApprove(IERC20 _token, address _spender, uint256 _requiredAllowance) internal {
        uint256 allowance = _token.allowance(address(this), _spender);
        if (allowance < _requiredAllowance) {
            _token.safeIncreaseAllowance(_spender, MAX_UINT96 - allowance);
        }
    }


    function _buyExactPortfolioFromWETH(IPortfolio _portfolio, uint256 _amountPortfolio, uint256 _maxEther) internal returns (uint256) {

        address[] memory components = _portfolio.getComponents();
        (
            uint256 sumEth,
            ,
            address[] memory routers,
            uint256[] memory amountComponents,
        ) = _getAmountETHForIssuance(_portfolio, components, _amountPortfolio);

        require(sumEth <= _maxEther, "SOFITrading: INSUFFICIENT_INPUT_AMOUNT");

        uint256 totalEth = 0;
        for (uint256 i = 0; i < components.length; i++) {
            uint256 amountETHSpent;
            if (components[i] == WETH) {
                amountETHSpent = amountComponents[i];
            } else {
                amountETHSpent = sofiProxy.tradeExactTokenByToken(routers[i], WETH, components[i], amountComponents[i], _maxEther, address(this));
            }
            totalEth = totalEth.add(amountETHSpent);
            _maxEther = _maxEther.sub(amountETHSpent);
        }
        portfolioModule.issue(_portfolio, _amountPortfolio, msg.sender);
        return totalEth;
    }


    function _getAmountETHForIssuance(IPortfolio _portfolio, address[] memory _components, uint256 _amountPortfolio)
        internal
        view
        returns (
            uint256 sumEth,
            uint256[] memory amountEthIn,
            address[] memory routers,
            uint256[] memory amountComponents,
            address[] memory pairAddresses
        )
    {
        sumEth = 0;
        amountEthIn = new uint256[](_components.length);
        amountComponents = new uint256[](_components.length);
        routers = new address[](_components.length);
        pairAddresses = new address[](_components.length);

        for (uint256 i = 0; i < _components.length; i++) {

            require(
                _portfolio.getExternalPositionModules(_components[i]).length == 0,
                "SOFITrading: EXTERNAL_POSITIONS_NOT_ALLOWED"
            );

            uint256 unit = uint256(_portfolio.getDefaultPositionRealUnit(_components[i]));
            amountComponents[i] = uint256(unit).preciseMulCeil(_amountPortfolio);

            (amountEthIn[i], routers[i], pairAddresses[i]) = sofiProxy.getMinAmountIn(amountComponents[i], WETH, _components[i]);
            sumEth = sumEth.add(amountEthIn[i]);
        }
        return (sumEth, amountEthIn, routers, amountComponents, pairAddresses);
    }

}