// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Crowdfunding {
    struct Project {
        address owner;
        string title;
        string description;
        uint256 fundingGoal;
        uint256 deadline;
        uint256 totalFunding;
        uint256 numFunders;
        mapping(address => uint256) funds;
        bool closed;
    }

    mapping(uint256 => Project) public projects;

    uint256 public numProjects;
    ERC20 public token;

    event ProjectCreated(uint256 projectId, address owner, string title, string description, uint256 fundingGoal, uint256 deadline);
    event ProjectFunded(uint256 projectId, address backer, uint256 amount, uint256 totalFunding);
    event ProjectClosed(uint256 projectId, bool successfullyFunded);

    constructor(address _tokenAddress) {
        token = ERC20(_tokenAddress);
    }

    function createProject(string memory _title, string memory _description, uint256 _fundingGoal, uint256 _deadline) external returns (uint256) {
        require(_fundingGoal > 0, "Funding goal must be greater than zero.");
        require(_deadline > block.timestamp, "Deadline must be in the future.");
        uint256 projectId = numProjects++;
        projects[projectId] = Project(msg.sender, _title, _description, _fundingGoal, _deadline, 0, 0, new mapping(address => uint256), false);
        emit ProjectCreated(projectId, msg.sender, _title, _description, _fundingGoal, _deadline);
        return projectId;
    }

    function pledgeFunds(uint256 _projectId, uint256 _amount) external {
        Project storage project = projects[_projectId];
        require(!project.closed, "Project is closed.");
        require(block.timestamp < project.deadline, "Deadline has passed.");
        require(project.totalFunding + _amount <= project.fundingGoal, "Funding goal exceeded.");
        token.transferFrom(msg.sender, address(this), _amount);
        project.funds[msg.sender] += _amount;
        project.totalFunding += _amount;
        project.numFunders++;
        emit ProjectFunded(_projectId, msg.sender, _amount, project.totalFunding);
        if (project.totalFunding == project.fundingGoal) {
            project.closed = true;
            emit ProjectClosed(_projectId, true);
        }
    }

    function withdrawFunds(uint256 _projectId) external {
        Project storage project = projects[_projectId];
        require(project.closed, "Project is not closed.");
        if (project.totalFunding < project.fundingGoal) {
            token.transfer(project.owner, project.totalFunding);
        } else {
            uint256 ownerFee = (project.totalFunding * 10) / 100; // 10% fee for the platform
            uint256 fundingFee = project.totalFunding - ownerFee;
            token.transfer(project.owner, ownerFee);
            token.transferFrom(address(this), msg.sender, fundingFee);
        }
    }
}
