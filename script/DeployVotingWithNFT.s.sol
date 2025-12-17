// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {VotingNFT} from "../src/VotingNFT.sol";
import {Voting} from "../src/Voting.sol";

contract DeployVotingWithNFT is Script {
    function run() external returns (Voting, VotingNFT) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying with account:", deployer);
        console.log("Account balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy VotingNFT
        VotingNFT nft = new VotingNFT();
        console.log("VotingNFT deployed at:", address(nft));

        // 2. Deploy Voting with NFT address
        Voting voting = new Voting(address(nft));
        console.log("Voting deployed at:", address(voting));

        // 3. Transfer NFT ownership to Voting contract
        nft.transferOwnership(address(voting));
        console.log("NFT ownership transferred to Voting contract");

        // Log role information
        console.log(
            "Deployer has DEFAULT_ADMIN_ROLE:",
            voting.hasRole(voting.DEFAULT_ADMIN_ROLE(), deployer)
        );
        console.log(
            "Deployer has ADMIN_ROLE:",
            voting.hasRole(voting.ADMIN_ROLE(), deployer)
        );

        vm.stopBroadcast();

        // Save deployment addresses for verification
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("VotingNFT:", address(nft));
        console.log("Voting:", address(voting));
        console.log(
            "Network:",
            block.chainid == 11155111 ? "Sepolia" : "Unknown"
        );

        return (voting, nft);
    }
}
