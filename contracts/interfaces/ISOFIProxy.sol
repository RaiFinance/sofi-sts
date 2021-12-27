pragma solidity 0.6.10;

interface ISOFIProxy {
    function tradeTokenByExactToken(address _router, address _tokenIn, address _tokenOut, uint256 _amountIn, uint256 _amountOutMin, address _to) external payable returns (uint256);
    function tradeExactTokenByToken(address _router, address _tokenIn, address _tokenOut, uint256 _amountOut, uint256 _amountInMax, address _to) external payable returns (uint256);
    function getMaxAmountOut(uint256 _amountIn, address _tokenIn, address _tokenOut) external view returns (uint256, address, address);
    function getMinAmountIn(uint256 _amountOut, address _tokenIn, address _tokenOut) external view returns (uint256, address, address);
}