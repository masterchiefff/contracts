// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ActionRegistry {
    address public owner;
    uint256 public nextActionId = 1;

    struct Action {
        address creator;
        address targetContractAddress;
        string description;
        bool isActive;
    }

    struct TargetContract {
        bytes4 selector;
        address contractAddress;
    }

    mapping(uint256 => Action) public actions;
    mapping(uint256 => TargetContract) public targetContracts;

    event ActionRegistered(uint256 indexed actionId, address targetAddress, string description);
    event TargetContractRegistered(uint256 indexed actionId, bytes4 selector, address contractAddress);
    event ActionExecuted(uint256 indexed actionId, bool success);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    function registerAction(
        address _targetAddress,
        string memory _description
    ) public onlyOwner returns (uint256) {
        require(_targetAddress != address(0), "Invalid target address");
        require(bytes(_description).length > 0, "Description cannot be empty");
        
        uint256 actionId = nextActionId;
        actions[actionId] = Action(msg.sender, _targetAddress, _description, true);
        
        emit ActionRegistered(actionId, _targetAddress, _description);
        
        nextActionId++;
        return actionId;
    }

    function registerTargetContract(
        uint256 _actionId,
        bytes4 _selector,
        address _contractAddress
    ) public onlyOwner {
        require(_contractAddress != address(0), "Invalid contract address");
        require(actions[_actionId].isActive, "Action does not exist");
        
        targetContracts[_actionId] = TargetContract(_selector, _contractAddress);
        
        emit TargetContractRegistered(_actionId, _selector, _contractAddress);
    }

    function executeAction(uint256 _actionId, bytes calldata data) external {
        Action memory action = actions[_actionId];
        require(action.isActive, "Action not found or inactive");
        
        TargetContract memory targetContract = targetContracts[_actionId];
        require(targetContract.contractAddress != address(0), "Target contract not registered");
        
        // Verify that the function selector in the data matches the registered selector
        require(bytes4(data[:4]) == targetContract.selector, "Invalid function selector");
        
        (bool success, ) = action.targetContractAddress.call(data);
        
        emit ActionExecuted(_actionId, success);
        require(success, "Execution failed");
    }

    function getAction(uint256 _actionId) external view returns (Action memory) {
        return actions[_actionId];
    }

    function getTargetContract(uint256 _actionId) external view returns (TargetContract memory) {
        return targetContracts[_actionId];
    }

    function deactivateAction(uint256 _actionId) external onlyOwner {
        require(actions[_actionId].isActive, "Action does not exist or is already inactive");
        actions[_actionId].isActive = false;
    }
}