---
name: ape-project-setup
description: Set up or retrofit an aPe* project (aPePAS, aPeDiscovery, aPeSecrets, or a new one) with the standard Claude Code files - runs C:\Code\aPeTemplate\New-ApeProject.ps1, then fills CLAUDE.md's FILL markers from the real code. Use when the user asks to start a new aPe project, scaffold a project, add a CLAUDE.md, or retrofit a project with the template.
---

# aPe project setup

The deterministic work (folders, file copies, .gitignore merge, git init) is done by a script. Your job is only the part that needs judgment: filling in CLAUDE.md from the actual code. Keep token use low.

## 1. Run the scaffold script

Work out the project name and parent folder (default `C:\Code`) from the user's request or the current working directory. Use `-Existing` if the folder already has content. Preview first, then run:

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Code\aPeTemplate\New-ApeProject.ps1 -Name <Name> [-Existing] [-Description '<one line>'] -WhatIf
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Code\aPeTemplate\New-ApeProject.ps1 -Name <Name> [-Existing] [-Description '<one line>']
```

The script never overwrites files. If it reports `CLAUDE.md skipped (already exists)` and the file has no `<!-- FILL:` markers, stop and tell the user. Don't rewrite an existing CLAUDE.md unless they ask.

## 2. Gather facts cheaply

Use only the listings, headings and small reads you need. Don't read whole large files.
- the top-level listing and one level down (`ls`), plus `git log --oneline -15`
- the test runner's comment-based help and `param()` block only
- the README headings (`grep -n '^## '`) and the Docs/ file list with their headings
- `.gitignore`, to find the runtime output Claude should not read
- the line counts of the largest source files (`wc -l`), to flag the ones over ~1,000 lines

## 3. Fill the FILL markers

Replace each `<!-- FILL: ... -->` marker in CLAUDE.md, following its instruction.
- **Hard limit of 80 lines.** CLAUDE.md is loaded on every call.
- Include only facts you confirmed in step 2. If you can't confirm something (e.g. a test command), leave a `<!-- TODO: ... -->` rather than guessing.
- Point to the doc and section that holds the detail rather than copying it.
- Keep the template's generic sections (Git, Live testing, doc-size rules) unless the repo contradicts them.
- Never put hostnames, tenants, App IDs or credentials in CLAUDE.md. Those belong in the gitignored `Live-Testing.local.md`, and secrets belong in neither file.

Show the user the filled CLAUDE.md, with a one-line note on anything you left as TODO, and write it only after they approve.

## 4. Finish

Report what the script created, skipped or appended, and any TODOs left in CLAUDE.md. Don't commit or push unless the user asks.
