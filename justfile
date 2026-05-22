alias b := build
alias r := run

build:
    forge b
run:
    claude --append-system-prompt-file prompt.md --dangerously-skip-permissions
