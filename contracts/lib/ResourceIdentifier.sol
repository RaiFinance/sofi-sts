pragma solidity 0.6.10;

import { IController } from "../interfaces/IController.sol";
import { IIntegrationRegistry } from "../interfaces/IIntegrationRegistry.sol";


library ResourceIdentifier {

    
    uint256 constant internal INTEGRATION_REGISTRY_RESOURCE_ID = 0;

    function getIntegrationRegistry(IController _controller) internal view returns (IIntegrationRegistry) {
        return IIntegrationRegistry(_controller.resourceId(INTEGRATION_REGISTRY_RESOURCE_ID));
    }
}