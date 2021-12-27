pragma solidity 0.6.10;

interface IController {
    function addPortfolio(address _portfolio) external;
    function isModule(address _module) external view returns(bool);
    function isPortfolio(address _portfolio) external view returns(bool);
    function resourceId(uint256 _id) external view returns(address);
}