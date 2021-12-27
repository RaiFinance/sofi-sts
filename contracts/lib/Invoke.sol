pragma solidity 0.6.10;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";

import { IPortfolio } from "../interfaces/IPortfolio.sol";


library Invoke {
    using SafeMath for uint256;

    function invokeApprove(
        IPortfolio _portfolio,
        address _token,
        address _spender,
        uint256 _quantity
    )
        internal
    {
        bytes memory callData = abi.encodeWithSignature("approve(address,uint256)", _spender, _quantity);
        _portfolio.invoke(_token, 0, callData);
    }

    function invokeTransfer(
        IPortfolio _portfolio,
        address _token,
        address _to,
        uint256 _quantity
    )
        internal
    {
        if (_quantity > 0) {
            bytes memory callData = abi.encodeWithSignature("transfer(address,uint256)", _to, _quantity);
            _portfolio.invoke(_token, 0, callData);
        }
    }


    function strictInvokeTransfer(
        IPortfolio _portfolio,
        address _token,
        address _to,
        uint256 _quantity
    )
        internal
    {
        if (_quantity > 0) {
            
            uint256 existingBalance = IERC20(_token).balanceOf(address(_portfolio));

            Invoke.invokeTransfer(_portfolio, _token, _to, _quantity);

            
            uint256 newBalance = IERC20(_token).balanceOf(address(_portfolio));

            require(
                newBalance == existingBalance.sub(_quantity),
                "Invalid post transfer balance"
            );
        }
    }


    function invokeUnwrapWETH(IPortfolio _portfolio, address _weth, uint256 _quantity) internal {
        bytes memory callData = abi.encodeWithSignature("withdraw(uint256)", _quantity);
        _portfolio.invoke(_weth, 0, callData);
    }

    
    function invokeWrapWETH(IPortfolio _portfolio, address _weth, uint256 _quantity) internal {
        bytes memory callData = abi.encodeWithSignature("deposit()");
        _portfolio.invoke(_weth, _quantity, callData);
    }
}