// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {VotingNFT} from "./VotingNFT.sol";

contract Voting is AccessControl {
    // Role definitions
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant FOUNDER_ROLE = keccak256("FOUNDER_ROLE");

    // Workflow status enum
    enum WorkflowStatus {
        REGISTER_CANDIDATES, // 0: Admins ajoutent candidats
        FOUND_CANDIDATES, // 1: Founders financent candidats
        VOTE, // 2: Période de vote (après délai 1h)
        COMPLETED // 3: Vote terminé, winner disponible
    }

    // Candidate struct with funding support
    struct Candidate {
        string name;
        string description;
        uint256 votes;
        address candidateAddress;
        uint256 fundsReceived;
    }

    // State variables
    Candidate[] public candidates;
    mapping(address => uint256) public voterToCandidate;

    VotingNFT public votingNft;
    WorkflowStatus public currentStatus;
    uint256 public voteStartTime;
    uint256 public constant VOTE_DELAY = 1 hours;

    // Events
    event Voted(address indexed voter, uint256 indexed candidateIndex);
    event CandidateAdded(
        string name,
        string description,
        address candidateAddress
    );
    event CandidateUpdated(
        uint256 indexed index,
        string name,
        string description,
        address candidateAddress
    );
    event CandidateDeleted(uint256 indexed index);
    event WorkflowStatusChanged(WorkflowStatus newStatus);
    event CandidateFunded(
        uint256 indexed candidateIndex,
        address indexed funder,
        uint256 amount
    );
    event FundsWithdrawn(uint256 indexed candidateIndex, uint256 amount);

    constructor(address _votingNft) {
        votingNft = VotingNFT(_votingNft);
        currentStatus = WorkflowStatus.REGISTER_CANDIDATES;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    // Workflow management
    function setWorkflowStatus(
        WorkflowStatus newStatus
    ) external onlyRole(ADMIN_ROLE) {
        require(
            uint8(newStatus) == uint8(currentStatus) + 1,
            "Must advance workflow sequentially"
        );

        if (newStatus == WorkflowStatus.VOTE) {
            voteStartTime = block.timestamp;
        }

        currentStatus = newStatus;
        emit WorkflowStatusChanged(newStatus);
    }

    // Candidate management functions
    function addCandidate(
        string memory _name,
        string memory _description,
        address _candidateAddress
    ) public onlyRole(ADMIN_ROLE) {
        require(
            currentStatus == WorkflowStatus.REGISTER_CANDIDATES,
            "Can only add candidates during registration"
        );
        require(_candidateAddress != address(0), "Invalid address");

        candidates.push(
            Candidate({
                name: _name,
                description: _description,
                votes: 0,
                candidateAddress: _candidateAddress,
                fundsReceived: 0
            })
        );

        emit CandidateAdded(_name, _description, _candidateAddress);
    }

    function deleteCandidate(uint256 index) public onlyRole(ADMIN_ROLE) {
        require(
            currentStatus == WorkflowStatus.REGISTER_CANDIDATES,
            "Can only delete candidates during registration"
        );
        require(index < candidates.length, "Invalid candidate index");

        // Swap with the last element
        candidates[index] = candidates[candidates.length - 1];
        // Remove the last element
        candidates.pop();

        emit CandidateDeleted(index);
    }

    function updateCandidate(
        uint256 index,
        string memory _name,
        string memory _description,
        address _candidateAddress
    ) public onlyRole(ADMIN_ROLE) {
        require(
            currentStatus == WorkflowStatus.REGISTER_CANDIDATES,
            "Can only update candidates during registration"
        );
        require(index < candidates.length, "Invalid candidate index");
        require(_candidateAddress != address(0), "Invalid address");

        candidates[index].name = _name;
        candidates[index].description = _description;
        candidates[index].candidateAddress = _candidateAddress;

        emit CandidateUpdated(index, _name, _description, _candidateAddress);
    }

    // Funding mechanism
    function fundCandidate(
        uint256 candidateIndex
    ) external payable onlyRole(FOUNDER_ROLE) {
        require(
            currentStatus == WorkflowStatus.FOUND_CANDIDATES,
            "Can only fund during founding period"
        );
        require(candidateIndex < candidates.length, "Invalid candidate");
        require(msg.value > 0, "Must send ETH");

        candidates[candidateIndex].fundsReceived += msg.value;
        emit CandidateFunded(candidateIndex, msg.sender, msg.value);
    }

    function withdrawFunds(uint256 candidateIndex) external {
        require(candidateIndex < candidates.length, "Invalid candidate");
        Candidate storage candidate = candidates[candidateIndex];
        require(
            msg.sender == candidate.candidateAddress,
            "Only candidate can withdraw"
        );
        require(candidate.fundsReceived > 0, "No funds");

        uint256 amount = candidate.fundsReceived;
        candidate.fundsReceived = 0; // Reentrancy protection

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        emit FundsWithdrawn(candidateIndex, amount);
    }

    // Voting function with NFT integration
    function vote(uint256 candidateIndex) public {
        require(currentStatus == WorkflowStatus.VOTE, "Voting not open");
        require(
            block.timestamp >= voteStartTime + VOTE_DELAY,
            "Voting delay not passed"
        );
        require(candidateIndex < candidates.length, "Invalid candidate");
        require(votingNft.balanceOf(msg.sender) == 0, "Already voted");

        candidates[candidateIndex].votes++;
        votingNft.mint(msg.sender);
        voterToCandidate[msg.sender] = candidateIndex;

        emit Voted(msg.sender, candidateIndex);
    }

    // View functions
    function getCandidates()
        public
        view
        returns (string[] memory, string[] memory, uint256[] memory)
    {
        string[] memory names = new string[](candidates.length);
        string[] memory descriptions = new string[](candidates.length);
        uint256[] memory votes = new uint256[](candidates.length);

        for (uint256 i = 0; i < candidates.length; i++) {
            names[i] = candidates[i].name;
            descriptions[i] = candidates[i].description;
            votes[i] = candidates[i].votes;
        }

        return (names, descriptions, votes);
    }

    function getCandidateDetails(
        uint256 index
    )
        external
        view
        returns (
            string memory name,
            string memory description,
            uint256 votes,
            address candidateAddress,
            uint256 fundsReceived
        )
    {
        require(index < candidates.length, "Invalid index");
        Candidate storage c = candidates[index];
        return (
            c.name,
            c.description,
            c.votes,
            c.candidateAddress,
            c.fundsReceived
        );
    }

    function getUserVote(address user) public view returns (uint256) {
        require(votingNft.balanceOf(user) > 0, "This user has not voted yet.");
        return voterToCandidate[user];
    }

    function getWinner()
        public
        view
        returns (
            string memory winnerName,
            string memory winnerDescription,
            uint256 winnerVotes,
            address winnerAddress,
            uint256 winnerFunds
        )
    {
        require(
            currentStatus == WorkflowStatus.COMPLETED,
            "Voting not completed"
        );
        require(candidates.length > 0, "No candidates");

        uint256 maxVotes = 0;
        uint256 winnerIndex = 0;

        for (uint256 i = 0; i < candidates.length; i++) {
            if (candidates[i].votes > maxVotes) {
                maxVotes = candidates[i].votes;
                winnerIndex = i;
            }
        }

        Candidate storage winner = candidates[winnerIndex];
        return (
            winner.name,
            winner.description,
            winner.votes,
            winner.candidateAddress,
            winner.fundsReceived
        );
    }

    function getCurrentStatus() external view returns (WorkflowStatus) {
        return currentStatus;
    }

    function canVoteAt() external view returns (uint256) {
        if (currentStatus != WorkflowStatus.VOTE) return 0;
        return voteStartTime + VOTE_DELAY;
    }

    function getVotingStatus()
        public
        view
        returns (bool isOpen, uint256 timeUntilVoting)
    {
        if (currentStatus != WorkflowStatus.VOTE) {
            return (false, 0);
        }

        uint256 voteAllowedAt = voteStartTime + VOTE_DELAY;
        if (block.timestamp < voteAllowedAt) {
            return (false, voteAllowedAt - block.timestamp);
        } else {
            return (true, 0);
        }
    }
}
