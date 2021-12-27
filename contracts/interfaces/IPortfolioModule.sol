
pragma solidity >=0.6.10;

import { IPortfolio } from "./IPortfolio.sol";

interface IPortfolioModule {
    function getRequiredComponentUnitsForIssue(
        IPortfolio _portfolio,
        uint256 _quantity
    ) external returns(address[] memory, uint256[] memory);
    function issue(IPortfolio _portfolio, uint256 _quantity, address _to) external;
    function redeem(IPortfolio _token, uint256 _quantity, address _to) external;
}