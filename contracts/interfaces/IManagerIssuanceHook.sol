pragma solidity 0.6.10;

import { IPortfolio} from "./IPortfolio.sol";

interface IManagerIssuanceHook {
    function invokePreIssueHook(IPortfolio _portfolio, uint256 _issueQuantity, address _sender, address _to) external;
    function invokePreRedeemHook(IPortfolio _portfolio, uint256 _redeemQuantity, address _sender, address _to) external;
}