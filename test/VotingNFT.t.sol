// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {VotingNFT} from "../src/VotingNFT.sol";

contract VotingNFTTest is Test {
    VotingNFT public nft;
    address public owner;
    address public voter;

    function setUp() public {
        owner = address(this);
        voter = makeAddr("voter");
        nft = new VotingNFT();
    }

    // Test: Initial state
    function test_InitialState() public view {
        assertEq(nft.name(), "Voting Participation NFT");
        assertEq(nft.symbol(), "VOTE");
        assertEq(nft.owner(), owner);
    }

    // Test: Mint by owner
    function test_MintByOwner() public {
        uint256 tokenId = nft.mint(voter);
        assertEq(tokenId, 0);
        assertEq(nft.balanceOf(voter), 1);
        assertEq(nft.ownerOf(0), voter);
    }

    // Test: Revert when non-owner mints
    function test_RevertWhen_NonOwnerMints() public {
        vm.prank(voter);
        vm.expectRevert();
        nft.mint(voter);
    }

    // Test: Token ID increment
    function test_TokenIdIncrement() public {
        address voter1 = makeAddr("voter1");
        address voter2 = makeAddr("voter2");
        address voter3 = makeAddr("voter3");

        uint256 tokenId1 = nft.mint(voter1);
        uint256 tokenId2 = nft.mint(voter2);
        uint256 tokenId3 = nft.mint(voter3);

        assertEq(tokenId1, 0);
        assertEq(tokenId2, 1);
        assertEq(tokenId3, 2);
    }

    // Test: Balance tracking
    function test_BalanceTracking() public {
        assertEq(nft.balanceOf(voter), 0);

        nft.mint(voter);
        assertEq(nft.balanceOf(voter), 1);

        nft.mint(voter);
        assertEq(nft.balanceOf(voter), 2);
    }

    // Test: Multiple mints to same address
    function test_MultipleMintsToSameAddress() public {
        nft.mint(voter);
        nft.mint(voter);
        nft.mint(voter);

        assertEq(nft.balanceOf(voter), 3);
        assertEq(nft.ownerOf(0), voter);
        assertEq(nft.ownerOf(1), voter);
        assertEq(nft.ownerOf(2), voter);
    }
}
