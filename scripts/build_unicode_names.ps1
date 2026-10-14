<#
.SYNOPSIS
    Builds a curated Unicode name table for every code point that appears in the
    decoded NiDA / legacy Khmer layouts, using the official UCD.

.DESCRIPTION
    Downloads (or reads from a local copy of) UnicodeData.txt and extracts the
    official character name for each code point actually used by the layouts, so
    the generated spec never carries hand-typed (possibly wrong) names.

    The generated file scripts/data/unicode_names.json is committed; this script
    only needs re-running when new characters enter a layout.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)] [string[]]$TableCsv = @(
        'tables_kbdkni.csv', 'tables_kbdkhmr.csv'),
    [Parameter(Mandatory = $false)] [string]$UcdFile = "$env:TEMP\opencode\UnicodeData.txt",
    [Parameter(Mandatory = $false)] [string]$UcdUrl = 'https://www.unicode.org/Public/UCD/latest/ucd/UnicodeData.txt',
    [Parameter(Mandatory = $false)] [string]$OutFile = $null
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not $OutFile) { $OutFile = Join-Path $PSScriptRoot 'data\unicode_names.json' }

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$csvs = $TableCsv | ForEach-Object {
    $p = if ([System.IO.Path]::IsPathRooted($_)) { $_ } else { Join-Path $root $_ }
    if (Test-Path $p) { $p } else { Write-Warning "skipping missing $_"; $null }
} | Where-Object { $_ }

$used = New-Object 'System.Collections.Generic.HashSet[int]'
foreach ($csv in $csvs) {
    foreach ($row in (Import-Csv -Encoding UTF8 $csv)) {
        # Unicode column holds either "U+XXXX" or the sentinel 0xF000 / 0xF002
        if ($row.Unicode -match '^U\+([0-9A-Fa-f]{4,6})$') {
            [void]$used.Add([Convert]::ToInt32($Matches[1], 16))
        }
        # multi-codepoint ligature text is already expanded per code point
        foreach ($ch in $row.Value.ToCharArray()) { [void]$used.Add([int]$ch) }
    }
}

if (-not (Test-Path $UcdFile)) {
    Write-Host "fetching $UcdUrl"
    Invoke-WebRequest -Uri $UcdUrl -OutFile $UcdFile -UseBasicParsing -TimeoutSec 120
}

# UnicodeData.txt lists control characters with the alias <control>; give the
# ones a layout actually emits their conventional names.
$controlNames = @{
    'U+0003' = 'END OF TEXT (ETX)'
    'U+0008' = 'BACKSPACE (BS)'
    'U+0009' = 'CHARACTER TABULATION (TAB)'
    'U+000A' = 'LINE FEED (LF)'
    'U+000D' = 'CARRIAGE RETURN (CR)'
    'U+001B' = 'ESCAPE (ESC)'
    'U+007F' = 'DELETE (DEL)'
}

$names = @{}
foreach ($k in $controlNames.Keys) { if ($used.Contains([Convert]::ToInt32($k.Substring(2), 16))) { $names[$k] = $controlNames[$k] } }
$found = $names.Count
foreach ($line in [System.IO.File]::ReadLines($UcdFile)) {
    $f = $line.Split(';')
    if ($f.Length -lt 2) { continue }
    $cp = [Convert]::ToInt32($f[0], 16)
    if (-not $used.Contains($cp)) { continue }
    $name = $f[1]
    if ($name.StartsWith('<') -and $name.EndsWith('>')) { continue }   # range alias, not a real name
    $names[('U+{0:X4}' -f $cp)] = $name
    $found++
}

$missing = ($used | Where-Object { -not $names.ContainsKey(('U+{0:X4}' -f $_)) })

$obj = [ordered]@{
    generatedFrom = $UcdUrl.Split('/')[-1]
    usage         = 'Official Unicode character names for every code point used by the NiDA and legacy Khmer layouts.'
    count         = $names.Count
    names         = $names
}
$dir = Split-Path -Parent $OutFile
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
[System.IO.File]::WriteAllText($OutFile, ($obj | ConvertTo-Json -Depth 5), (New-Object System.Text.UTF8Encoding $false))

Write-Host ("code points used : {0}" -f $used.Count)
Write-Host ("names resolved   : {0}" -f $found)
if ($missing) { Write-Host ("unresolved       : {0}" -f (($missing | ForEach-Object { 'U+{0:X4}' -f $_ }) -join ', ')) }
Write-Host "-> $OutFile"
