alias b := build
alias r := run
alias d := debug
alias am := add-mcp
alias as := add-skill

add-skill:
  npx skills install openzeppelin/openzeppelin-skills@develop-secure-contracts

add-mcp:
  claude mcp add --transport stdio solidity-synthesis -- mcp_synth --cwd . --project auction-deepseek-flash --invariants 1

build:
    forge b
debug:
  claude --debug mcp --debug-file /tmp/claude_debug.log --append-system-prompt-file prompt.md --dangerously-skip-permissions
run:
    claude --append-system-prompt-file prompt.md --dangerously-skip-permissions
install:
  forge install foundry-rs/forge-std && \
  forge install OpenZeppelin/openzeppelin-foundry-upgrades &&  \
  forge install OpenZeppelin/openzeppelin-contracts-upgradeable
