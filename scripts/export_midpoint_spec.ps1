<#
.SYNOPSIS
    Builds midpoint_layout.json - the machine-readable Khmer Better-NiDA
    (Midpoint) specification - from nida_layout.json and midpoint_engine.ps1.

.DESCRIPTION
    Applies Midpoint's static layer overrides (Rules 2, 4, 5) to the 49 keys of
    nida_layout.json and embeds the prefix-buffered sequence rules (Rules 1, 2,
    3) from scripts/midpoint_engine.ps1. Character names are resolved from
    scripts/data/unicode_names.json.

    Never modifies nida_layout.json.

.EXAMPLE
    .\scripts\export_midpoint_spec.ps1
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)] [string]$StockSpec = 'nida_layout.json',
    [Parameter(Mandatory = $false)] [string]$NamesJson = $null,
    [Parameter(Mandatory = $false)] [string]$OutFile   = 'midpoint_layout.json'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not $NamesJson) { $NamesJson = Join-Path $PSScriptRoot 'data\unicode_names.json' }
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

function Resolve-Input([string]$p) {
    if ([System.IO.Path]::IsPathRooted($p)) { return $p }
    $c = Join-Path $root $p
    if (Test-Path $c) { return $c }
    return $p
}

$stockPath = Resolve-Input $StockSpec
$namesPath = Resolve-Input $NamesJson
$outPath   = if ([System.IO.Path]::IsPathRooted($OutFile)) { $OutFile } else { Join-Path $root $OutFile }

if (-not (Test-Path $stockPath)) { throw "missing $stockPath - run scripts\export_nida_spec.ps1 first" }
if (-not (Test-Path $namesPath)) { throw "missing $namesPath - run scripts\build_unicode_names.ps1 first" }

$nida = Get-Content $stockPath -Raw -Encoding UTF8 | ConvertFrom-Json
$nameMap = (Get-Content $namesPath -Raw -Encoding UTF8 | ConvertFrom-Json).names
$engine = & (Join-Path $PSScriptRoot 'midpoint_engine.ps1') -Spec $stockPath

function New-CharFromCps([int[]]$cps, [string]$note) {
    if (-not $cps -or $cps.Count -eq 0) { return $null }
    $txt = -join ($cps | ForEach-Object { [char]$_ })
    $labels = @(); $names = @()
    foreach ($cp in $cps) {
        $lbl = 'U+{0:X4}' -f $cp
        $labels += $lbl
        if ($nameMap.PSObject.Properties.Name -contains $lbl) { $names += $nameMap.$lbl }
    }
    $o = [ordered]@{
        text       = $txt
        codepoints = $labels
        names      = $names
    }
    if ($note) { $o['note'] = $note }
    if ($cps.Count -gt 1) { $o['isLigature'] = $true }
    return [PSCustomObject]$o
}

$keys = foreach ($k in $nida.keys) {
    $legend = $k.usLegend
    $ovLower = if ($legend -eq 'Space') { ' ' } else { $legend.ToLower() }
    $ovUpper = if ($legend -eq 'Space') { ' ' } else { $legend.ToUpper() }

    # Only apply legend-keyed overrides to main-block keys (which have a scanCode)
    $hasScan = [bool]$k.scanCode

    $normalCell = $k.chars.Normal
    if ($hasScan -and $engine.Static.Normal.ContainsKey($ovLower)) {
        $normalCell = New-CharFromCps $engine.Static.Normal[$ovLower] 'Rule 4: reclaimed unshifted key'
    }

    $shiftCell = $k.chars.Shift
    if ($hasScan -and $engine.Static.Shift.ContainsKey($ovUpper)) {
        $shiftCell = New-CharFromCps $engine.Static.Shift[$ovUpper] 'Rule 2: rollover-safe coeng'
    }

    $altGrCell = $k.chars.AltGr
    if ($hasScan -and $engine.Static.AltGr.ContainsKey($ovUpper)) {
        $altGrCell = New-CharFromCps $engine.Static.AltGr[$ovUpper] 'Midpoint AltGr relocation'
    }

    $shiftAltGrCell = $k.chars.ShiftAltGr
    if ($hasScan -and $engine.SecondSeries.Contains($ovLower)) {
        $shiftAltGrCell = New-CharFromCps @([int]$engine.SecondSeries[$ovLower]) 'Rule 5: static second-series consonant'
    }

    $chars = [ordered]@{
        Normal     = $normalCell
        Shift      = $shiftCell
        Control    = $k.chars.Control
        AltGr      = $altGrCell
        ShiftAltGr = $shiftAltGrCell
    }

    [PSCustomObject]([ordered]@{
        scanCode = $k.scanCode
        vk       = $k.vk
        vkHex    = $k.vkHex
        vkName   = $k.vkName
        usLegend = $k.usLegend
        chars    = [PSCustomObject]$chars
    })
}

$seqList = foreach ($r in $engine.Rules) {
    $cps = @([int[]]$r.Out)
    $ch = New-CharFromCps $cps $r.Note
    [PSCustomObject]([ordered]@{
        sequence   = $r.Seq
        rule       = $r.Rule
        note       = $r.Note
        text       = $ch.text
        codepoints = $ch.codepoints
        names      = $ch.names
    })
}

$doc = [ordered]@{
    layout = [ordered]@{
        name        = 'Khmer (Better-NiDA Midpoint)'
        slug        = 'nida_midpoint'
        baseLayout  = 'Khmer (NiDA) - kbdkni.dll (KLID 00010453)'
        locale      = 'km-KH'
        script      = 'Khmer (U+1780..U+17FF)'
        encoding    = 'Unicode'
        design      = '100% unshifted A-Z NiDA preservation + universal / series switch + double-tap vowels + reclaimed ] and \'
    }
    provenance = [ordered]@{
        sourceSpec     = 'nida_layout.json'
        engine         = 'scripts/midpoint_engine.ps1'
        verifiedBy     = 'scripts/verify_midpoint.ps1'
        characterNames = 'official Unicode Character Database (scripts/build_unicode_names.ps1)'
    }
    staticOverrides = [ordered]@{
        Normal     = @($engine.Static.Normal.Keys | Sort-Object)
        Shift      = @($engine.Static.Shift.Keys | Sort-Object)
        AltGr      = @($engine.Static.AltGr.Keys | Sort-Object)
        ShiftAltGr = @($engine.SecondSeries.Keys)
    }
    keys            = @($keys)
    sequences       = @($seqList)
    ligatures       = $nida.ligatures
    secondaryTables = $nida.secondaryTables
}

$json = ($doc | ConvertTo-Json -Depth 12).Replace("`r`n", "`n")
[System.IO.File]::WriteAllText($outPath, $json, (New-Object System.Text.UTF8Encoding $false))

Write-Host ("midpoint_layout.json: {0} keys, {1} sequences, {2} static ShiftAltGr keys" -f `
    @($keys).Count, @($seqList).Count, @($engine.SecondSeries.Keys).Count)
Write-Host "  -> $outPath"
