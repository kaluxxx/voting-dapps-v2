// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract VotingNFT is ERC721, Ownable {
    uint256 private _tokenIdCounter;

    constructor()
        ERC721("Voting Participation NFT", "VOTE")
        Ownable(msg.sender)
    {}

    function mint(address to) external onlyOwner returns (uint256) {
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;
        _safeMint(to, tokenId);
        return tokenId;
    }
}
