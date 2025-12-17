# Deploy to Sepolia testnet via Alchemy (PowerShell)
# Usage: .\deploy-testnet.ps1

$ErrorActionPreference = "Stop"

# Add Foundry to PATH
$env:PATH = "$env:USERPROFILE\.foundry\bin;$env:PATH"

Write-Host "========================================"
Write-Host "  DEPLOY TO SEPOLIA (Alchemy)"
Write-Host "========================================"

# Load environment variables from .env
Get-Content .env | ForEach-Object {
    if ($_ -match "^([^#][^=]+)=(.*)$") {
        $name = $matches[1].Trim()
        $value = $matches[2].Trim()
        Set-Item -Path "Env:$name" -Value $value
    }
}

# Check required variables
if ($env:PRIVATE_KEY -eq "your_wallet_private_key_here" -or [string]::IsNullOrEmpty($env:PRIVATE_KEY)) {
    Write-Host "Error: Please set your PRIVATE_KEY in .env" -ForegroundColor Red
    exit 1
}

if ($env:SEPOLIA_RPC_URL -match "YOUR_ALCHEMY_API_KEY" -or [string]::IsNullOrEmpty($env:SEPOLIA_RPC_URL)) {
    Write-Host "Error: Please set your SEPOLIA_RPC_URL in .env" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[1/3] Compiling contracts..."
forge build

Write-Host ""
Write-Host "[2/3] Deploying to Sepolia..."
forge script script/DeployVotingWithNFT.s.sol `
    --rpc-url $env:SEPOLIA_RPC_URL `
    --private-key $env:PRIVATE_KEY `
    --broadcast `
    -vvv

Write-Host ""
Write-Host "[3/3] Deployment complete!"
Write-Host ""
Write-Host "========================================"
Write-Host "Check your contract on Etherscan:"
Write-Host "https://sepolia.etherscan.io/"
Write-Host "========================================"
