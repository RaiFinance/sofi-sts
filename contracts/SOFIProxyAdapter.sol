pragma solidity 0.6.10;
pragma experimental "ABIEncoderV2";


contract SOFIProxyAdapter {


    address public immutable proxy;

    constructor(address _proxy) public {
        proxy = _proxy;
    }

    function getTradeCalldata(
        address _router,
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint256 _amountOutMin,
        address _to
    )
        external
        view
        returns (address, uint256, bytes memory)
    {   

        bytes memory callData = abi.encodeWithSignature(
            "tradeTokenByExactToken(address,address,address,uint256,uint256,address)",
            _router,
            _tokenIn,
            _tokenOut,
            _amountIn,
            _amountOutMin,
            _to
        );
        return (proxy, 0, callData);
    }


    function getSpender()
        external
        view
        returns (address)
    {
        return proxy;
    }
} 