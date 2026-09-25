#Requires -Version 5.1
<#
.SYNOPSIS
    Scaffolds a new aPe* project, or retrofits an existing one, with the standard
    Claude Code setup: CLAUDE.md, Live-Testing.local.md, .gitignore entries and
    (optionally) skeleton docs.

.DESCRIPTION
    Never overwrites an existing file. Existing .gitignore files are merged: only
    missing entries are appended. CLAUDE.md is written from the template with
    <!-- FILL: ... --> markers; the ape-project-setup Claude Code skill (or you)
    fills those in from the real code.

.PARAMETER Name
    Project folder name, e.g. aPeFoo.

.PARAMETER Path
    Parent folder. Defaults to the folder that contains aPeTemplate (C:\Code).

.PARAMETER Existing
    Retrofit an existing project folder instead of creating a new one.
    Skeleton docs are skipped unless -IncludeDocs is also given.

.PARAMETER Description
    One-line project description placed in CLAUDE.md.

.PARAMETER IncludeDocs
    Copy the skeleton Docs\ files (the default for new projects). Existing
    docs are never overwritten.

.EXAMPLE
    .\New-ApeProject.ps1 -Name aPeFoo -Description 'Exports foo from CyberArk.'

.EXAMPLE
    .\New-ApeProject.ps1 -Name aPeSecrets -Existing -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9._-]+$')]
    [string]$Name,

    [string]$Path = '',

    [switch]$Existing,

    [string]$Description = '',

    [switch]$IncludeDocs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# PS 5.1 leaves $PSScriptRoot empty inside param() defaults, so resolve it here.
if (-not $Path) { $Path = Split-Path -Parent $PSScriptRoot }

$templateRoot = Join-Path $PSScriptRoot 'templates'
$target       = Join-Path $Path $Name
$utf8NoBom    = New-Object System.Text.UTF8Encoding($false)
$results      = New-Object System.Collections.Generic.List[object]

function Add-Result {
    param([string]$Item, [string]$Action)
    $results.Add([pscustomobject]@{ Item = $Item; Action = $Action })
}

function Expand-Template {
    param([string]$TemplatePath)
    $text = [System.IO.File]::ReadAllText($TemplatePath, [System.Text.Encoding]::UTF8)
    $text = $text.Replace('{{ProjectName}}', $Name)
    $text = $text.Replace('{{Description}}', $Description)
    $text = $text.Replace('{{Date}}', (Get-Date -Format 'yyyy-MM-dd'))
    return $text
}

function Copy-TemplateFile {
    param([string]$TemplatePath, [string]$Destination)
    $relative = $Destination.Substring($target.Length).TrimStart('\', '/')
    if (Test-Path -LiteralPath $Destination) {
        Add-Result $relative 'skipped (already exists)'
        return
    }
    if ($PSCmdlet.ShouldProcess($Destination, 'Create from template')) {
        $dir = Split-Path -Parent $Destination
        if (-not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        [System.IO.File]::WriteAllText($Destination, (Expand-Template $TemplatePath), $utf8NoBom)
    }
    Add-Result $relative 'created'
}

#region --- Validate target ---

if (-not (Test-Path -LiteralPath $templateRoot)) {
    throw "Template folder not found: $templateRoot"
}

$targetExists = Test-Path -LiteralPath $target
if ($Existing -and -not $targetExists) {
    throw "-Existing was given but $target does not exist."
}
if (-not $Existing -and $targetExists -and @(Get-ChildItem -LiteralPath $target -Force).Count -gt 0) {
    throw "$target already exists and is not empty. Use -Existing to retrofit it."
}

$copyDocs = $IncludeDocs -or -not $Existing

#endregion

#region --- Folders ---

if (-not $targetExists) {
    if ($PSCmdlet.ShouldProcess($target, 'Create project folder')) {
        New-Item -ItemType Directory -Path $target | Out-Null
    }
    Add-Result '.' 'created'
}
if (-not $Existing) {
    foreach ($sub in @('Docs', 'Modules', 'Tests\Unit')) {
        $subPath = Join-Path $target $sub
        if (-not (Test-Path -LiteralPath $subPath)) {
            if ($PSCmdlet.ShouldProcess($subPath, 'Create folder')) {
                New-Item -ItemType Directory -Path $subPath -Force | Out-Null
            }
            Add-Result $sub 'created'
        }
    }
}

#endregion

#region --- Template files ---

Copy-TemplateFile (Join-Path $templateRoot 'CLAUDE.template.md')             (Join-Path $target 'CLAUDE.md')
Copy-TemplateFile (Join-Path $templateRoot 'Live-Testing.local.template.md') (Join-Path $target 'Live-Testing.local.md')

if ($copyDocs) {
    foreach ($doc in Get-ChildItem -LiteralPath (Join-Path $templateRoot 'Docs') -File) {
        Copy-TemplateFile $doc.FullName (Join-Path (Join-Path $target 'Docs') $doc.Name)
    }
}

#endregion

#region --- .gitignore merge ---

$gitignorePath = Join-Path $target '.gitignore'
$baseLines     = [System.IO.File]::ReadAllLines((Join-Path $templateRoot 'gitignore.base'), [System.Text.Encoding]::UTF8)

if (-not (Test-Path -LiteralPath $gitignorePath)) {
    if ($PSCmdlet.ShouldProcess($gitignorePath, 'Create .gitignore')) {
        [System.IO.File]::WriteAllLines($gitignorePath, $baseLines, $utf8NoBom)
    }
    Add-Result '.gitignore' 'created'
}
else {
    $existingEntries = @{}
    foreach ($line in [System.IO.File]::ReadAllLines($gitignorePath, [System.Text.Encoding]::UTF8)) {
        $trimmed = $line.Trim()
        if ($trimmed) { $existingEntries[$trimmed] = $true }
    }
    $missing = @($baseLines | Where-Object {
        $t = $_.Trim()
        $t -and -not $t.StartsWith('#') -and -not $existingEntries.ContainsKey($t)
    })
    if ($missing.Count -eq 0) {
        Add-Result '.gitignore' 'skipped (all entries present)'
    }
    else {
        if ($PSCmdlet.ShouldProcess($gitignorePath, "Append $($missing.Count) entries")) {
            $block = @('', '# Added by aPeTemplate\New-ApeProject.ps1') + $missing
            [System.IO.File]::AppendAllText($gitignorePath, (($block -join "`r`n") + "`r`n"), $utf8NoBom)
        }
        Add-Result '.gitignore' ("appended: " + ($missing -join ', '))
    }
}

#endregion

#region --- git init ---

if (-not (Test-Path -LiteralPath (Join-Path $target '.git'))) {
    if (Get-Command git -ErrorAction SilentlyContinue) {
        if ($PSCmdlet.ShouldProcess($target, 'git init -b main')) {
            & git -C $target init -q -b main
            if ($LASTEXITCODE -ne 0) { throw "git init failed in $target" }
        }
        Add-Result '.git' 'initialized (branch main, nothing committed)'
    }
    else {
        Add-Result '.git' 'skipped (git not on PATH)'
    }
}

#endregion

$results | Format-Table -AutoSize | Out-String | Write-Host

if (Test-Path -LiteralPath (Join-Path $target 'CLAUDE.md')) {
    $fillCount = @(Select-String -LiteralPath (Join-Path $target 'CLAUDE.md') -Pattern '<!-- FILL:' -SimpleMatch).Count
    if ($fillCount -gt 0) {
        Write-Host "CLAUDE.md has $fillCount FILL marker(s). Run the ape-project-setup skill in Claude Code from $target to fill them."
    }
}
