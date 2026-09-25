# aPeTemplate

This repo scaffolds new aPe* projects, and retrofits existing ones, with a standard Claude Code setup that keeps token use low.

## What it sets up

| File | Purpose |
|---|---|
| `CLAUDE.md` | A lean project guide that Claude Code loads every session. It's created with `<!-- FILL: -->` markers for the project-specific parts. |
| `Live-Testing.local.md` | Lab details (URLs, tenants, App IDs, test fixtures). Gitignored, and read only when a task involves live testing. Never put secrets in it. |
| `.gitignore` | The base entries (`*.local.md`, logs, CSVs, credential files). An existing `.gitignore` is merged: missing entries are appended. |
| `README.md` | An overview-only README (purpose, requirements, quick start, links to the docs). It's created only if the project doesn't have one. |
| `Claude_Docs/` (new projects) | Skeleton `Design_Architecture.md`, `Testing_Plan.md`, `Reference_Lessons-Learned.md` and `Planning_User-Docs-Backlog.md`, set up so they don't grow revision logs. |

The script never overwrites an existing file, so it's safe to run again.

## Documentation layout

| Location | Holds |
|---|---|
| `README.md` | Overview only. It links to the docs below rather than repeating them. |
| `Claude_Docs/` | Every doc Claude creates or works from, named `<Stage>_<Topic-With-Hyphens>.md`. |
| `User_Docs/` | End-user documentation, usually written near the end of a project from `Claude_Docs/Planning_User-Docs-Backlog.md`. The script doesn't create this folder. |

| Stage prefix | Use for | When the work is done |
|---|---|---|
| `Planning_` | Proposals and backlogs that aren't built yet | It becomes `Design_`, or it's renamed `Archive_Planning_...` |
| `Design_` | How the current system works | It's kept current, and archived only when the feature is removed or replaced |
| `Testing_` | Test plans, open findings, known issues | Closed findings move to `Archive_Testing_...` |
| `Reference_` | Rules that apply at every stage (lessons learned, conventions, interfaces) | It's kept current, and split by topic once it passes about 500 lines |
| `Archive_<OriginalStage>_` | Finished or superseded material | Claude doesn't read it unless asked |

The full rules Claude follows are in the "Documentation layout" section of [templates/CLAUDE.template.md](templates/CLAUDE.template.md).

## Usage

```powershell
# New project (creates C:\Code\aPeFoo, runs git init; nothing is committed)
.\New-ApeProject.ps1 -Name aPeFoo -Description 'Exports foo from CyberArk.'

# Retrofit an existing project (preview first)
.\New-ApeProject.ps1 -Name aPeDiscovery -Existing -WhatIf
.\New-ApeProject.ps1 -Name aPeDiscovery -Existing

# Retrofit and also add any skeleton docs that are missing
.\New-ApeProject.ps1 -Name aPeDiscovery -Existing -IncludeDocs
```

Then open the project folder in VS Code, start Claude Code, and ask it to *"run the ape-project-setup skill"* (or say "set up CLAUDE.md for this project"). The skill fills the FILL markers from the real code and shows you the draft before writing it. If the project still has a legacy `Docs` folder, the skill can also migrate it to `Claude_Docs` and `User_Docs`: it proposes a mapping table for you to approve, then uses `git mv` and updates the links.

## The skill

Claude Code loads the skill from `%USERPROFILE%\.claude\skills\ape-project-setup\`, because it's a personal skill that's available in every project. The source is `skill/SKILL.md` in this repo. Run this once per host, from wherever you cloned the repo:

```powershell
.\Install-Skill.ps1 -WhatIf   # preview
.\Install-Skill.ps1
```

This makes the skill folder a directory junction to this repo's `skill\` folder, so there's only one copy and a `git pull` updates the installed skill. An older copied install is moved to `%USERPROFILE%\.claude\skill-backups\`. Use `-Force` to repoint a junction that goes to another clone. Start a new Claude Code session afterwards. The skill finds this repo from the junction target, so the clone doesn't have to be at `C:\Code\aPeTemplate`.

## User-level CLAUDE.md

`user-claude/CLAUDE.md` holds personal Claude Code preferences that apply in every project, such as how replies are formatted. Claude Code reads it from `%USERPROFILE%\.claude\CLAUDE.md`. Run this once per host from an elevated PowerShell (or turn on Windows Developer Mode first), because Windows needs one of those to create a file symbolic link:

```powershell
.\Install-UserClaudeMd.ps1 -WhatIf   # preview
.\Install-UserClaudeMd.ps1
```

This makes `%USERPROFILE%\.claude\CLAUDE.md` a symbolic link to the repo file, so a `git pull` updates every host. An existing real file is moved to `%USERPROFILE%\.claude\claude-md-backups\` first. Use `-Force` to repoint a link that goes to another clone. Edit the repo copy, then start a new Claude Code session.

## Why a script and a skill

The script does everything that's the same every time (copying, merging, `git init`) and uses no tokens. The skill does only what needs judgment, which is reading the code to fill in `CLAUDE.md`. See `Token-Usage-Recommendations.md` in aPePAS (R4) for the reasoning behind the CLAUDE.md layout.

## Editing the templates

- The placeholders are `{{ProjectName}}`, `{{Description}}` and `{{Date}}`.
- `New-ApeProject.ps1` must stay PS 5.1-compatible, ASCII-only, and saved as UTF-8 with BOM.
