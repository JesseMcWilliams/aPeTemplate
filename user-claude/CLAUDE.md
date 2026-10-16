# Personal Claude Code preferences

These apply in every project on every host. The source is `user-claude/CLAUDE.md` in the aPeTemplate repo, and `%USERPROFILE%\.claude\CLAUDE.md` is a symbolic link to it, created by `Install-UserClaudeMd.ps1`. Edit the repo copy, not the link.

## Communication
- Present actions (taken or proposed), open items, options and questions as **numbered lists**, so I can answer by number. Keep the numbers stable within a thread, and when I reply using numbers, keep using mine.
- Prefix each number with a letter for its kind so it's easy to reference: questions are **always** `Q1`, `Q2`...; decisions `D#`, proposals `P#`. Pick an obvious letter for any other kind. Never reuse or renumber an ID; an answered item keeps its ID.

## Git
- When I ask you to merge a PR, delete its branch in the same step: `gh pr merge <n> --merge --delete-branch`. If the branch delete is refused, say so and give me the command; don't try another way around it.
