pragma solidity 0.6.10;
pragma experimental "ABIEncoderV2";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/SafeCast.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { SignedSafeMath } from "@openzeppelin/contracts/math/SignedSafeMath.sol";

import { IPortfolio } from "../interfaces/IPortfolio.sol";
import { PreciseUnitMath } from "./PreciseUnitMath.sol";



library Position {
    using SafeCast for uint256;
    using SafeMath for uint256;
    using SafeCast for int256;
    using SignedSafeMath for int256;
    using PreciseUnitMath for uint256;

    
    function hasDefaultPosition(IPortfolio _portfolio, address _component) internal view returns(bool) {
        return _portfolio.getDefaultPositionRealUnit(_component) > 0;
    }

    function hasExternalPosition(IPortfolio _portfolio, address _component) internal view returns(bool) {
        return _portfolio.getExternalPositionModules(_component).length > 0;
    }
    
    function hasSufficientDefaultUnits(IPortfolio _portfolio, address _component, uint256 _unit) internal view returns(bool) {
        return _portfolio.getDefaultPositionRealUnit(_component) >= _unit.toInt256();
    }

    function hasSufficientExternalUnits(
        IPortfolio _portfolio,
        address _component,
        address _positionModule,
        uint256 _unit
    )
        internal
        view
        returns(bool)
    {
       return _portfolio.getExternalPositionRealUnit(_component, _positionModule) >= _unit.toInt256();    
    }

    function editDefaultPosition(IPortfolio _portfolio, address _component, uint256 _newUnit) internal {
        bool isPositionFound = hasDefaultPosition(_portfolio, _component);
        if (!isPositionFound && _newUnit > 0) {
            
            if (!hasExternalPosition(_portfolio, _component)) {
                _portfolio.addComponent(_component);
            }
        } else if (isPositionFound && _newUnit == 0) {
            
            if (!hasExternalPosition(_portfolio, _component)) {
                _portfolio.removeComponent(_component);
            }
        }

        _portfolio.editDefaultPositionUnit(_component, _newUnit.toInt256());
    }

    
    function editExternalPosition(
        IPortfolio _portfolio,
        address _component,
        address _module,
        int256 _newUnit,
        bytes memory _data
    )
        internal
    {
        if (_newUnit != 0) {
            if (!_portfolio.isComponent(_component)) {
                _portfolio.addComponent(_component);
                _portfolio.addExternalPositionModule(_component, _module);
            } else if (!_portfolio.isExternalPositionModule(_component, _module)) {
                _portfolio.addExternalPositionModule(_component, _module);
            }
            _portfolio.editExternalPositionUnit(_component, _module, _newUnit);
            _portfolio.editExternalPositionData(_component, _module, _data);
        } else {
            require(_data.length == 0, "Passed data must be null");
            
            if (_portfolio.getExternalPositionRealUnit(_component, _module) != 0) {
                address[] memory positionModules = _portfolio.getExternalPositionModules(_component);
                if (_portfolio.getDefaultPositionRealUnit(_component) == 0 && positionModules.length == 1) {
                    require(positionModules[0] == _module, "External positions must be 0 to remove component");
                    _portfolio.removeComponent(_component);
                }
                _portfolio.removeExternalPositionModule(_component, _module);
            }
        }
    }

    
    function getDefaultTotalNotional(uint256 _portfolioSupply, uint256 _positionUnit) internal pure returns (uint256) {
        return _portfolioSupply.preciseMul(_positionUnit);
    }

    
    function getDefaultPositionUnit(uint256 _portfolioSupply, uint256 _totalNotional) internal pure returns (uint256) {
        return _totalNotional.preciseDiv(_portfolioSupply);
    }

    
    function getDefaultTrackedBalance(IPortfolio _portfolio, address _component) internal view returns(uint256) {
        int256 positionUnit = _portfolio.getDefaultPositionRealUnit(_component); 
        return _portfolio.totalSupply().preciseMul(positionUnit.toUint256());
    }

    
    function calculateAndEditDefaultPosition(
        IPortfolio _portfolio,
        address _component,
        uint256 _portfolioTotalSupply,
        uint256 _componentPreviousBalance
    )
        internal
        returns(uint256, uint256, uint256)
    {
        uint256 currentBalance = IERC20(_component).balanceOf(address(_portfolio));
        uint256 positionUnit = _portfolio.getDefaultPositionRealUnit(_component).toUint256();

        uint256 newTokenUnit;
        if (currentBalance > 0) {
            newTokenUnit = calculateDefaultEditPositionUnit(
                _portfolioTotalSupply,
                _componentPreviousBalance,
                currentBalance,
                positionUnit
            );
        } else {
            newTokenUnit = 0;
        }

        editDefaultPosition(_portfolio, _component, newTokenUnit);

        return (currentBalance, positionUnit, newTokenUnit);
    }

    
    function calculateDefaultEditPositionUnit(
        uint256 _portfolioSupply,
        uint256 _preTotalNotional,
        uint256 _postTotalNotional,
        uint256 _prePositionUnit
    )
        internal
        pure
        returns (uint256)
    {
        
        uint256 airdroppedAmount = _preTotalNotional.sub(_prePositionUnit.preciseMul(_portfolioSupply));
        return _postTotalNotional.sub(airdroppedAmount).preciseDiv(_portfolioSupply);
    }
}
