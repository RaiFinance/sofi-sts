pragma solidity 0.6.10;
pragma experimental "ABIEncoderV2";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/SafeCast.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";

import { IController } from "./interfaces/IController.sol";
import { IManagerIssuanceHook } from "./interfaces/IManagerIssuanceHook.sol";
import { Invoke } from "./lib/Invoke.sol";
import { IPortfolio } from "./interfaces/IPortfolio.sol";
import { ModuleBase } from "./lib/ModuleBase.sol";
import { Position } from "./lib/Position.sol";
import { PreciseUnitMath } from "./lib/PreciseUnitMath.sol";


contract PortfolioModule is ModuleBase, ReentrancyGuard {
    using Invoke for IPortfolio;
    using Position for IPortfolio.Position;
    using Position for IPortfolio;
    using PreciseUnitMath for uint256;
    using SafeMath for uint256;
    using SafeCast for int256;

    event PortfolioIssued(
        address indexed _portfolio,
        address indexed _issuer,
        address indexed _to,
        uint256 _quantity
    );
    event PortfolioRedeemed(
        address indexed _portfolio,
        address indexed _redeemer,
        address indexed _to,
        uint256 _quantity
    );

    constructor(IController _controller) public ModuleBase(_controller) {}


    function issue(
        IPortfolio _portfolio,
        uint256 _quantity,
        address _to
    ) 
        external
        nonReentrant
        onlyValidAndInitializedPortfolio(_portfolio)
    {
        require(_quantity > 0, "Issue quantity must be > 0");

        (
            address[] memory components,
            uint256[] memory componentQuantities
        ) = getRequiredComponentUnitsForIssue(_portfolio, _quantity);

        for (uint256 i = 0; i < components.length; i++) {

            transferFrom(
                IERC20(components[i]),
                msg.sender,
                address(_portfolio),
                componentQuantities[i]
            );
        }
        _portfolio.mint(_to, _quantity);

        emit PortfolioIssued(address(_portfolio), msg.sender, _to, _quantity);
    }

    function redeem(
        IPortfolio _portfolio,
        uint256 _quantity,
        address _to
    )
        external
        nonReentrant
        onlyValidAndInitializedPortfolio(_portfolio)
    {
        require(_quantity > 0, "Redeem quantity must be > 0");

        _portfolio.burn(msg.sender, _quantity);

        address[] memory components = _portfolio.getComponents();
        for (uint256 i = 0; i < components.length; i++) {
            address component = components[i];
            require(!_portfolio.hasExternalPosition(component), "Only default positions are supported");

            uint256 unit = _portfolio.getDefaultPositionRealUnit(component).toUint256();

            uint256 componentQuantity = _quantity.preciseMul(unit);

            _portfolio.strictInvokeTransfer(
                component,
                _to,
                componentQuantity
            );
        }

        emit PortfolioRedeemed(address(_portfolio), msg.sender, _to, _quantity);
    }

    function initialize(
        IPortfolio _portfolio
    )
        external
        onlyPortfolioManager(_portfolio, msg.sender)
        onlyValidAndPendingPortfolio(_portfolio)
    {

        _portfolio.initializeModule();
    }


    function removeModule() external override {
        revert("The PortfolioModule module cannot be removed");
    }

    function getRequiredComponentUnitsForIssue(
        IPortfolio _portfolio,
        uint256 _quantity
    )
        public
        view
        onlyValidAndInitializedPortfolio(_portfolio)
        returns (address[] memory, uint256[] memory)
    {
        address[] memory components = _portfolio.getComponents();

        uint256[] memory notionalUnits = new uint256[](components.length);

        for (uint256 i = 0; i < components.length; i++) {
            require(!_portfolio.hasExternalPosition(components[i]), "Only default positions are supported");

            notionalUnits[i] = _portfolio.getDefaultPositionRealUnit(components[i]).toUint256().preciseMulCeil(_quantity);
        }

        return (components, notionalUnits);
    }

}