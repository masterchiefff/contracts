// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract UserRegistration {
    struct Institution {
        string name;
        address owner; 
        bool isActive; 
    }

    struct User {
        address walletAddress;
        bool isInstructor; 
        uint256 institutionId; 
        bool isRegistered; 
    }

    mapping(uint256 => Institution) public institutions; 
    mapping(address => User) public users; 

    uint256 public institutionCount; 

    event InstitutionCreated(uint256 indexed institutionId, string name, address indexed owner);
    event UserRegistered(address indexed walletAddress, bool isInstructor, uint256 institutionId);

    // Function to create a new institution
    function createInstitution(string memory _name) external {
        require(bytes(_name).length > 0, "Institution name is required");

        institutions[institutionCount] = Institution({
            name: _name,
            owner: msg.sender,
            isActive: true
        });

        emit InstitutionCreated(institutionCount, _name, msg.sender);
        institutionCount++;
    }

    function registerUser(uint256 _institutionId) external {
        require(!users[msg.sender].isRegistered, "User already registered");
        
        if (_institutionId > 0) {
            require(institutions[_institutionId].isActive, "Institution must be active");
        }

        users[msg.sender] = User({
            walletAddress: msg.sender,
            isInstructor: false,
            institutionId: _institutionId,
            isRegistered: true
        });

        emit UserRegistered(msg.sender, false, _institutionId); 
    }

    function registerInstructor(uint256 _institutionId) external {
        require(!users[msg.sender].isRegistered, "User already registered");
        
        if (_institutionId > 0) {
            require(institutions[_institutionId].isActive, "Institution must be active");
        }

        users[msg.sender] = User({
            walletAddress: msg.sender,
            isInstructor: true,
            institutionId: _institutionId,
            isRegistered: true
        });

        emit UserRegistered(msg.sender, true, _institutionId); 
    }

    // Function to get user details
    function getUserDetails(address _userAddress) external view returns (User memory) {
        return users[_userAddress];
    }
}