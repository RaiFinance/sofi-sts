pragma solidity 0.6.10;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AddressArrayUtils } from "./lib/AddressArrayUtils.sol";


contract Controller is Ownable {
    using AddressArrayUtils for address[];

    event FactoryAdded(address indexed _factory);
    event FactoryRemoved(address indexed _factory);
    event ModuleAdded(address indexed _module);
    event ModuleRemoved(address indexed _module);
    event ResourceAdded(address indexed _resource, uint256 _id);
    event ResourceRemoved(address indexed _resource, uint256 _id);
    event PortfolioAdded(address indexed _portfolio, address indexed _factory);
    event PortfolioRemoved(address indexed _portfolio);

    modifier onlyFactory() {
        require(isFactory[msg.sender], "Only valid factories can call");
        _;
    }

    modifier onlyInitialized() {
        require(isInitialized, "Contract must be initialized.");
        _;
    }

    address[] public portfolios;

    address[] public factories;

    address[] public modules;

    address[] public resources;

    mapping(address => bool) public isPortfolio;
    mapping(address => bool) public isFactory;
    mapping(address => bool) public isModule;
    mapping(address => bool) public isResource;


    mapping(uint256 => address) public resourceId;

    
    bool public isInitialized;

    function initialize(
        address[] memory _factories,
        address[] memory _modules,
        address[] memory _resources,
        uint256[] memory _resourceIds
    )
        external
        onlyOwner
    {
        require(!isInitialized, "Controller is already initialized");
        require(_resources.length == _resourceIds.length, "Array lengths do not match.");

        factories = _factories;
        modules = _modules;
        resources = _resources;

        
        for (uint256 i = 0; i < _factories.length; i++) {
            require(_factories[i] != address(0), "Zero address submitted.");
            isFactory[_factories[i]] = true;
        }
        for (uint256 i = 0; i < _modules.length; i++) {
            require(_modules[i] != address(0), "Zero address submitted.");
            isModule[_modules[i]] = true;
        }

        for (uint256 i = 0; i < _resources.length; i++) {
            require(_resources[i] != address(0), "Zero address submitted.");
            require(resourceId[_resourceIds[i]] == address(0), "Resource ID already exists");
            isResource[_resources[i]] = true;
            resourceId[_resourceIds[i]] = _resources[i];
        }


        isInitialized = true;
    }


    function addPortfolio(address _portfolio) external onlyInitialized onlyFactory {
        require(!isPortfolio[_portfolio], "Portfolio already exists");

        isPortfolio[_portfolio] = true;

        portfolios.push(_portfolio);

        emit PortfolioAdded(_portfolio, msg.sender);
    }

    function removePortfolio(address _portfolio) external onlyInitialized onlyOwner {
        require(isPortfolio[_portfolio], "Portfolio does not exist");

        portfolios = portfolios.remove(_portfolio);

        isPortfolio[_portfolio] = false;

        emit PortfolioRemoved(_portfolio);
    }

    function addFactory(address _factory) external onlyInitialized onlyOwner {
        require(!isFactory[_factory], "Factory already exists");

        isFactory[_factory] = true;

        factories.push(_factory);

        emit FactoryAdded(_factory);
    }


    function removeFactory(address _factory) external onlyInitialized onlyOwner {
        require(isFactory[_factory], "Factory does not exist");

        factories = factories.remove(_factory);

        isFactory[_factory] = false;

        emit FactoryRemoved(_factory);
    }


    function addModule(address _module) external onlyInitialized onlyOwner {
        require(!isModule[_module], "Module already exists");

        isModule[_module] = true;

        modules.push(_module);

        emit ModuleAdded(_module);
    }


    function removeModule(address _module) external onlyInitialized onlyOwner {
        require(isModule[_module], "Module does not exist");

        modules = modules.remove(_module);

        isModule[_module] = false;

        emit ModuleRemoved(_module);
    }


    function addResource(address _resource, uint256 _id) external onlyInitialized onlyOwner {
        require(!isResource[_resource], "Resource already exists");

        require(resourceId[_id] == address(0), "Resource ID already exists");

        isResource[_resource] = true;

        resourceId[_id] = _resource;

        resources.push(_resource);

        emit ResourceAdded(_resource, _id);
    }


    function removeResource(uint256 _id) external onlyInitialized onlyOwner {
        address resourceToRemove = resourceId[_id];

        require(resourceToRemove != address(0), "Resource does not exist");

        resources = resources.remove(resourceToRemove);

        delete resourceId[_id];

        isResource[resourceToRemove] = false;

        emit ResourceRemoved(resourceToRemove, _id);
    }

    function getFactories() external view returns (address[] memory) {
        return factories;
    }

    function getModules() external view returns (address[] memory) {
        return modules;
    }

    function getResources() external view returns (address[] memory) {
        return resources;
    }

    function getPortfolios() external view returns (address[] memory) {
        return portfolios;
    }

}
