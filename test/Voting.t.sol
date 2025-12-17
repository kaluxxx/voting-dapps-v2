// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Voting} from "../src/Voting.sol";
import {VotingNFT} from "../src/VotingNFT.sol";

contract VotingTest is Test {
    Voting public voting;
    VotingNFT public nft;
    address public admin;
    address public founder1;
    address public founder2;
    address public voter1;
    address public voter2;
    address public voter3;
    address public candidateAddr1;
    address public candidateAddr2;
    address public candidateAddr3;

    function setUp() public {
        admin = address(this);
        founder1 = makeAddr("founder1");
        founder2 = makeAddr("founder2");
        voter1 = makeAddr("voter1");
        voter2 = makeAddr("voter2");
        voter3 = makeAddr("voter3");
        candidateAddr1 = makeAddr("candidateAddr1");
        candidateAddr2 = makeAddr("candidateAddr2");
        candidateAddr3 = makeAddr("candidateAddr3");

        // Deploy NFT first
        nft = new VotingNFT();

        // Deploy Voting with NFT address
        voting = new Voting(address(nft));

        // Transfer NFT ownership to Voting contract
        nft.transferOwnership(address(voting));

        // Grant founder roles
        voting.grantRole(voting.FOUNDER_ROLE(), founder1);
        voting.grantRole(voting.FOUNDER_ROLE(), founder2);

        // Fund founders for testing
        vm.deal(founder1, 10 ether);
        vm.deal(founder2, 5 ether);
    }

    // Helper modifier to advance to specific workflow status
    modifier atStatus(Voting.WorkflowStatus status) {
        while (uint8(voting.currentStatus()) < uint8(status)) {
            voting.setWorkflowStatus(
                Voting.WorkflowStatus(uint8(voting.currentStatus()) + 1)
            );
        }
        _;
    }

    // Helper function to setup candidates
    function setupCandidates() internal {
        voting.addCandidate("Alice", "Candidate 1", candidateAddr1);
        voting.addCandidate("Bob", "Candidate 2", candidateAddr2);
        voting.addCandidate("Charlie", "Candidate 3", candidateAddr3);
    }

    // ============================================
    // ACCESS CONTROL TESTS (6 tests)
    // ============================================

    function test_AdminRoleGrantedToDeployer() public view {
        assertTrue(voting.hasRole(voting.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(voting.hasRole(voting.ADMIN_ROLE(), admin));
    }

    function test_GrantFounderRole() public {
        address newFounder = makeAddr("newFounder");
        voting.grantRole(voting.FOUNDER_ROLE(), newFounder);
        assertTrue(voting.hasRole(voting.FOUNDER_ROLE(), newFounder));
    }

    function test_RevokeRole() public {
        voting.revokeRole(voting.FOUNDER_ROLE(), founder1);
        assertFalse(voting.hasRole(voting.FOUNDER_ROLE(), founder1));
    }

    function test_RevertWhen_NonAdminSetsWorkflow() public {
        vm.prank(voter1);
        vm.expectRevert();
        voting.setWorkflowStatus(Voting.WorkflowStatus.FOUND_CANDIDATES);
    }

    function test_MultipleAdmins() public {
        address newAdmin = makeAddr("newAdmin");
        voting.grantRole(voting.ADMIN_ROLE(), newAdmin);
        assertTrue(voting.hasRole(voting.ADMIN_ROLE(), newAdmin));

        // New admin can add candidates
        vm.prank(newAdmin);
        voting.addCandidate("Dave", "Candidate 4", makeAddr("dave"));

        (string[] memory names, , ) = voting.getCandidates();
        assertEq(names.length, 1);
    }

    // ============================================
    // WORKFLOW STATE MANAGEMENT TESTS (8 tests)
    // ============================================

    function test_InitialWorkflowIsRegisterCandidates() public view {
        assertEq(
            uint8(voting.currentStatus()),
            uint8(Voting.WorkflowStatus.REGISTER_CANDIDATES)
        );
    }

    function test_AdvanceToFoundCandidates() public {
        voting.setWorkflowStatus(Voting.WorkflowStatus.FOUND_CANDIDATES);
        assertEq(
            uint8(voting.currentStatus()),
            uint8(Voting.WorkflowStatus.FOUND_CANDIDATES)
        );
    }

    function test_AdvanceToVote() public {
        voting.setWorkflowStatus(Voting.WorkflowStatus.FOUND_CANDIDATES);
        voting.setWorkflowStatus(Voting.WorkflowStatus.VOTE);
        assertEq(
            uint8(voting.currentStatus()),
            uint8(Voting.WorkflowStatus.VOTE)
        );
        assertTrue(voting.voteStartTime() > 0);
    }

    function test_AdvanceToCompleted() public {
        voting.setWorkflowStatus(Voting.WorkflowStatus.FOUND_CANDIDATES);
        voting.setWorkflowStatus(Voting.WorkflowStatus.VOTE);
        voting.setWorkflowStatus(Voting.WorkflowStatus.COMPLETED);
        assertEq(
            uint8(voting.currentStatus()),
            uint8(Voting.WorkflowStatus.COMPLETED)
        );
    }

    function test_RevertWhen_SkippingWorkflowStates() public {
        vm.expectRevert("Must advance workflow sequentially");
        voting.setWorkflowStatus(Voting.WorkflowStatus.VOTE);
    }

    function test_RevertWhen_GoingBackwards() public {
        voting.setWorkflowStatus(Voting.WorkflowStatus.FOUND_CANDIDATES);
        vm.expectRevert("Must advance workflow sequentially");
        voting.setWorkflowStatus(Voting.WorkflowStatus.REGISTER_CANDIDATES);
    }

    function test_VoteStartTimeSetCorrectly() public {
        assertEq(voting.voteStartTime(), 0);

        voting.setWorkflowStatus(Voting.WorkflowStatus.FOUND_CANDIDATES);
        assertEq(voting.voteStartTime(), 0);

        voting.setWorkflowStatus(Voting.WorkflowStatus.VOTE);
        assertEq(voting.voteStartTime(), block.timestamp);
    }

    function test_WorkflowEvents() public {
        vm.expectEmit(true, true, true, true);
        emit Voting.WorkflowStatusChanged(Voting.WorkflowStatus.FOUND_CANDIDATES);
        voting.setWorkflowStatus(Voting.WorkflowStatus.FOUND_CANDIDATES);
    }

    // ============================================
    // CANDIDATE MANAGEMENT TESTS (7 tests)
    // ============================================

    function test_AddCandidateWithAddress() public {
        voting.addCandidate("Alice", "Candidate 1", candidateAddr1);
        (string[] memory names, , ) = voting.getCandidates();
        assertEq(names.length, 1);
        assertEq(names[0], "Alice");

        (
            string memory name,
            ,
            ,
            address addr,
            uint256 funds
        ) = voting.getCandidateDetails(0);
        assertEq(name, "Alice");
        assertEq(addr, candidateAddr1);
        assertEq(funds, 0);
    }

    function test_UpdateCandidateWithAddress() public {
        voting.addCandidate("Alice", "Candidate 1", candidateAddr1);

        address newAddr = makeAddr("newAddr");
        voting.updateCandidate(0, "Alicia", "Updated candidate", newAddr);

        (string memory name, string memory desc, , address addr, ) = voting
            .getCandidateDetails(0);
        assertEq(name, "Alicia");
        assertEq(desc, "Updated candidate");
        assertEq(addr, newAddr);
    }

    function test_DeleteCandidate() public {
        setupCandidates();
        (string[] memory namesBefore, , ) = voting.getCandidates();
        assertEq(namesBefore.length, 3);

        voting.deleteCandidate(1);

        (string[] memory namesAfter, , ) = voting.getCandidates();
        assertEq(namesAfter.length, 2);
    }

    function test_RevertWhen_AddingCandidateAfterRegistration() public {
        voting.setWorkflowStatus(Voting.WorkflowStatus.FOUND_CANDIDATES);

        vm.expectRevert("Can only add candidates during registration");
        voting.addCandidate("Bob", "Candidate 2", candidateAddr2);
    }

    function test_RevertWhen_NonAdminAddsCandidate() public {
        vm.prank(voter1);
        vm.expectRevert();
        voting.addCandidate("Bob", "Candidate 2", candidateAddr2);
    }

    function test_RevertWhen_InvalidCandidateAddress() public {
        vm.expectRevert("Invalid address");
        voting.addCandidate("Bob", "Candidate 2", address(0));
    }

    function test_GetCandidateDetails() public {
        voting.addCandidate("Alice", "Candidate 1", candidateAddr1);

        (
            string memory name,
            string memory desc,
            uint256 votes,
            address addr,
            uint256 funds
        ) = voting.getCandidateDetails(0);

        assertEq(name, "Alice");
        assertEq(desc, "Candidate 1");
        assertEq(votes, 0);
        assertEq(addr, candidateAddr1);
        assertEq(funds, 0);
    }

    // ============================================
    // FUNDING MECHANISM TESTS (9 tests)
    // ============================================

    function test_FundCandidateDuringFoundPeriod() public {
        setupCandidates();
        voting.setWorkflowStatus(Voting.WorkflowStatus.FOUND_CANDIDATES);

        vm.prank(founder1);
        voting.fundCandidate{value: 2 ether}(0);

        (, , , , uint256 funds) = voting.getCandidateDetails(0);
        assertEq(funds, 2 ether);
    }

    function test_MultipleFundsAccumulate() public {
        setupCandidates();
        voting.setWorkflowStatus(Voting.WorkflowStatus.FOUND_CANDIDATES);

        vm.prank(founder1);
        voting.fundCandidate{value: 1 ether}(0);

        vm.prank(founder1);
        voting.fundCandidate{value: 1.5 ether}(0);

        (, , , , uint256 funds) = voting.getCandidateDetails(0);
        assertEq(funds, 2.5 ether);
    }

    function test_FundsFromMultipleFounders() public {
        setupCandidates();
        voting.setWorkflowStatus(Voting.WorkflowStatus.FOUND_CANDIDATES);

        vm.prank(founder1);
        voting.fundCandidate{value: 2 ether}(0);

        vm.prank(founder2);
        voting.fundCandidate{value: 1 ether}(0);

        (, , , , uint256 funds) = voting.getCandidateDetails(0);
        assertEq(funds, 3 ether);
    }

    function test_WithdrawFundsByCandidate() public {
        setupCandidates();
        voting.setWorkflowStatus(Voting.WorkflowStatus.FOUND_CANDIDATES);

        vm.prank(founder1);
        voting.fundCandidate{value: 2 ether}(0);

        uint256 balanceBefore = candidateAddr1.balance;

        vm.prank(candidateAddr1);
        voting.withdrawFunds(0);

        assertEq(candidateAddr1.balance, balanceBefore + 2 ether);

        (, , , , uint256 funds) = voting.getCandidateDetails(0);
        assertEq(funds, 0);
    }

    function test_RevertWhen_NonCandidateWithdraws() public {
        setupCandidates();
        voting.setWorkflowStatus(Voting.WorkflowStatus.FOUND_CANDIDATES);

        vm.prank(founder1);
        voting.fundCandidate{value: 2 ether}(0);

        vm.prank(voter1);
        vm.expectRevert("Only candidate can withdraw");
        voting.withdrawFunds(0);
    }

    function test_RevertWhen_FundingOutsideFoundPeriod() public {
        setupCandidates();

        vm.prank(founder1);
        vm.expectRevert("Can only fund during founding period");
        voting.fundCandidate{value: 1 ether}(0);
    }

    function test_RevertWhen_FundingWithZeroValue() public {
        setupCandidates();
        voting.setWorkflowStatus(Voting.WorkflowStatus.FOUND_CANDIDATES);

        vm.prank(founder1);
        vm.expectRevert("Must send ETH");
        voting.fundCandidate{value: 0}(0);
    }

    function test_FundsResetAfterWithdraw() public {
        setupCandidates();
        voting.setWorkflowStatus(Voting.WorkflowStatus.FOUND_CANDIDATES);

        vm.prank(founder1);
        voting.fundCandidate{value: 2 ether}(0);

        vm.prank(candidateAddr1);
        voting.withdrawFunds(0);

        (, , , , uint256 funds) = voting.getCandidateDetails(0);
        assertEq(funds, 0);

        // Should revert if trying to withdraw again
        vm.prank(candidateAddr1);
        vm.expectRevert("No funds");
        voting.withdrawFunds(0);
    }

    // ============================================
    // VOTING DELAY TESTS (5 tests)
    // ============================================

    function test_VoteAfterDelay() public {
        setupCandidates();
        voting.setWorkflowStatus(Voting.WorkflowStatus.FOUND_CANDIDATES);
        voting.setWorkflowStatus(Voting.WorkflowStatus.VOTE);

        // Advance time by 1 hour + 1 second
        vm.warp(block.timestamp + 1 hours + 1);

        vm.prank(voter1);
        voting.vote(0);

        assertEq(nft.balanceOf(voter1), 1);
    }

    function test_RevertWhen_VotingBeforeDelay() public {
        setupCandidates();
        voting.setWorkflowStatus(Voting.WorkflowStatus.FOUND_CANDIDATES);
        voting.setWorkflowStatus(Voting.WorkflowStatus.VOTE);

        // Try to vote immediately
        vm.prank(voter1);
        vm.expectRevert("Voting delay not passed");
        voting.vote(0);
    }

    function test_DelayCalculation() public {
        setupCandidates();
        voting.setWorkflowStatus(Voting.WorkflowStatus.FOUND_CANDIDATES);
        voting.setWorkflowStatus(Voting.WorkflowStatus.VOTE);

        uint256 expectedVoteTime = voting.voteStartTime() + 1 hours;
        assertEq(voting.canVoteAt(), expectedVoteTime);
    }

    function test_VoteExactlyAtDelayExpiry() public {
        setupCandidates();
        voting.setWorkflowStatus(Voting.WorkflowStatus.FOUND_CANDIDATES);
        voting.setWorkflowStatus(Voting.WorkflowStatus.VOTE);

        // Advance time by exactly 1 hour
        vm.warp(block.timestamp + 1 hours);

        vm.prank(voter1);
        voting.vote(0);

        assertEq(nft.balanceOf(voter1), 1);
    }

    function test_MultipleVotesAfterDelay() public {
        setupCandidates();
        voting.setWorkflowStatus(Voting.WorkflowStatus.FOUND_CANDIDATES);
        voting.setWorkflowStatus(Voting.WorkflowStatus.VOTE);

        vm.warp(block.timestamp + 1 hours + 1);

        vm.prank(voter1);
        voting.vote(0);

        vm.prank(voter2);
        voting.vote(1);

        vm.prank(voter3);
        voting.vote(0);

        assertEq(nft.balanceOf(voter1), 1);
        assertEq(nft.balanceOf(voter2), 1);
        assertEq(nft.balanceOf(voter3), 1);
    }

    // ============================================
    // NFT INTEGRATION TESTS (8 tests)
    // ============================================

    function test_NFTMintedAfterVote() public {
        setupCandidates();
        voting.setWorkflowStatus(Voting.WorkflowStatus.FOUND_CANDIDATES);
        voting.setWorkflowStatus(Voting.WorkflowStatus.VOTE);
        vm.warp(block.timestamp + 1 hours + 1);

        assertEq(nft.balanceOf(voter1), 0);

        vm.prank(voter1);
        voting.vote(0);

        assertEq(nft.balanceOf(voter1), 1);
    }

    function test_RevertWhen_VotingTwiceWithNFTCheck() public {
        setupCandidates();
        voting.setWorkflowStatus(Voting.WorkflowStatus.FOUND_CANDIDATES);
        voting.setWorkflowStatus(Voting.WorkflowStatus.VOTE);
        vm.warp(block.timestamp + 1 hours + 1);

        vm.prank(voter1);
        voting.vote(0);

        vm.prank(voter1);
        vm.expectRevert("Already voted");
        voting.vote(1);
    }

    function test_NFTOwnershipCorrect() public {
        setupCandidates();
        voting.setWorkflowStatus(Voting.WorkflowStatus.FOUND_CANDIDATES);
        voting.setWorkflowStatus(Voting.WorkflowStatus.VOTE);
        vm.warp(block.timestamp + 1 hours + 1);

        vm.prank(voter1);
        voting.vote(0);

        assertEq(nft.ownerOf(0), voter1);
    }

    function test_TokenIdSequential() public {
        setupCandidates();
        voting.setWorkflowStatus(Voting.WorkflowStatus.FOUND_CANDIDATES);
        voting.setWorkflowStatus(Voting.WorkflowStatus.VOTE);
        vm.warp(block.timestamp + 1 hours + 1);

        vm.prank(voter1);
        voting.vote(0);

        vm.prank(voter2);
        voting.vote(1);

        assertEq(nft.ownerOf(0), voter1);
        assertEq(nft.ownerOf(1), voter2);
    }

    function test_MultipleVotersGetUniqueNFTs() public {
        setupCandidates();
        voting.setWorkflowStatus(Voting.WorkflowStatus.FOUND_CANDIDATES);
        voting.setWorkflowStatus(Voting.WorkflowStatus.VOTE);
        vm.warp(block.timestamp + 1 hours + 1);

        vm.prank(voter1);
        voting.vote(0);

        vm.prank(voter2);
        voting.vote(1);

        vm.prank(voter3);
        voting.vote(0);

        assertTrue(nft.ownerOf(0) != nft.ownerOf(1));
        assertTrue(nft.ownerOf(1) != nft.ownerOf(2));
    }

    function test_NFTContractOwnership() public view {
        assertEq(nft.owner(), address(voting));
    }

    function test_VoterToCandidateMapping() public {
        setupCandidates();
        voting.setWorkflowStatus(Voting.WorkflowStatus.FOUND_CANDIDATES);
        voting.setWorkflowStatus(Voting.WorkflowStatus.VOTE);
        vm.warp(block.timestamp + 1 hours + 1);

        vm.prank(voter1);
        voting.vote(0);

        vm.prank(voter2);
        voting.vote(2);

        assertEq(voting.voterToCandidate(voter1), 0);
        assertEq(voting.voterToCandidate(voter2), 2);
    }

    function test_GetUserVoteAfterNFT() public {
        setupCandidates();
        voting.setWorkflowStatus(Voting.WorkflowStatus.FOUND_CANDIDATES);
        voting.setWorkflowStatus(Voting.WorkflowStatus.VOTE);
        vm.warp(block.timestamp + 1 hours + 1);

        vm.prank(voter1);
        voting.vote(1);

        assertEq(voting.getUserVote(voter1), 1);
    }

    // ============================================
    // WINNER DETERMINATION TESTS (6 tests)
    // ============================================

    function test_GetWinnerInCompletedStatus() public {
        setupCandidates();
        voting.setWorkflowStatus(Voting.WorkflowStatus.FOUND_CANDIDATES);
        voting.setWorkflowStatus(Voting.WorkflowStatus.VOTE);
        vm.warp(block.timestamp + 1 hours + 1);

        vm.prank(voter1);
        voting.vote(0);

        vm.prank(voter2);
        voting.vote(0);

        voting.setWorkflowStatus(Voting.WorkflowStatus.COMPLETED);

        (string memory name, , uint256 votes, , ) = voting.getWinner();
        assertEq(name, "Alice");
        assertEq(votes, 2);
    }

    function test_WinnerWithMostVotes() public {
        setupCandidates();
        voting.setWorkflowStatus(Voting.WorkflowStatus.FOUND_CANDIDATES);
        voting.setWorkflowStatus(Voting.WorkflowStatus.VOTE);
        vm.warp(block.timestamp + 1 hours + 1);

        vm.prank(voter1);
        voting.vote(1); // Bob

        vm.prank(voter2);
        voting.vote(1); // Bob

        vm.prank(voter3);
        voting.vote(2); // Charlie

        voting.setWorkflowStatus(Voting.WorkflowStatus.COMPLETED);

        (string memory name, , uint256 votes, , ) = voting.getWinner();
        assertEq(name, "Bob");
        assertEq(votes, 2);
    }

    function test_WinnerIncludesFunds() public {
        setupCandidates();
        voting.setWorkflowStatus(Voting.WorkflowStatus.FOUND_CANDIDATES);

        vm.prank(founder1);
        voting.fundCandidate{value: 5 ether}(0);

        voting.setWorkflowStatus(Voting.WorkflowStatus.VOTE);
        vm.warp(block.timestamp + 1 hours + 1);

        vm.prank(voter1);
        voting.vote(0);

        voting.setWorkflowStatus(Voting.WorkflowStatus.COMPLETED);

        (
            string memory name,
            ,
            uint256 votes,
            address addr,
            uint256 funds
        ) = voting.getWinner();
        assertEq(name, "Alice");
        assertEq(votes, 1);
        assertEq(addr, candidateAddr1);
        assertEq(funds, 5 ether);
    }

    function test_TieGoesToFirstCandidate() public {
        setupCandidates();
        voting.setWorkflowStatus(Voting.WorkflowStatus.FOUND_CANDIDATES);
        voting.setWorkflowStatus(Voting.WorkflowStatus.VOTE);
        vm.warp(block.timestamp + 1 hours + 1);

        vm.prank(voter1);
        voting.vote(0);

        vm.prank(voter2);
        voting.vote(1);

        voting.setWorkflowStatus(Voting.WorkflowStatus.COMPLETED);

        (string memory name, , uint256 votes, , ) = voting.getWinner();
        assertEq(name, "Alice");
        assertEq(votes, 1);
    }

    function test_RevertWhen_GetWinnerBeforeCompleted() public {
        setupCandidates();
        voting.setWorkflowStatus(Voting.WorkflowStatus.FOUND_CANDIDATES);
        voting.setWorkflowStatus(Voting.WorkflowStatus.VOTE);

        vm.expectRevert("Voting not completed");
        voting.getWinner();
    }

    function test_GetWinnerWithNoVotes() public {
        setupCandidates();
        voting.setWorkflowStatus(Voting.WorkflowStatus.FOUND_CANDIDATES);
        voting.setWorkflowStatus(Voting.WorkflowStatus.VOTE);
        vm.warp(block.timestamp + 1 hours + 1);

        // No votes cast

        voting.setWorkflowStatus(Voting.WorkflowStatus.COMPLETED);

        (string memory name, , uint256 votes, , ) = voting.getWinner();
        assertEq(name, "Alice"); // First candidate wins with 0 votes
        assertEq(votes, 0);
    }

    // ============================================
    // INTEGRATION TESTS (5 tests)
    // ============================================

    function test_FullWorkflowIntegration() public {
        // Step 1: Register candidates
        setupCandidates();

        // Step 2: Advance to funding
        voting.setWorkflowStatus(Voting.WorkflowStatus.FOUND_CANDIDATES);

        // Step 3: Fund candidates
        vm.prank(founder1);
        voting.fundCandidate{value: 2 ether}(0);

        vm.prank(founder2);
        voting.fundCandidate{value: 1 ether}(1);

        // Step 4: Advance to voting
        voting.setWorkflowStatus(Voting.WorkflowStatus.VOTE);
        vm.warp(block.timestamp + 1 hours + 1);

        // Step 5: Vote
        vm.prank(voter1);
        voting.vote(0);

        vm.prank(voter2);
        voting.vote(0);

        vm.prank(voter3);
        voting.vote(1);

        // Step 6: Complete voting
        voting.setWorkflowStatus(Voting.WorkflowStatus.COMPLETED);

        // Step 7: Check winner
        (
            string memory name,
            ,
            uint256 votes,
            address addr,
            uint256 funds
        ) = voting.getWinner();
        assertEq(name, "Alice");
        assertEq(votes, 2);
        assertEq(addr, candidateAddr1);
        assertEq(funds, 2 ether);
    }

    function test_CandidateReceivesFundsAndWins() public {
        setupCandidates();
        voting.setWorkflowStatus(Voting.WorkflowStatus.FOUND_CANDIDATES);

        vm.prank(founder1);
        voting.fundCandidate{value: 3 ether}(1);

        voting.setWorkflowStatus(Voting.WorkflowStatus.VOTE);
        vm.warp(block.timestamp + 1 hours + 1);

        vm.prank(voter1);
        voting.vote(1);

        vm.prank(voter2);
        voting.vote(1);

        voting.setWorkflowStatus(Voting.WorkflowStatus.COMPLETED);

        (string memory name, , , , uint256 funds) = voting.getWinner();
        assertEq(name, "Bob");
        assertEq(funds, 3 ether);

        // Candidate withdraws
        vm.prank(candidateAddr2);
        voting.withdrawFunds(1);
        assertEq(candidateAddr2.balance, 3 ether);
    }

    function test_MultipleRolesInteraction() public {
        // Admin adds candidates
        setupCandidates();

        // Founder funds
        voting.setWorkflowStatus(Voting.WorkflowStatus.FOUND_CANDIDATES);
        vm.prank(founder1);
        voting.fundCandidate{value: 1 ether}(0);

        // Voters vote
        voting.setWorkflowStatus(Voting.WorkflowStatus.VOTE);
        vm.warp(block.timestamp + 1 hours + 1);
        vm.prank(voter1);
        voting.vote(0);

        // Admin completes
        voting.setWorkflowStatus(Voting.WorkflowStatus.COMPLETED);

        // Verify everything worked
        (, , uint256 votes, , uint256 funds) = voting.getWinner();
        assertEq(votes, 1);
        assertEq(funds, 1 ether);
    }

    function test_EmergencyAdminControl() public {
        // Admin can skip to completed even without votes
        setupCandidates();
        voting.setWorkflowStatus(Voting.WorkflowStatus.FOUND_CANDIDATES);
        voting.setWorkflowStatus(Voting.WorkflowStatus.VOTE);
        voting.setWorkflowStatus(Voting.WorkflowStatus.COMPLETED);

        assertEq(
            uint8(voting.currentStatus()),
            uint8(Voting.WorkflowStatus.COMPLETED)
        );
    }

    function test_EventEmissionThroughWorkflow() public {
        // Test candidate added event
        vm.expectEmit(true, true, true, true);
        emit Voting.CandidateAdded("Alice", "Candidate 1", candidateAddr1);
        voting.addCandidate("Alice", "Candidate 1", candidateAddr1);

        // Test workflow changed event
        vm.expectEmit(true, true, true, true);
        emit Voting.WorkflowStatusChanged(Voting.WorkflowStatus.FOUND_CANDIDATES);
        voting.setWorkflowStatus(Voting.WorkflowStatus.FOUND_CANDIDATES);

        // Test funding event
        vm.expectEmit(true, true, true, true);
        emit Voting.CandidateFunded(0, founder1, 1 ether);
        vm.prank(founder1);
        voting.fundCandidate{value: 1 ether}(0);

        // Test vote event
        voting.setWorkflowStatus(Voting.WorkflowStatus.VOTE);
        vm.warp(block.timestamp + 1 hours + 1);
        vm.expectEmit(true, true, true, true);
        emit Voting.Voted(voter1, 0);
        vm.prank(voter1);
        voting.vote(0);
    }
}
