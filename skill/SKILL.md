---
name: ape-project-setup
description: Set up or retrofit an aPe* project (aPePAS, aPeDiscovery, aPeSecrets, or a new one) with the standard Claude Code files and doc layout (Claude_Docs/ with stage prefixes, User_Docs/, overview README) - runs C:\Code\aPeTemplate\New-ApeProject.ps1, fills CLAUDE.md's FILL markers from the real code, and migrates a legacy Docs/ folder. Use when the user asks to start a new aPe project, scaffold a project, add a CLAUDE.md, migrate docs to Claude_Docs, or retrofit a project with the template.
---

# aPe project setup

The deterministic work (folders, file copies, .gitignore merge, git init) is done by a script. Your job is only the part that needs judgment: filling in CLAUDE.md from the actual code, and classifying docs during a migration. Keep token use low.

The doc layout rules live in the "Documentation layout" section of `C:\Code\aPeTemplate\templates\CLAUDE.template.md`. Follow that section; it isn't repeated here.

## 1. Run the scaffold script

Work out the project name and parent folder (default `C:\Code`) from the user's request or the current working directory. Use `-Existing` if the folder already has content. Preview first, then run:

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Code\aPeTemplate\New-ApeProject.ps1 -Name <Name> [-Existing] [-Description '<one line>'] -WhatIf
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Code\aPeTemplate\New-ApeProject.ps1 -Name <Name> [-Existing] [-Description '<one line>']
```

The script never overwrites files. If `CLAUDE.md` already exists and has no `<!-- FILL:` markers, don't rewrite it. Instead, add the template's "Documentation layout" section if it's missing, and tell the user.

## 2. Gather facts cheaply

Use only the listings, headings and small reads you need. Don't read whole large files.
- the top-level listing and one level down (`ls`), plus `git log --oneline -15`
- the test runner's comment-based help and `param()` block only
- the README headings (`grep -n '^## '`) and the doc file list with their headings
- `.gitignore`, to find the runtime output Claude should not read
- the line counts of the largest source files (`wc -l`), to flag the ones over ~1,000 lines

## 3. Fill the FILL markers

Replace each `<!-- FILL: ... -->` marker in CLAUDE.md, following its instruction.
- **Hard limit of about 90 lines.** CLAUDE.md is loaded on every call.
- Include only facts you confirmed in step 2. If you can't confirm something (e.g. a test command), leave a `<!-- TODO: ... -->` rather than guessing.
- Point to the doc and section that holds the detail rather than copying it.
- Keep the template's generic sections (Documentation layout, Git, Live testing) unless the repo contradicts them.
- Never put hostnames, tenants, App IDs, safe or object names, or credentials in CLAUDE.md. Those belong in the gitignored `Live-Testing.local.md`, and secrets belong in neither file. For a placeholder password, use `ThisIsMy_FAKE_Password6!`.

Show the user the filled CLAUDE.md, with a one-line note on anything you left as TODO, and write it only after they approve.

## 4. Migrate a legacy `Docs/` folder (when present)

1. **Classify each doc** from its title, any `Status:` line and its headings. Don't read whole files. Map each one to `Claude_Docs/<Stage>_<Topic>.md` or `User_Docs/<Name>.md`:
   - implemented designs that describe current behavior → `Design_`
   - one-off plans, migrations or status notes that are finished → `Archive_Planning_` or `Archive_Design_`
   - proposals that aren't started, or aren't confirmed finished → `Planning_`
   - conventions, lessons learned, interface contracts → `Reference_`
   - guides written for end users → `User_Docs/`
   - lab details (hosts, App IDs, safes, objects) → out of tracked docs and into `Live-Testing.local.md`
2. **Show the mapping table**, marking the rows you're unsure about, and get approval before moving anything.
3. **Move the files** with `git mv` on a `YYYY-MM-DD-<topic>` branch. Split out oversized sections (revision logs, closed findings) into `Archive_` files with a script. Don't read them into context.
4. **Update every link** to a moved doc (README, CLAUDE.md, other docs, code comments) with a scripted old→new replacement across the tracked text files. Then grep for any leftover `Docs/` or `Docs\` references.
5. **Make the README an overview**: purpose, requirements, quick start, a short feature list, and links to the docs. Move detailed sections into the right doc rather than deleting them.
6. **Run the unit tests** in case any test reads doc paths. Then report the result. Don't commit unless asked.

## 5. Finish

Report what the script created, skipped or appended, any TODOs left in CLAUDE.md, and any migration rows the user should double-check. Don't commit or push unless the user asks.
