#Requires -Version 5.1
<#
.SYNOPSIS
    Installs the ape-project-setup Claude Code skill as a directory junction that
    points at this repo's skill\ folder, so the installed skill always matches the
    template (a git pull updates both).

.DESCRIPTION
    Creates %USERPROFILE%\.claude\skills\ape-project-setup as a junction to
    <this repo>\skill. Run it once per host, from wherever the repo is cloned.
    A junction needs no admin rights, but both paths must be on local NTFS volumes.

    If the skill folder already exists as a real folder (an older copied install),
    it is moved to %USERPROFILE%\.claude\skill-backups\ape-project-setup.bak-<timestamp>
    first, not deleted. If it is
    already a junction to this repo's skill\ folder, nothing changes.

.PARAMETER Force
    Replace an existing junction that points somewhere else (e.g. an old clone).

.EXAMPLE
    .\Install-Skill.ps1 -WhatIf

.EXAMPLE
    .\Install-Skill.ps1
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$target = Join-Path $PSScriptRoot 'skill'
$skillsDir = Join-Path $env:USERPROFILE '.claude\skills'
$link = Join-Path $skillsDir 'ape-project-setup'

if (-not (Test-Path -LiteralPath (Join-Path $target 'SKILL.md'))) {
    throw "SKILL.md not found under '$target'."
}

if (-not (Test-Path -LiteralPath $skillsDir)) {
    if ($PSCmdlet.ShouldProcess($skillsDir, 'Create skills folder')) {
        New-Item -ItemType Directory -Path $skillsDir -Force | Out-Null
    }
}

if (Test-Path -LiteralPath $link) {
    $item = Get-Item -LiteralPath $link -Force
    $isReparse = ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0

    if ($isReparse) {
        $current = @($item.Target) | Select-Object -First 1
        if ($current -and ([IO.Path]::GetFullPath($current).TrimEnd('\') -ieq [IO.Path]::GetFullPath($target).TrimEnd('\'))) {
            Write-Host "Already installed: $link -> $target" -ForegroundColor Green
            return
        }
        if (-not $Force) {
            throw "'$link' is already a link to '$current'. Re-run with -Force to point it at '$target'."
        }
        if ($PSCmdlet.ShouldProcess($link, "Remove junction to '$current'")) {
            # Removes only the junction itself; the folder it points to is untouched.
            [IO.Directory]::Delete($link)
        }
    }
    else {
        # Back up outside skills\ so Claude Code doesn't load the old copy as a second skill.
        $backupDir = Join-Path $env:USERPROFILE '.claude\skill-backups'
        $backup = Join-Path $backupDir "ape-project-setup.bak-$(Get-Date -Format 'yyyyMMddHHmmss')"
        if ($PSCmdlet.ShouldProcess($link, "Move existing folder to '$backup'")) {
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
            Move-Item -LiteralPath $link -Destination $backup
            Write-Host "Existing copy moved to $backup" -ForegroundColor Yellow
        }
    }
}

if ($PSCmdlet.ShouldProcess($link, "Create junction to '$target'")) {
    New-Item -ItemType Junction -Path $link -Target $target | Out-Null
    Write-Host "Installed: $link -> $target" -ForegroundColor Green
    Write-Host 'Start a new Claude Code session to pick up the skill.' -ForegroundColor DarkGray
}
