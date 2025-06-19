// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Decentralized Reputation and Freelancing System
 * @dev A smart contract for managing freelance projects with reputation tracking
 */
contract Project {
    
    // Structs
    struct FreelanceProject {
        uint256 id;
        address client;
        address freelancer;
        string description;
        uint256 budget;
        uint256 deadline;
        ProjectStatus status;
        bool clientApproval;
        bool freelancerApproval;
    }
    
    struct UserProfile {
        string name;
        uint256 totalProjects;
        uint256 completedProjects;
        uint256 reputationScore;
        bool isRegistered;
    }
    
    enum ProjectStatus {
        Open,
        InProgress,
        Completed,
        Disputed,
        Cancelled
    }
    
    // State variables
    mapping(address => UserProfile) public users;
    mapping(uint256 => FreelanceProject) public projects;
    mapping(address => uint256[]) public userProjects;
    
    uint256 public projectCounter;
    uint256 public constant REPUTATION_BONUS = 10;
    uint256 public constant COMPLETION_BONUS = 5;
    
    // Events
    event UserRegistered(address indexed user, string name);
    event ProjectCreated(uint256 indexed projectId, address indexed client, uint256 budget);
    event ProjectAssigned(uint256 indexed projectId, address indexed freelancer);
    event ProjectCompleted(uint256 indexed projectId, address indexed client, address indexed freelancer);
    event ReputationUpdated(address indexed user, uint256 newScore);
    
    // Modifiers
    modifier onlyRegistered() {
        require(users[msg.sender].isRegistered, "User must be registered");
        _;
    }
    
    modifier projectExists(uint256 _projectId) {
        require(_projectId < projectCounter, "Project does not exist");
        _;
    }
    
    modifier onlyClient(uint256 _projectId) {
        require(projects[_projectId].client == msg.sender, "Only client can call this function");
        _;
    }
    
    modifier onlyFreelancer(uint256 _projectId) {
        require(projects[_projectId].freelancer == msg.sender, "Only assigned freelancer can call this function");
        _;
    }
    
    /**
     * @dev Core Function 1: Register User Profile
     * @param _name User's display name
     */
    function registerUser(string memory _name) external {
        require(!users[msg.sender].isRegistered, "User already registered");
        require(bytes(_name).length > 0, "Name cannot be empty");
        
        users[msg.sender] = UserProfile({
            name: _name,
            totalProjects: 0,
            completedProjects: 0,
            reputationScore: 100, // Starting reputation score
            isRegistered: true
        });
        
        emit UserRegistered(msg.sender, _name);
    }
    
    /**
     * @dev Core Function 2: Create and Manage Freelance Projects
     * @param _description Project description
     * @param _deadline Project deadline (timestamp)
     */
    function createProject(string memory _description, uint256 _deadline) external payable onlyRegistered {
        require(msg.value > 0, "Budget must be greater than 0");
        require(_deadline > block.timestamp, "Deadline must be in the future");
        require(bytes(_description).length > 0, "Description cannot be empty");
        
        uint256 projectId = projectCounter++;
        
        projects[projectId] = FreelanceProject({
            id: projectId,
            client: msg.sender,
            freelancer: address(0),
            description: _description,
            budget: msg.value,
            deadline: _deadline,
            status: ProjectStatus.Open,
            clientApproval: false,
            freelancerApproval: false
        });
        
        userProjects[msg.sender].push(projectId);
        users[msg.sender].totalProjects++;
        
        emit ProjectCreated(projectId, msg.sender, msg.value);
    }
    
    /**
     * @dev Assign freelancer to project
     * @param _projectId Project ID to apply for
     */
    function assignFreelancer(uint256 _projectId) external onlyRegistered projectExists(_projectId) {
        FreelanceProject storage project = projects[_projectId];
        require(project.status == ProjectStatus.Open, "Project is not open");
        require(project.client != msg.sender, "Client cannot be freelancer");
        require(project.freelancer == address(0), "Project already has a freelancer");
        
        project.freelancer = msg.sender;
        project.status = ProjectStatus.InProgress;
        userProjects[msg.sender].push(_projectId);
        users[msg.sender].totalProjects++;
        
        emit ProjectAssigned(_projectId, msg.sender);
    }
    
    /**
     * @dev Submit work and request completion
     * @param _projectId Project ID
     */
    function submitWork(uint256 _projectId) external onlyFreelancer(_projectId) projectExists(_projectId) {
        FreelanceProject storage project = projects[_projectId];
        require(project.status == ProjectStatus.InProgress, "Project is not in progress");
        
        project.freelancerApproval = true;
        
        // Auto-complete if both parties approve or if deadline passed
        if (project.clientApproval || block.timestamp > project.deadline) {
            _completeProject(_projectId);
        }
    }
    
    /**
     * @dev Client approves completed work
     * @param _projectId Project ID
     */
    function approveWork(uint256 _projectId) external onlyClient(_projectId) projectExists(_projectId) {
        FreelanceProject storage project = projects[_projectId];
        require(project.status == ProjectStatus.InProgress, "Project is not in progress");
        
        project.clientApproval = true;
        
        if (project.freelancerApproval) {
            _completeProject(_projectId);
        }
    }
    
    /**
     * @dev Core Function 3: Update Reputation Scores
     * @param _projectId Project ID to complete
     */
    function _completeProject(uint256 _projectId) internal {
        FreelanceProject storage project = projects[_projectId];
        project.status = ProjectStatus.Completed;
        
        // Update freelancer stats
        users[project.freelancer].completedProjects++;
        
        // Calculate reputation bonus based on timely delivery
        uint256 reputationBonus = REPUTATION_BONUS;
        if (block.timestamp <= project.deadline) {
            reputationBonus += COMPLETION_BONUS; // Bonus for on-time delivery
        }
        
        // Update reputation scores
        users[project.freelancer].reputationScore += reputationBonus;
        users[project.client].reputationScore += COMPLETION_BONUS;
        
        // Transfer payment to freelancer
        payable(project.freelancer).transfer(project.budget);
        
        emit ProjectCompleted(_projectId, project.client, project.freelancer);
        emit ReputationUpdated(project.freelancer, users[project.freelancer].reputationScore);
        emit ReputationUpdated(project.client, users[project.client].reputationScore);
    }
    
    // View functions
    function getUserProfile(address _user) external view returns (UserProfile memory) {
        return users[_user];
    }
    
    function getProject(uint256 _projectId) external view returns (FreelanceProject memory) {
        return projects[_projectId];
    }
    
    function getUserProjects(address _user) external view returns (uint256[] memory) {
        return userProjects[_user];
    }
    
    function getReputationScore(address _user) external view returns (uint256) {
        return users[_user].reputationScore;
    }
    
    // Emergency functions
    function cancelProject(uint256 _projectId) external onlyClient(_projectId) projectExists(_projectId) {
        FreelanceProject storage project = projects[_projectId];
        require(project.status == ProjectStatus.Open || project.status == ProjectStatus.InProgress, "Cannot cancel completed project");
        
        project.status = ProjectStatus.Cancelled;
        
        // Refund client
        payable(project.client).transfer(project.budget);
    }
}
