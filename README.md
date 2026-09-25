# aPeTemplate

This repo scaffolds new aPe* projects, and retrofits existing ones, with a standard Claude Code setup that keeps token use low.

## What it sets up

| File | Purpose |
|---|---|
| `CLAUDE.md` | A lean project guide that Claude Code loads every session. It's created with `<!-- FILL: -->` markers for the project-specific parts. |
| `Live-Testing.local.md` | Lab details (URLs, tenants, App IDs, test fixtures). Gitignored, and read only when a task involves live testing. Never put secrets in it. |
| `.gitignore` | The base entries (`*.local.md`, logs, CSVs, credential files). An existing `.gitignore` is merged: missing entries are appended. |
| `Docs/` (new projects) | Skeleton Architecture, Testing-Plan and Lessons-Learned docs, set up so they don't grow revision logs. |

The script never overwrites an existing file, so it's safe to run again.

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

Then open the project folder in VS Code, start Claude Code, and ask it to *"run the ape-project-setup skill"* (or say "set up CLAUDE.md for this project"). The skill fills the FILL markers from the real code and shows you the draft before writing it.

## The skill

The skill lives outside this repo, at `%USERPROFILE%\.claude\skills\ape-project-setup\SKILL.md`, because it's a personal Claude Code skill that's available in every project. It's copied here as `skill/SKILL.md` so it's version-controlled. After editing either copy, update the other:

```powershell
Copy-Item .\skill\SKILL.md "$env:USERPROFILE\.claude\skills\ape-project-setup\SKILL.md"
```

## Why a script and a skill

The script does everything that's the same every time (copying, merging, `git init`) and uses no tokens. The skill does only what needs judgment, which is reading the code to fill in `CLAUDE.md`. See `Token-Usage-Recommendations.md` in aPePAS (R4) for the reasoning behind the CLAUDE.md layout.

## Editing the templates

- The placeholders are `{{ProjectName}}`, `{{Description}}` and `{{Date}}`.
- `New-ApeProject.ps1` must stay PS 5.1-compatible, ASCII-only, and saved as UTF-8 with BOM.
