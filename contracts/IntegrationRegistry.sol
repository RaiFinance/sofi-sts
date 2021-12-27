pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import { IController } from "./interfaces/IController.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";


contract IntegrationRegistry is Ownable {


    event IntegrationAdded(address indexed _module, address indexed _adapter, string _integrationName);
    event IntegrationRemoved(address indexed _module, address indexed _adapter, string _integrationName);
    event IntegrationEdited(
        address indexed _module,
        address _newAdapter,
        string _integrationName
    );

    
    IController public controller;

    
    mapping(address => mapping(bytes32 => address)) private integrations;

    
    constructor(IController _controller) public {
        controller = _controller;
    }

    
    function addIntegration(
        address _module,
        string memory _name,
        address _adapter
    )
        public
        onlyOwner
    {
        bytes32 hashedName = _nameHash(_name);
        require(controller.isModule(_module), "Must be valid module.");
        require(integrations[_module][hashedName] == address(0), "Integration exists already.");
        require(_adapter != address(0), "Adapter address must exist.");

        integrations[_module][hashedName] = _adapter;

        emit IntegrationAdded(_module, _adapter, _name);
    }

    
    function batchAddIntegration(
        address[] memory _modules,
        string[] memory _names,
        address[] memory _adapters
    )
        external
        onlyOwner
    {
        
        uint256 modulesCount = _modules.length;

        require(modulesCount > 0, "Modules must not be empty");
        require(modulesCount == _names.length, "Module and name lengths mismatch");
        require(modulesCount == _adapters.length, "Module and adapter lengths mismatch");

        for (uint256 i = 0; i < modulesCount; i++) {
            
            addIntegration(
                _modules[i],
                _names[i],
                _adapters[i]
            );
        }
    }

    
    function editIntegration(
        address _module,
        string memory _name,
        address _adapter
    )
        public
        onlyOwner
    {
        bytes32 hashedName = _nameHash(_name);

        require(controller.isModule(_module), "Must be valid module.");
        require(integrations[_module][hashedName] != address(0), "Integration does not exist.");
        require(_adapter != address(0), "Adapter address must exist.");

        integrations[_module][hashedName] = _adapter;

        emit IntegrationEdited(_module, _adapter, _name);
    }

    
    function batchEditIntegration(
        address[] memory _modules,
        string[] memory _names,
        address[] memory _adapters
    )
        external
        onlyOwner
    {
        
        uint256 modulesCount = _modules.length;

        require(modulesCount > 0, "Modules must not be empty");
        require(modulesCount == _names.length, "Module and name lengths mismatch");
        require(modulesCount == _adapters.length, "Module and adapter lengths mismatch");

        for (uint256 i = 0; i < modulesCount; i++) {
            
            editIntegration(
                _modules[i],
                _names[i],
                _adapters[i]
            );
        }
    }

    
    function removeIntegration(address _module, string memory _name) external onlyOwner {
        bytes32 hashedName = _nameHash(_name);
        require(integrations[_module][hashedName] != address(0), "Integration does not exist.");

        address oldAdapter = integrations[_module][hashedName];
        delete integrations[_module][hashedName];

        emit IntegrationRemoved(_module, oldAdapter, _name);
    }

    
    function getIntegrationAdapter(address _module, string memory _name) external view returns (address) {
        return integrations[_module][_nameHash(_name)];
    }

    
    function getIntegrationAdapterWithHash(address _module, bytes32 _nameHash) external view returns (address) {
        return integrations[_module][_nameHash];
    }

    
    function isValidIntegration(address _module, string memory _name) external view returns (bool) {
        return integrations[_module][_nameHash(_name)] != address(0);
    }

    
    function _nameHash(string memory _name) internal pure returns(bytes32) {
        return keccak256(bytes(_name));
    }
}