pragma solidity 0.6.10;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { AddressArrayUtils } from "./AddressArrayUtils.sol";
import { ExplicitERC20 } from "./ExplicitERC20.sol";
import { IController } from "../interfaces/IController.sol";
import { IModule } from "../interfaces/IModule.sol";
import { IPortfolio } from "../interfaces/IPortfolio.sol";
import { Invoke } from "./Invoke.sol";
import { Position } from "./Position.sol";
import { PreciseUnitMath } from "./PreciseUnitMath.sol";
import { ResourceIdentifier } from "./ResourceIdentifier.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/SafeCast.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { SignedSafeMath } from "@openzeppelin/contracts/math/SignedSafeMath.sol";


abstract contract ModuleBase is IModule {
    using AddressArrayUtils for address[];
    using Invoke for IPortfolio;
    using Position for IPortfolio;
    using PreciseUnitMath for uint256;
    using ResourceIdentifier for IController;
    using SafeCast for int256;
    using SafeCast for uint256;
    using SafeMath for uint256;
    using SignedSafeMath for int256;

    
    IController public controller;

    modifier onlyManagerAndValidPortfolio(IPortfolio _portfolio) {
        _validateOnlyManagerAndValidPortfolio(_portfolio);
        _;
    }

    modifier onlyPortfolioManager(IPortfolio _portfolio, address _caller) {
        _validateOnlyPortfolioManager(_portfolio, _caller);
        _;
    }

    modifier onlyValidAndInitializedPortfolio(IPortfolio _portfolio) {
        _validateOnlyValidAndInitializedPortfolio(_portfolio);
        _;
    }


    modifier onlyModule(IPortfolio _portfolio) {
        _validateOnlyModule(_portfolio);
        _;
    }

    modifier onlyValidAndPendingPortfolio(IPortfolio _portfolio) {
        _validateOnlyValidAndPendingPortfolio(_portfolio);
        _;
    }


    constructor(IController _controller) public {
        controller = _controller;
    }

    function transferFrom(IERC20 _token, address _from, address _to, uint256 _quantity) internal {
        ExplicitERC20.transferFrom(_token, _from, _to, _quantity);
    }

    
    function getAndValidateAdapter(string memory _integrationName) internal view returns(address) { 
        bytes32 integrationHash = getNameHash(_integrationName);
        return getAndValidateAdapterWithHash(integrationHash);
    }

    
    function getAndValidateAdapterWithHash(bytes32 _integrationHash) internal view returns(address) { 
        address adapter = controller.getIntegrationRegistry().getIntegrationAdapterWithHash(
            address(this),
            _integrationHash
        );

        require(adapter != address(0), "Must be valid adapter"); 
        return adapter;
    }


    function isPortfolioPendingInitialization(IPortfolio _portfolio) internal view returns(bool) {
        return _portfolio.isPendingModule(address(this));
    }

    function isPortfolioManager(IPortfolio _portfolio, address _toCheck) internal view returns(bool) {
        return _portfolio.manager() == _toCheck;
    }


    function isPortfolioValidAndInitialized(IPortfolio _portfolio) internal view returns(bool) {
        return controller.isPortfolio(address(_portfolio)) &&
            _portfolio.isInitializedModule(address(this));
    }


    function getNameHash(string memory _name) internal pure returns(bytes32) {
        return keccak256(bytes(_name));
    }


    function _validateOnlyManagerAndValidPortfolio(IPortfolio _portfolio) internal view {
       require(isPortfolioManager(_portfolio, msg.sender), "Must be the porfolio manager");
       require(isPortfolioValidAndInitialized(_portfolio), "Must be a valid and initialized porfolio");
    }


    function _validateOnlyPortfolioManager(IPortfolio _portfolio, address _caller) internal view {
        require(isPortfolioManager(_portfolio, _caller), "Must be the porfolio manager");
    }


    function _validateOnlyValidAndInitializedPortfolio(IPortfolio _portfolio) internal view {
        require(isPortfolioValidAndInitialized(_portfolio), "Must be a valid and initialized porfolio");
    }

    
    function _validateOnlyModule(IPortfolio _portfolio) internal view {
        require(
            _portfolio.moduleStates(msg.sender) == IPortfolio.ModuleState.INITIALIZED,
            "Only the module can call"
        );

        require(
            controller.isModule(msg.sender),
            "Module must be enabled on controller"
        );
    }


    function _validateOnlyValidAndPendingPortfolio(IPortfolio _portfolio) internal view {
        require(controller.isPortfolio(address(_portfolio)), "Must be controller-enabled porfolio");
        require(isPortfolioPendingInitialization(_portfolio), "Must be pending initialization");
    }
}