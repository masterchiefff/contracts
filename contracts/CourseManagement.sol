// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./UserRegistration.sol";

contract CourseManagement {
    struct Course {
        string title;
        string description;
        address creator;
        uint256 mintingPrice;
        bool isActive;
    }

    mapping(uint256 => Course) public courses;
    uint256 public courseCount;

    event CourseCreated(uint256 courseId, string title, address indexed creator);

    function createCourse(string memory _title, string memory _description, uint256 _mintingPrice) external {
        require(UserRegistration(users[msg.sender]).isRegistered, "User not registered");
        
        courses[courseCount] = Course({
            title: _title,
            description: _description,
            creator: msg.sender,
            mintingPrice: _mintingPrice,
            isActive: true
        });

        emit CourseCreated(courseCount, _title, msg.sender);
        courseCount++;
    }

    function deactivateCourse(uint256 _courseId) external {
        require(courses[_courseId].creator == msg.sender, "Only creator can deactivate");
        
        courses[_courseId].isActive = false;
    }
}