pragma solidity 0.6.10;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";


library ExplicitERC20 {
    using SafeMath for uint256;

    function transferFrom(
        IERC20 _token,
        address _from,
        address _to,
        uint256 _quantity
    )
        internal
    {
        
        if (_quantity > 0) {
            uint256 existingBalance = _token.balanceOf(_to);

            SafeERC20.safeTransferFrom(
                _token,
                _from,
                _to,
                _quantity
            );

            uint256 newBalance = _token.balanceOf(_to);

            
            require(
                newBalance == existingBalance.add(_quantity),
                "Invalid post transfer balance"
            );
        }
    }
}
