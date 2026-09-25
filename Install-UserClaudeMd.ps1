#Requires -Version 5.1
<#
.SYNOPSIS
    Links %USERPROFILE%\.claude\CLAUDE.md (the user-level Claude Code instructions) to
    this repo's user-claude\CLAUDE.md, so every host shares one copy and a git pull
    updates it.

.DESCRIPTION
    Creates %USERPROFILE%\.claude\CLAUDE.md as a file symbolic link to
    <this repo>\user-claude\CLAUDE.md. Run it once per host, from wherever the repo
    is cloned.

    A file symbolic link needs an elevated PowerShell, or Windows Developer Mode turned
    on. (A junction only works for folders, and a hard link would be broken by git
    replacing the file on pull, so neither is used here.)

    If CLAUDE.md already exists as a real file, it is moved to
    %USERPROFILE%\.claude\claude-md-backups\CLAUDE.md.bak-<timestamp> first, not deleted.
    If it is already a link to this repo's file, nothing changes.

.PARAMETER Force
    Replace an existing link that points somewhere else (e.g. an old clone).

.EXAMPLE
    .\Install-UserClaudeMd.ps1 -WhatIf

.EXAMPLE
    .\Install-UserClaudeMd.ps1
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$target = Join-Path $PSScriptRoot 'user-claude\CLAUDE.md'
$claudeDir = Join-Path $env:USERPROFILE '.claude'
$link = Join-Path $claudeDir 'CLAUDE.md'

if (-not (Test-Path -LiteralPath $target)) {
    throw "CLAUDE.md not found at '$target'."
}

if (-not (Test-Path -LiteralPath $claudeDir)) {
    if ($PSCmdlet.ShouldProcess($claudeDir, 'Create .claude folder')) {
        New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
    }
}

# Get-Item rather than Test-Path: Test-Path is false for a dangling link (e.g. the clone moved).
$item = Get-Item -LiteralPath $link -Force -ErrorAction SilentlyContinue
if ($item) {
    $isReparse = ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0

    if ($isReparse) {
        $current = @($item.Target) | Select-Object -First 1
        if ($current -and ([IO.Path]::GetFullPath($current) -ieq [IO.Path]::GetFullPath($target))) {
            Write-Host "Already installed: $link -> $target" -ForegroundColor Green
            return
        }
        if (-not $Force) {
            throw "'$link' is already a link to '$current'. Re-run with -Force to point it at '$target'."
        }
        if ($PSCmdlet.ShouldProcess($link, "Remove link to '$current'")) {
            # Removes only the link itself; the file it points to is untouched.
            [IO.File]::Delete($link)
        }
    }
    else {
        $backupDir = Join-Path $claudeDir 'claude-md-backups'
        $backup = Join-Path $backupDir "CLAUDE.md.bak-$(Get-Date -Format 'yyyyMMddHHmmss')"
        if ($PSCmdlet.ShouldProcess($link, "Move existing file to '$backup'")) {
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
            Move-Item -LiteralPath $link -Destination $backup
            Write-Host "Existing file moved to $backup. Merge anything you still want into '$target'." -ForegroundColor Yellow
        }
    }
}

if ($PSCmdlet.ShouldProcess($link, "Create symbolic link to '$target'")) {
    try {
        New-Item -ItemType SymbolicLink -Path $link -Target $target | Out-Null
    }
    catch {
        throw "Could not create the symbolic link: $($_.Exception.Message) Run this from an elevated PowerShell, or turn on Windows Developer Mode, and try again."
    }
    Write-Host "Installed: $link -> $target" -ForegroundColor Green
    Write-Host 'Start a new Claude Code session to pick up the change.' -ForegroundColor DarkGray
}
