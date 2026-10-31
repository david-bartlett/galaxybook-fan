# galaxybook-fan --help as a table

PR #30 · Claude · 2026-10-31

## What changed
- `lib/galaxybook-fan`: `cmd_help` prints the commands in a box table (command | what it does), 80 columns, descriptions wrapped in their cell with `fold`, commands and headings bold on a terminal (`$B`, empty when not a tty). It replaced printing the header comment with `sed`. No arguments still prints it and exits 1.
- Header comment and help: `updates on|off` (sudo) and `updates status` separate; "daily" → every 6 hours (since #28).
- CHANGELOG, PLAN.md §4.

## Why
- David: the two-column help ran together and was hard to read. He saw a mock-up in Konsole first.

## Tested
- Every line 80 characters; bold codes only under a tty (`script`); `--help` exit 0, no arguments exit 1; `bash -n`, shellcheck (no new notes).

## For the next person
- A new command needs a row in `cmd_help` and a line in the header comment.
