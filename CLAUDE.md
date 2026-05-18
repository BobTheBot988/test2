# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture

This is a Foundry-based Ethereum smart contract project implementing an **Auction system** with:

- **Auction.sol** (\`src/Auction.sol\`): Core auction contract managing ERC20 bids and ERC721 NFT items
- **RealNFT.sol** (\`src/impls/RealNFT.sol\`): ZPunks ERC721 NFT contract with URI storage
- **realtoken.sol** (\`src/impls/realtoken.sol\`): MyToken ERC20 token contract

The test suite (\`test/System.invariant.t.sol\`) uses invariant testing to verify the auction's \`getWinner()\` function correctly identifies the highest bidder.

## Common Commands

| Command | Description |
|---------|-------------|
| \`forge build\` | Compile smart contracts |
| \`forge test\` | Run tests |
| \`forge test -vvv\` | Run tests with verbose output |
| \`forge fmt\` | Format Solidity code |
| \`forge snapshot\` | Generate gas snapshots |
| \`forge build --sizes\` | Build with contract size info |

## Configuration

- **Solidity version**: ^0.8.33 (compiler), ^0.8.27 (NFT), ^0.8.20 (token)
- **EVM version**: Prague
- **Test framework**: Forge Std
- **Libraries**: OpenZeppelin Contracts 5.6.0
