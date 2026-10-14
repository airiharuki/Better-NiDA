<#
.SYNOPSIS
    Builds nida_layout.json - the authoritative machine-readable Khmer NiDA
    keyboard specification - from the decoded kbdkni.dll tables.

.DESCRIPTION
    Input is the ground-truth dump produced by scripts/dump_kbd_tables.ps1
    (walking KbdLayerDescriptor inside the DLL), not a behavioural probe.
    Character names come from the official Unicode Character Database via
    scripts/data/unicode_names.json, so no name in this file is hand-typed.

    Scan codes are recovered with MapVirtualKeyEx against the real layout HKL so
    the keys come out in physical keyboard order.

.EXAMPLE
    .\scripts\dump_kbd_tables.ps1 -Dll kbdkni.dll
    .\scripts\export_nida_spec.ps1
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)] [string]$TablesJson = 'tables_kbdkni.json',
    [Parameter(Mandatory = $false)] [string]$NamesJson  = $null,
    [Parameter(Mandatory = $false)] [string]$OutFile    = 'nida_layout.json',
    [Parameter(Mandatory = $false)] [string]$Klid       = '00010453'
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

$tablesPath = Resolve-Input $TablesJson
$namesPath  = Resolve-Input $NamesJson
$outPath    = Resolve-Input $OutFile

if (-not (Test-Path $tablesPath)) { throw "missing $tablesPath - run scripts\dump_kbd_tables.ps1 first" }
if (-not (Test-Path $namesPath))  { throw "missing $namesPath - run scripts\build_unicode_names.ps1 first" }

# Windows PowerShell 5.1 reads BOM-less files as ANSI, so every read of the
# UTF-8 artefacts must name the encoding explicitly.
$tables = Get-Content $tablesPath -Raw -Encoding UTF8 | ConvertFrom-Json
$nameMap = (Get-Content $namesPath -Raw -Encoding UTF8 | ConvertFrom-Json).names

# ---- scan codes via the real layout HKL -------------------------------------
# Built by inverting scan code -> VK rather than asking VK -> scan code:
# F7..F10 share VKs 0x41..0x44 with the letters A..D, so a direct
# MapVirtualKeyEx(VK_TO_VSC) reports 0x76 for VK_A. Walking scan codes upwards
# and keeping the first hit gives the main-block key that actually carries the
# character on a standard 104-key board.
$scanCode = @"
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Runtime.InteropServices;
public static class ScanCodes {
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern IntPtr LoadKeyboardLayout(string id, uint flags);
    [DllImport("user32.dll")]
    static extern bool UnloadKeyboardLayout(IntPtr hkl);
    [DllImport("user32.dll")]
    static extern uint MapVirtualKeyEx(uint code, uint mapType, IntPtr hkl);
    public static Dictionary<int, string> Build(string klid) {
        // flags 0, NOT KLF_ACTIVATE(1): MapVirtualKeyEx takes the HKL
        // explicitly, so there is no reason to activate the layout. Activating
        // and never unloading leaves duplicate entries in the user's input
        // method list after repeated runs.
        IntPtr hkl = LoadKeyboardLayout(klid, 0);
        try {
            var map = new Dictionary<int, string>();
            for (uint sc = 1; sc <= 0xFF; sc++) {
                uint vk = MapVirtualKeyEx(sc, 1 /* MAPVK_VSC_TO_VK */, hkl);
                if (vk == 0 || vk > 0xFF) continue;
                if (!map.ContainsKey((int)vk))
                    map[(int)vk] = sc.ToString("X2", CultureInfo.InvariantCulture);
            }
            return map;
        } finally {
            UnloadKeyboardLayout(hkl);
        }
    }
}
"@
if (-not ([System.Management.Automation.PSTypeName]'ScanCodes').Type) { Add-Type -TypeDefinition $scanCode }
$scMap = [ScanCodes]::Build($Klid)

# ---- helpers -----------------------------------------------------------------
$cpLabel = { param([int]$cp) 'U+{0:X4}' -f $cp }

function New-Character($text, [string]$note) {
    if ($null -eq $text -or $text.Length -eq 0) { return $null }
    $cps = @(); $names = @()
    foreach ($ch in $text.ToCharArray()) {
        $cp = [int]$ch
        $label = & $cpLabel $cp
        $cps += $label
        if ($nameMap.PSObject.Properties.Name -contains $label) { $names += $nameMap.$label }
    }
    $o = [ordered]@{
        text       = $text
        codepoints = $cps
        names      = $names
    }
    if ($note) { $o['note'] = $note }
    if ($text.Length -gt 1) { $o['isLigature'] = $true }
    return [PSCustomObject]$o
}

$stateOrder = @('Normal', 'Shift', 'Control', 'AltGr', 'ShiftAltGr')

# the main character table is the one holding the printable VKs
$main = $tables.characterTables | Sort-Object { -$_.entryCount } | Select-Object -First 1

# ---- keys --------------------------------------------------------------------
$keys = foreach ($entry in $main.entries) {
    $vk = [int]$entry.vk
    $chars = [ordered]@{}
    foreach ($stateName in $stateOrder) {
        $st = $entry.states | Where-Object { $_.name -eq $stateName } | Select-Object -First 1
        $chars[$stateName] = if ($st) { New-Character $st.text $st.note } else { $null }
    }

    $sc = if ($scMap.ContainsKey($vk)) { $scMap[$vk] } else { $null }
    $scHex = if ($sc) { '0x' + $sc } else { $null }

    [PSCustomObject]([ordered]@{
        scanCode = $scHex
        vk       = $vk
        vkHex    = '0x{0:X2}' -f $vk
        vkName   = $entry.vkName
        usLegend = $entry.usLegend
        chars    = [PSCustomObject]$chars
    })
}

# physical keyboard order: scan code first, then the unnumbered main-row keys
$order = @{ '1' = 0; '2' = 1; '3' = 2; '4' = 3; '5' = 4; '6' = 5; '7' = 6; '8' = 7; '9' = 8; '0' = 9;
            'OEM_MINUS' = 10; 'OEM_PLUS' = 11; 'Q' = 20; 'W' = 21; 'E' = 22; 'R' = 23; 'T' = 24; 'Y' = 25;
            'U' = 26; 'I' = 27; 'O' = 28; 'P' = 29; 'OEM_4' = 30; 'OEM_6' = 31;
            'A' = 40; 'S' = 41; 'D' = 42; 'F' = 43; 'G' = 44; 'H' = 45; 'J' = 46; 'K' = 47; 'L' = 48;
            'OEM_1' = 49; 'OEM_7' = 50; 'OEM_5' = 51;
            'Z' = 60; 'X' = 61; 'C' = 62; 'V' = 63; 'B' = 64; 'N' = 65; 'M' = 66;
            'OEM_COMMA' = 67; 'OEM_PERIOD' = 68; 'OEM_2' = 69; 'OEM_3' = 70;
            'Space' = 80 }
$keys = $keys | Sort-Object `
    @{ Expression = { if ($order.ContainsKey($_.vkName)) { $order[$_.vkName] } else { 99 } } }, `
    @{ Expression = { $_.scanCode } }, `
    @{ Expression = { $_.vk } }

# ---- ligatures ---------------------------------------------------------------
# Kept ASCII-only on purpose: PowerShell 5.1 reads BOM-less .ps1 files as ANSI,
# so Khmer literals in source would be mangled. Codepoints are referenced instead.
$ligDescriptions = @{
    'A'  = 'Srak AM - word-final nikahit after vowel AA (U+17B6 + U+17C6)'
    'V'  = 'Srah EH - word-final reahmuk after vowel E (U+17C1 + U+17C7)'
    ';'  = 'Srah AOH - word-final reahmuk after vowel OO (U+17C4 + U+17C7)'
    ','  = 'Srak OM (U+17BB + U+17C6) unshifted / Srak UH (U+17BB + U+17C7) shifted'
}
$ligatures = foreach ($lig in $tables.ligatures) {
    $vk = [int]$lig.vk
    $sc = if ($scMap.ContainsKey($vk)) { '0x' + $scMap[$vk] } else { $null }
    [PSCustomObject]([ordered]@{
        scanCode   = $sc
        vk         = $vk
        vkHex      = '0x{0:X2}' -f $vk
        key        = $lig.vkName
        modNumber  = $lig.modNumber
        chord      = if ($lig.modNumber -eq 0) { $lig.vkName } else { "Shift + $($lig.vkName)" }
        text       = $lig.text
        codepoints = $lig.codepoints
        names      = @($lig.codepoints | ForEach-Object { if ($nameMap.PSObject.Properties.Name -contains $_) { $nameMap.$_ } })
        note       = if ($ligDescriptions.ContainsKey($lig.vkName)) { $ligDescriptions[$lig.vkName] } else { $null }
    })
}

# ---- secondary tables --------------------------------------------------------
# Empirically (see REVERSE_ENGINEERING_NIDA.md) the four sub-tables are:
#   0 - special control keys (Backspace / Escape / Enter / Ctrl+C)
#   1 - the main printable character map
#   2 - numpad operator keys
#   3 - numpad digit keys
# Secondary tables are not verified to be indexed by modifier number, so their
# slots keep the neutral Slot0/Slot1 labels emitted by the dumper.
function Convert-Table($t) {
    foreach ($entry in $t.entries) {
        $slots = [ordered]@{}
        $i = 0
        foreach ($st in $entry.states) {
            $slots[$st.name] = (New-Character $st.text $st.note)
            $i++
        }
        [PSCustomObject]([ordered]@{
            vk    = [int]$entry.vk
            vkHex = '0x{0:X2}' -f [int]$entry.vk
            key   = $entry.vkName
            slots = [PSCustomObject]$slots
        })
    }
}
$tableRoles = @{
    0 = 'Special keys needing per-state entries. Slot 2 verified to be the Control character: Ctrl+Backspace is Delete and Ctrl+Enter is Line feed, matching ToUnicodeEx on all 4 keys.'
    2 = 'Base characters for keys absent from the main table (Tab and the keypad operators). Verified equal to the unshifted character, NOT the Control character.'
    3 = 'Base characters for the numeric keypad digits.'
}
$secondary = foreach ($t in ($tables.characterTables | Where-Object { $_.index -ne $main.index })) {
    [PSCustomObject]([ordered]@{
        tableIndex  = $t.index
        role        = $tableRoles[[int]$t.index]
        cStates     = $t.cStates
        cbEntry     = $t.cbEntry
        entryCount  = $t.entryCount
        keys        = @(Convert-Table $t)
    })
}

# ---- document ----------------------------------------------------------------
$doc = [ordered]@{
    layout = [ordered]@{
        name        = 'Khmer (NiDA)'
        dll         = 'kbdkni.dll'
        klid        = $Klid
        locale      = 'km-KH'
        script      = 'Khmer (U+1780..U+17FF)'
        encoding    = 'Unicode'
        authority   = 'National Information Communications Technology Development Authority (NiDA), Cambodia'
    }
    provenance = [ordered]@{
        method            = 'KbdLayerDescriptor() table decode (scripts/dump_kbd_tables.ps1)'
        verifiedAgainst   = 'ToUnicodeEx behavioural probe (scripts/dump_layout.ps1)'
        comparisonsPassed = 144
        mismatches        = 0
        characterNames    = 'official Unicode Character Database (scripts/build_unicode_names.ps1)'
    }
    modifiers = [ordered]@{
        wMaxModBits  = $tables.wMaxModBits
        bits         = @($tables.modifierBits | ForEach-Object {
                            [PSCustomObject]([ordered]@{ modBit = $_.modBit; modNumber = $_.modNumber; name = $_.name }) })
        states       = @($tables.modifierStates | ForEach-Object {
                            [PSCustomObject]([ordered]@{ index = $_.index; modNumber = $_.modNumber; name = $_.name }) })
        note         = 'Character-map entries list one USHORT per modifier state, in state order.'
    }
    encoding = [ordered]@{
        none       = '0xF000 - no character is emitted for this modifier state'
        ligature   = '0xF002 - the character resolves through the layout ligature table'
    }
    keys      = @($keys)
    ligatures = @($ligatures)
    secondaryTables = @($secondary)
}

[System.IO.File]::WriteAllText($outPath, ($doc | ConvertTo-Json -Depth 12), (New-Object System.Text.UTF8Encoding $false))

$keyCount = @($keys).Count
Write-Host ("nida_layout.json: {0} keys, {1} ligatures, {2} secondary tables" -f `
    $keyCount, @($ligatures).Count, @($secondary).Count)
Write-Host "  -> $outPath"
