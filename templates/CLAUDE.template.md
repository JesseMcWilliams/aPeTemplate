# {{ProjectName}}: Claude Code project notes

{{Description}}
<!-- FILL: one or two sentences: what the project does, its runtime target (e.g. Windows PowerShell 5.1), and whether strict mode is always on. -->

## Folder map
<!-- FILL: one line per top-level folder or key file. Flag any file over ~1,000 lines: "grep for the function and read a line range; don't read the whole file." List gitignored runtime output that Claude should not read. -->
- External references are in `C:\Code\References\`. Check there before guessing at API behavior.

## Tests
<!-- FILL: the exact commands, confirmed from the test runner's param() block: run all, run one file, and a PS 5.1 check if relevant. -->
- Redirect test output to a file and read only the summary or failures. Don't stream full test output into the conversation.
- The suite must stay at 100% pass. Run the single test file while iterating and the full suite before you commit.

## Code rules (details in the linked sections, not repeated here)
<!-- FILL: one line per convention, each pointing to the doc and section that holds the detail. Include only conventions that exist in this repo today. -->

## Docs: what to update for each kind of change
| Change | Update |
|---|---|
<!-- FILL: one row per change type (new feature, bug fix, design decision, new gotcha), mapped to the real docs in this repo. -->

- If a doc has grown large, find the target with grep and read a narrow range. Don't read it whole.
- Keep new table rows to one or two sentences. Revision history belongs in git, not in the docs.
- For "verify the docs are updated", use a subagent to diff the branch against this checklist and report the gaps only.

## Git
- Don't work directly on `main`. Create a topic branch named `YYYY-MM-DD-<topic>` and open a PR into `main` with `gh`.
- Commit, push, open a PR or merge only when asked. "Commit and push" means both.

## Live testing
- Lab environment details are in `Live-Testing.local.md` in the project root. That file is gitignored. **Read it only when a task involves live testing.** Never copy its contents into tracked files, commit messages or PR descriptions.
- If `Live-Testing.local.md` is missing, ask for the details. Don't guess.
- Never write secrets into any file, log or commit message, including `Live-Testing.local.md`. That file names *where* the credentials live, not the credentials themselves.
