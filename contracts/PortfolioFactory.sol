pragma solidity 0.6.10;
pragma experimental "ABIEncoderV2";

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IController } from "./interfaces/IController.sol";
import { Portfolio } from "./Portfolio.sol";
import { AddressArrayUtils } from "./lib/AddressArrayUtils.sol";


contract PortfolioFactory is Ownable {
    using AddressArrayUtils for address[];

    event PortfolioCreated(address indexed _portfolio, address _manager, string _name, string _symbol);

    address[] public allowedTokens;
    mapping(address => bool) public isAllowed;

    IController public controller;


    constructor(IController _controller) public {
        controller = _controller;
    }

    function addTokens(address[] memory _tokens) external onlyOwner {

        for (uint i = 0; i < _tokens.length; i++) {

            require(!isAllowed[_tokens[i]], "Token already exists");

            isAllowed[_tokens[i]] = true;

            allowedTokens.push(_tokens[i]);
        }
    }

    function removeTokens(address[] memory _tokens) external onlyOwner {

        for (uint i = 0; i < _tokens.length; i++) {
            require(isAllowed[_tokens[i]], "Token does not exist");

            allowedTokens = allowedTokens.remove(_tokens[i]);

            isAllowed[_tokens[i]] = false;
        }
        
    }

    function getAllowedTokens() external view returns (address[] memory) {
        return allowedTokens;
    }


    function create(
        address[] memory _components,
        int256[] memory _units,
        address[] memory _modules,
        address _manager,
        string memory _name,
        string memory _symbol
    )
        external
        returns (address)
    {
        require(_components.length > 0, "Must have at least 1 component");
        require(_components.length == _units.length, "Component and unit lengths must be the same");
        require(!_components.hasDuplicate(), "Components must not have a duplicate");
        require(_modules.length > 0, "Must have at least 1 module");
        require(_manager != address(0), "Manager must not be empty");

        for (uint256 i = 0; i < _components.length; i++) {
            require(_components[i] != address(0), "Component must not be null address");
            require(isAllowed[_components[i]], "Token is not allowed");
            require(_units[i] > 0, "Units must be greater than 0");
        }

        for (uint256 j = 0; j < _modules.length; j++) {
            require(controller.isModule(_modules[j]), "Must be enabled module");
        }


        Portfolio portfolio = new Portfolio(
            _components,
            _units,
            _modules,
            controller,
            _manager,
            _name,
            _symbol
        );

        controller.addPortfolio(address(portfolio));

        emit PortfolioCreated(address(portfolio), _manager, _name, _symbol);

        return address(portfolio);
    }
}

