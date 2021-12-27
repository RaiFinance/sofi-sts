pragma solidity 0.6.10;

interface ISOFIProxyAdapter {
    function getSpender() external view returns(address);
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
        returns (address, uint256, bytes memory);
}