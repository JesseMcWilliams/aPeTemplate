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

## Documentation layout
- `README.md` (root): an **overview only**. It covers purpose, requirements, a quick start and a short feature list, and links to `User_Docs/` and `Claude_Docs/` for everything else. Put detail in a doc and link to it rather than adding it to the README.
- `Claude_Docs/` holds every doc Claude creates or works from, named `<Stage>_<Topic-With-Hyphens>.md`:
  - `Planning_`: proposals and backlogs that aren't built yet. Once built, the doc becomes `Design_` or is renamed `Archive_Planning_...`.
  - `Design_`: how the current system works. Keep it current. Archive it only when the feature is removed or replaced.
  - `Testing_`: test plans, open findings and known issues. Closed findings move to `Archive_Testing_...`.
  - `Reference_`: rules that apply at every stage (lessons learned, conventions, interface contracts).
  - `Archive_<OriginalStage>_<Topic>.md`: finished or superseded material. **Don't read `Archive_*` unless the user asks or the task needs history.**
- `User_Docs/`: end-user documentation, usually written near the end of the project from `Claude_Docs/Planning_User-Docs-Backlog.md`. It's output, not a source of facts. Take facts from the code and `Claude_Docs/`.
- `Published_Docs/`: `.docx` deliverables for end users (for example installation guides), refreshed from `User_Docs/` and `Claude_Docs/` when a release is created. Don't read them for facts, and don't edit them between releases.
- When you make a user-visible change, add one line for it to `Planning_User-Docs-Backlog.md`.
- Keep each doc to about 500 lines. Past that, move closed or old content into an `Archive_` file. Don't keep revision logs, because git has the history. Put dates in file names only for point-in-time snapshots, such as reviews.
- Rename docs with `git mv`, and update every link to them in the same change.
- If a doc is large, find the target with grep and read a narrow range. Keep table rows to one or two sentences.

## Docs: what to update for each kind of change
| Change | Update |
|---|---|
<!-- FILL: one row per change type (new feature, bug fix, design decision, new gotcha), mapped to the real Claude_Docs/ files in this repo. Include the Planning_User-Docs-Backlog.md line for user-visible changes. -->

- For "verify the docs are updated", use a subagent to diff the branch against this checklist and report the gaps only.

## Git
- Don't work directly on `main`. Create a topic branch named `YYYY-MM-DD-<topic>` and open a PR into `main` with `gh`.
- Commit, push, open a PR or merge only when asked. "Commit and push" means both.

## Live testing
- Lab environment details are in `Live-Testing.local.md` in the project root. That file is gitignored. **Read it only when a task involves live testing.** Never copy its contents into tracked files, commit messages or PR descriptions.
- If `Live-Testing.local.md` is missing, ask for the details. Don't guess.
- Live tests are defined by label (`LT-*`) in `Claude_Docs/Testing_Live-Test-Definitions.md`, with `{Placeholder}` values only. `Live-Testing.local.md` fills in the placeholders per environment and tracks which labels have run. Add new tests to the definitions file, never lab values.
- Never write secrets into any file, log or commit message, including `Live-Testing.local.md`. That file names *where* the credentials live, not the credentials themselves.
- When an example, doc or test needs a password placeholder, use `ThisIsMy_FAKE_Password6!`. It's obviously fake, and it satisfies typical complexity rules.
