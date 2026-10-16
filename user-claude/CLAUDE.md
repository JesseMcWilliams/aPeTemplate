# Personal Claude Code preferences

These apply in every project on every host. The source is `user-claude/CLAUDE.md` in the aPeTemplate repo, and `%USERPROFILE%\.claude\CLAUDE.md` is a symbolic link to it, created by `Install-UserClaudeMd.ps1`. Edit the repo copy, not the link.

## Communication

- Present actions (taken or proposed), open items and options as **numbered lists** (1, 2, 3), so I can answer by number.
- Number **questions** with a **Q** prefix (Q1, Q2, ...) and write my **answers** with an **A** prefix (A1 answers Q1). When I answer with a bare number, treat it as the item with that number in your most recent list.
- Because a bare number can mean an option or a question, say which list you mean when more than one is on screen (for example "Q3" or "option 3"), and don't reuse a number across the lists in one message.
- Number items that live in a document with a **D** prefix on screen (D174 is question 174 in the project's questions doc); inside the document the number stays plain, and document numbers never reset. I'll answer-match `D174: <answer>`. When a document other than the default questions list is meant, name it ("Backlog D16").
- **Exception: kind-labeled documents.** A planning or design doc may label its items by kind instead of plain numbers: **D#** decisions, **P#** proposals, **Q#** questions. Those labels are used as-is inside the doc and on screen, so there "D12" means decision 12, not item 12. Name the doc on screen ("Planning D12", "Planning Q5") so they aren't confused with the questions doc or chat questions. These IDs never reset or get reused, and an answered question keeps its Q number and points to the decision that answered it.
- Keep numbers stable within a thread, and when I reply using numbers, keep using mine.
- When a numbering sequence passes 100, restart at 1 only if no earlier item with a number being reused is still open, referenced by a doc or a later message, or likely to be confused with the new one. Otherwise keep counting.

## Git
- When I ask you to merge a PR, delete its branch in the same step: `gh pr merge <n> --merge --delete-branch`. If the branch delete is refused, say so and give me the command; don't try another way around it.

