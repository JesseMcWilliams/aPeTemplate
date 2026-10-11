#Requires -Version 5.1
<#
.SYNOPSIS
    Finds the Claude Code plugins and claude.ai connectors a project's sessions never used, and
    writes a settings proposal that turns them off for that project (local settings only).

.DESCRIPTION
    Reads the project's session transcripts under <ClaudeHome>\projects\<encoded path>\ and
    counts what the sessions used:
      - plugins: Skill calls and /commands named "<plugin>:<skill>", Agent calls with a
        "<plugin>:<agent>" subagent type, and mcp__plugin_<plugin>_* tool calls
      - claude.ai connectors: mcp__claude_ai_<Name>__* tool calls
    The plugin inventory comes from the claude.ai synced plugins (plugins\synced\*\manifest.json)
    and, when present, installed_plugins.json. The connector inventory comes from the
    transcripts' deferred-tool records (offered tools and connectors that need sign-in).

    Writes <ProjectPath>\.claude\settings.token-proposal.json with:
      - enabledPlugins: "<name>@synced": false (or "<name>@<marketplace>": false) per unused plugin
      - disableClaudeAiConnectors: true when no connector was used, otherwise
        deniedMcpServers: { "serverName": "claude.ai <Name>" } per unused connector
    With -Apply, merges the proposal into <ProjectPath>\.claude\settings.local.json after
    saving a timestamped backup. Existing entries in that file are kept: a plugin you already
    set there, true or false, is left alone.

    Changes take effect in the next Claude Code session (or after /reload-plugins).

    Caveats:
      - Claude Code documents the transcript format as internal and subject to change, and the
        synced-plugin manifest is undocumented. Anything this script can't parse is reported and
        skipped, never guessed.
      - It only sees past use. Pass -Keep for anything you want even though it was unused.
      - Connector names for signed-in connectors are inferred from tool names (underscores
        become spaces) and flagged in the report; check them before applying.
      - A plugin your organization requires can't be disabled; only plugins whose synced
        installation preference is "available" are proposed.

.PARAMETER ProjectPath
    The project folder. Defaults to the current folder.

.PARAMETER Days
    Only count sessions active in the last N days. 0 (the default) counts every session.

.PARAMETER Keep
    Plugin names (e.g. pdf-viewer) or connector names (e.g. "claude.ai Notion") never to propose.

.PARAMETER Apply
    Merge the proposal into the project's .claude\settings.local.json.

.PARAMETER ClaudeHome
    The Claude Code user folder. Defaults to %USERPROFILE%\.claude.

.EXAMPLE
    .\New-ClaudeTokenSettings.ps1 -ProjectPath C:\Code\aPePAS

.EXAMPLE
    .\New-ClaudeTokenSettings.ps1 -ProjectPath C:\Code\aPePAS -Keep pdf-viewer -Apply -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$ProjectPath = (Get-Location).Path,

    [ValidateRange(0, 3650)]
    [int]$Days = 0,

    [string[]]$Keep = @(),

    [switch]$Apply,

    [string]$ClaudeHome = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $ClaudeHome) { $ClaudeHome = Join-Path $env:USERPROFILE '.claude' }
$ProjectPath = (Resolve-Path -LiteralPath $ProjectPath).Path.TrimEnd('\', '/')
$utf8NoBom   = New-Object System.Text.UTF8Encoding($false)

function Test-HasProperty {
    param($Object, [string]$Name)
    return ($null -ne $Object) -and ($Object -is [System.Management.Automation.PSCustomObject]) -and
        ($null -ne $Object.PSObject.Properties[$Name])
}

function Add-Count {
    param([hashtable]$Table, [string]$Key)
    if (-not $Key) { return }
    if ($Table.ContainsKey($Key)) { $Table[$Key]++ } else { $Table[$Key] = 1 }
}

#region --- Transcripts ---

# Claude Code names the folder after the project path with non-alphanumeric characters
# replaced by '-'. The drive letter's case varies by client, and Windows paths are
# case-insensitive, so match the name without regard to case.
$encoded     = [regex]::Replace($ProjectPath, '[^A-Za-z0-9]', '-')
$projectsDir = Join-Path $ClaudeHome 'projects'
$transcriptDir = $null
if (Test-Path -LiteralPath $projectsDir) {
    $transcriptDir = Get-ChildItem -LiteralPath $projectsDir -Directory |
        Where-Object { $_.Name -ieq $encoded } | Select-Object -First 1
}
if (-not $transcriptDir) {
    throw "No session transcripts found for $ProjectPath (looked for $projectsDir\$encoded). Nothing to measure."
}

$cutoff = if ($Days -gt 0) { (Get-Date).AddDays(-$Days) } else { [datetime]::MinValue }
$files  = @(Get-ChildItem -LiteralPath $transcriptDir.FullName -Filter '*.jsonl' -File -Recurse |
    Where-Object { $_.LastWriteTime -ge $cutoff })
if ($files.Count -eq 0) {
    throw "No session transcripts in $($transcriptDir.FullName) for the last $Days day(s). Nothing to measure."
}

$pluginUse        = @{}   # plugin name -> count
$connectorUse     = @{}   # tool-name token (e.g. Claude_Docs) -> count
$connectorOffered = @{}   # display name -> $true (exact) or 'inferred'
$badLines = 0

foreach ($file in $files) {
    foreach ($line in [System.IO.File]::ReadLines($file.FullName)) {
        # Cheap pre-filter: only parse lines that can hold what we count.
        if ($line -notmatch '"tool_use"|deferred_tools_delta|<command-name>') { continue }
        try { $entry = $line | ConvertFrom-Json } catch { $badLines++; continue }

        if ((Test-HasProperty $entry 'attachment') -and (Test-HasProperty $entry.attachment 'type') -and
            $entry.attachment.type -eq 'deferred_tools_delta') {
            if (Test-HasProperty $entry.attachment 'needsAuthMcpServers') {
                foreach ($name in @($entry.attachment.needsAuthMcpServers)) {
                    if ([string]$name -like 'claude.ai *') { $connectorOffered[[string]$name] = $true }
                }
            }
            if (Test-HasProperty $entry.attachment 'addedNames') {
                foreach ($tool in @($entry.attachment.addedNames)) {
                    if ([string]$tool -match '^mcp__claude_ai_(.+?)__') {
                        $display = 'claude.ai ' + ($Matches[1] -replace '_', ' ')
                        if (-not $connectorOffered.ContainsKey($display)) { $connectorOffered[$display] = 'inferred' }
                    }
                }
            }
            continue
        }

        if (-not (Test-HasProperty $entry 'message') -or -not (Test-HasProperty $entry.message 'content')) { continue }
        $content = $entry.message.content
        $isUser  = (Test-HasProperty $entry 'type') -and $entry.type -eq 'user'

        # A /plugin:skill command typed by the user.
        if ($content -is [string]) {
            if (-not $isUser) { continue }
            foreach ($m in [regex]::Matches($content, '<command-name>/?([A-Za-z0-9_-]+):')) {
                Add-Count $pluginUse $m.Groups[1].Value
            }
            continue
        }

        foreach ($block in @($content)) {
            if (-not (Test-HasProperty $block 'type')) { continue }
            if ($block.type -eq 'text' -and $isUser -and (Test-HasProperty $block 'text')) {
                foreach ($m in [regex]::Matches([string]$block.text, '<command-name>/?([A-Za-z0-9_-]+):')) {
                    Add-Count $pluginUse $m.Groups[1].Value
                }
                continue
            }
            if ($block.type -ne 'tool_use' -or -not (Test-HasProperty $block 'name')) { continue }
            $name  = [string]$block.name
            $toolInput = if (Test-HasProperty $block 'input') { $block.input } else { $null }

            if ($name -match '^mcp__claude_ai_(.+?)__') {
                Add-Count $connectorUse $Matches[1]
            }
            elseif ($name -match '^mcp__plugin_(.+?)_[^_]+__') {
                Add-Count $pluginUse $Matches[1]
            }
            elseif ($name -eq 'Skill' -and (Test-HasProperty $toolInput 'skill') -and [string]$toolInput.skill -match '^([^:]+):') {
                Add-Count $pluginUse $Matches[1]
            }
            elseif ($name -eq 'Agent' -and (Test-HasProperty $toolInput 'subagent_type') -and [string]$toolInput.subagent_type -match '^([^:]+):') {
                Add-Count $pluginUse $Matches[1]
            }
        }
    }
}

#endregion

#region --- Plugin inventory ---

$plugins = New-Object System.Collections.Generic.List[object]   # Name, Key, Preference
$notes   = New-Object System.Collections.Generic.List[string]

$syncedRoot = Join-Path $ClaudeHome 'plugins\synced'
if (Test-Path -LiteralPath $syncedRoot) {
    foreach ($manifestFile in Get-ChildItem -LiteralPath $syncedRoot -Filter 'manifest.json' -File -Recurse -Depth 1) {
        try { $manifest = Get-Content -LiteralPath $manifestFile.FullName -Raw -Encoding UTF8 | ConvertFrom-Json }
        catch { $notes.Add("Skipped $($manifestFile.FullName): not readable JSON."); continue }
        if (-not (Test-HasProperty $manifest 'plugins')) { $notes.Add("Skipped $($manifestFile.FullName): no 'plugins' list."); continue }
        foreach ($p in @($manifest.plugins)) {
            if (-not (Test-HasProperty $p 'name')) { continue }
            $pref = if (Test-HasProperty $p 'installationPreference') { [string]$p.installationPreference } else { '' }
            $plugins.Add([pscustomobject]@{ Name = [string]$p.name; Key = "$($p.name)@synced"; Preference = $pref })
        }
    }
}

$installedFile = Join-Path $ClaudeHome 'plugins\installed_plugins.json'
if (Test-Path -LiteralPath $installedFile) {
    try {
        $installed = Get-Content -LiteralPath $installedFile -Raw -Encoding UTF8 | ConvertFrom-Json
        if (Test-HasProperty $installed 'plugins') {
            foreach ($prop in $installed.plugins.PSObject.Properties) {
                if ($prop.Name -match '^([^@]+)@(.+)$') {
                    $plugins.Add([pscustomobject]@{ Name = $Matches[1]; Key = $prop.Name; Preference = 'installed' })
                }
            }
        }
        else { $notes.Add("installed_plugins.json has no 'plugins' object; marketplace plugins were not checked.") }
    }
    catch { $notes.Add('installed_plugins.json is not readable JSON; marketplace plugins were not checked.') }
}

#endregion

#region --- Proposal ---

$keepSet = @{}
foreach ($k in $Keep) { if ($k) { $keepSet[$k.ToLowerInvariant()] = $true } }

$report         = New-Object System.Collections.Generic.List[object]
$pluginsOff     = [ordered]@{}
foreach ($p in ($plugins | Sort-Object Key -Unique)) {
    $uses = if ($pluginUse.ContainsKey($p.Name)) { $pluginUse[$p.Name] } else { 0 }
    $action =
        if ($uses -gt 0) { 'keep (used)' }
        elseif ($keepSet.ContainsKey($p.Name.ToLowerInvariant())) { 'keep (-Keep)' }
        elseif ($p.Preference -notin @('available', 'installed')) { "keep (sync preference '$($p.Preference)')" }
        else { $pluginsOff[$p.Key] = $false; 'disable' }
    $report.Add([pscustomobject]@{ Kind = 'plugin'; Name = $p.Key; Uses = $uses; Action = $action })
}

$connectorsUsed = New-Object System.Collections.Generic.List[string]
$connectorsOff  = New-Object System.Collections.Generic.List[string]
$allConnectors  = @{}
foreach ($name in $connectorOffered.Keys) { $allConnectors[$name] = $connectorOffered[$name] }
foreach ($token in $connectorUse.Keys) {
    $display = 'claude.ai ' + ($token -replace '_', ' ')
    if (-not $allConnectors.ContainsKey($display)) { $allConnectors[$display] = 'inferred' }
}
foreach ($name in ($allConnectors.Keys | Sort-Object)) {
    $token = ($name.Substring('claude.ai '.Length)) -replace '[^A-Za-z0-9]', '_'
    $uses  = 0
    foreach ($t in $connectorUse.Keys) { if ($t -ieq $token) { $uses += $connectorUse[$t] } }
    $suffix = if ($allConnectors[$name] -is [string]) { ' (name inferred)' } else { '' }
    $action =
        if ($uses -gt 0) { $connectorsUsed.Add($name); 'keep (used)' }
        elseif ($keepSet.ContainsKey($name.ToLowerInvariant())) { $connectorsUsed.Add($name); 'keep (-Keep)' }
        else { $connectorsOff.Add($name); 'disable' }
    $report.Add([pscustomobject]@{ Kind = 'connector'; Name = $name + $suffix; Uses = $uses; Action = $action })
}

$proposal = [ordered]@{}
if ($pluginsOff.Count -gt 0) { $proposal['enabledPlugins'] = $pluginsOff }
if ($allConnectors.Count -gt 0 -and $connectorsUsed.Count -eq 0) {
    $proposal['disableClaudeAiConnectors'] = $true
}
elseif ($connectorsOff.Count -gt 0) {
    $proposal['deniedMcpServers'] = @($connectorsOff | ForEach-Object { [ordered]@{ serverName = $_ } })
}

#endregion

#region --- Output ---

"Project:     $ProjectPath"
"Transcripts: $($files.Count) file(s) in $($transcriptDir.FullName)" + $(if ($Days -gt 0) { " (last $Days days)" } else { '' })
if ($badLines -gt 0) { "Skipped $badLines unreadable transcript line(s)." }
foreach ($n in $notes) { $n }
$report | Format-Table -AutoSize | Out-String -Width 200 | Write-Output

if ($proposal.Count -eq 0) {
    'Nothing to turn off.'
    return
}

$claudeDir    = Join-Path $ProjectPath '.claude'
$proposalPath = Join-Path $claudeDir 'settings.token-proposal.json'
if ($PSCmdlet.ShouldProcess($proposalPath, 'Write settings proposal')) {
    if (-not (Test-Path -LiteralPath $claudeDir)) { New-Item -ItemType Directory -Path $claudeDir | Out-Null }
    [System.IO.File]::WriteAllText($proposalPath, ($proposal | ConvertTo-Json -Depth 6), $utf8NoBom)
    "Proposal written: $proposalPath"
}

if (-not $Apply) {
    'Review it, then rerun with -Apply to merge it into .claude\settings.local.json.'
    return
}

$localPath = Join-Path $claudeDir 'settings.local.json'
$local = [pscustomobject]@{}
if (Test-Path -LiteralPath $localPath) {
    $raw = Get-Content -LiteralPath $localPath -Raw -Encoding UTF8
    if ($raw -and $raw.Trim()) {
        try { $local = $raw | ConvertFrom-Json }
        catch { throw "$localPath is not valid JSON. Fix it first; nothing was changed." }
    }
}

$changes = New-Object System.Collections.Generic.List[string]
if ($proposal.Contains('enabledPlugins')) {
    if (-not (Test-HasProperty $local 'enabledPlugins')) {
        $local | Add-Member -NotePropertyName enabledPlugins -NotePropertyValue ([pscustomobject]@{})
    }
    foreach ($key in $proposal['enabledPlugins'].Keys) {
        if (Test-HasProperty $local.enabledPlugins $key) { $changes.Add("kept your existing $key = $($local.enabledPlugins.$key)"); continue }
        $local.enabledPlugins | Add-Member -NotePropertyName $key -NotePropertyValue $false
        $changes.Add("$key = false")
    }
}
if ($proposal.Contains('disableClaudeAiConnectors')) {
    if (Test-HasProperty $local 'disableClaudeAiConnectors') { $local.disableClaudeAiConnectors = $true }
    else { $local | Add-Member -NotePropertyName disableClaudeAiConnectors -NotePropertyValue $true }
    $changes.Add('disableClaudeAiConnectors = true')
}
if ($proposal.Contains('deniedMcpServers')) {
    $existing = @()
    if (Test-HasProperty $local 'deniedMcpServers') { $existing = @($local.deniedMcpServers) }
    $names = @($existing | Where-Object { Test-HasProperty $_ 'serverName' } | ForEach-Object { [string]$_.serverName })
    $merged = New-Object System.Collections.Generic.List[object]
    foreach ($e in $existing) { $merged.Add($e) }
    foreach ($e in $proposal['deniedMcpServers']) {
        if ($names -contains $e.serverName) { continue }
        $merged.Add([pscustomobject]@{ serverName = $e.serverName }); $changes.Add("deniedMcpServers += $($e.serverName)")
    }
    if (Test-HasProperty $local 'deniedMcpServers') { $local.deniedMcpServers = $merged.ToArray() }
    else { $local | Add-Member -NotePropertyName deniedMcpServers -NotePropertyValue $merged.ToArray() }
}

if ($PSCmdlet.ShouldProcess($localPath, "Merge $($changes.Count) setting(s)")) {
    if (Test-Path -LiteralPath $localPath) {
        $backup = "$localPath.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item -LiteralPath $localPath -Destination $backup
        "Backup: $backup"
    }
    [System.IO.File]::WriteAllText($localPath, ($local | ConvertTo-Json -Depth 10), $utf8NoBom)
    "Applied to $localPath"
}
foreach ($c in $changes) { "  $c" }
'Start a new Claude Code session (or run /reload-plugins) for the change to take effect.'

#endregion
