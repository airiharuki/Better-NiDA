<#
.SYNOPSIS
    Generates the macOS and Linux keyboard layouts from the verified spec.

.DESCRIPTION
    Emits, from nida_layout.json and tables_kbdkhmr.json:

      macos/<name>.keylayout      Apple XML keylayout bundles (both variants)
      linux/nida, linux/nida_legacy   XKB symbols files (both variants)

    Both variants are produced from the same generator, so the two can never
    drift apart.

    Modifier level mapping (XKB and macOS keyMap index):
      0 Normal   1 Shift   2 Control   3 AltGr   4 Shift+AltGr
    Control is empty in both source layouts, so level 2 is only emitted when
    the data actually defines it (legacy Khmer's Shift+AltGr block).

    LIGATURE CAVEAT - the single most important limitation here:
      XKB maps one key to exactly one keysym per level and cannot emit two
      code points for one keystroke. The five NiDA ligatures therefore fall
      back to their first code point, and each is marked with a comment.
      macOS keylayouts CAN emit several characters in one output, so the
      ligatures are reproduced faithfully there.
      For full ligature support on Linux see linux/m17n/.

.PARAMETER Variant
    Limit generation to one variant (default: both).

.EXAMPLE
    .\scripts\build_platform_layouts.ps1
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('both', 'nida', 'legacy')]
    [string]$Variant = 'both',

    [Parameter(Mandatory = $false)]
    [string]$OutRoot = $null
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# ASCII-only source: PowerShell 5.1 reads BOM-less .ps1 as ANSI and mangles
# non-ASCII literals. All Khmer text is written by a separate UTF-8 writer
# using NewUtf8File() below.

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not $OutRoot) { $OutRoot = $root }

function New-Utf8File([string]$Path, [string]$Content) {
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding $false))
}

# ---------------------------------------------------------------------------
# scan code -> platform key identifiers
# ---------------------------------------------------------------------------
$XkbByScan = @{
    0x02='AE01'; 0x03='AE02'; 0x04='AE03'; 0x05='AE04'; 0x06='AE05'; 0x07='AE06'
    0x08='AE07'; 0x09='AE08'; 0x0A='AE09'; 0x0B='AE10'; 0x0C='AE11'; 0x0D='AE12'
    0x10='AD01'; 0x11='AD02'; 0x12='AD03'; 0x13='AD04'; 0x14='AD05'; 0x15='AD06'
    0x16='AD07'; 0x17='AD08'; 0x18='AD09'; 0x19='AD10'; 0x1A='AD11'; 0x1B='AD12'
    0x1C='RTRN'
    0x1E='AC01'; 0x1F='AC02'; 0x20='AC03'; 0x21='AC04'; 0x22='AC05'; 0x23='AC06'
    0x24='AC07'; 0x25='AC08'; 0x26='AC09'; 0x27='AC10'; 0x28='AC11'
    0x29='TLDE'; 0x2B='BKSL'
    0x2C='AB01'; 0x2D='AB02'; 0x2E='AB03'; 0x2F='AB04'; 0x30='AB05'; 0x31='AB06'
    0x32='AB07'; 0x33='AB08'; 0x34='AB09'; 0x35='AB10'
    0x37='KPMU'; 0x39='SPCE'; 0x4A='KPSU'; 0x4E='KPAD'; 0x53='KPDL'
}

# Apple ANSI virtual key codes, keyed by the same scan codes.
# Number row order is NOT positional on Apple: 5=23, 6=22, 7=26, 8=28, 9=25.
$MacByScan = @{
    0x02=18; 0x03=19; 0x04=20; 0x05=21; 0x06=23; 0x07=22; 0x08=26; 0x09=28
    0x0A=25; 0x0B=29; 0x0C=27; 0x0D=24
    0x10=12; 0x11=13; 0x12=14; 0x13=15; 0x14=17; 0x15=16; 0x16=32; 0x17=34
    0x18=31; 0x19=35; 0x1A=33; 0x1B=30; 0x1C=36
    0x1E=0;  0x1F=1;  0x20=2;  0x21=3;  0x22=5;  0x23=4;  0x24=38; 0x25=40
    0x26=37; 0x27=41; 0x28=39; 0x29=50; 0x2B=42
    0x2C=6;  0x2D=7;  0x2E=8;  0x2F=9;  0x30=11; 0x31=45; 0x32=46
    0x33=43; 0x34=47; 0x35=44; 0x37=67; 0x39=49; 0x4A=78; 0x4E=81; 0x53=65
}

function Get-XkbName([int]$scan) { if ($XkbByScan.ContainsKey($scan)) { $XkbByScan[$scan] } else { $null } }
function Get-MacCode([int]$scan) { if ($MacByScan.ContainsKey($scan)) { $MacByScan[$scan] } else { $null } }

function Get-CpArray($ch) {
    if ($null -eq $ch) { return @() }
    return @($ch.codepoints | ForEach-Object { [Convert]::ToInt32(($_ -replace '^U\+',''), 16) })
}
function Get-Text($ch) { if ($null -eq $ch) { return $null } return [string]$ch.text }

# ---------------------------------------------------------------------------
# load the two variants into a common shape:
#   @{ Name; Slug; ScanKeys = @(@{Scan;Levels=@(@{Text;Cps;IsLig})}...) }
# ---------------------------------------------------------------------------
$stateOrder = @('Normal', 'Shift', 'Control', 'AltGr', 'ShiftAltGr')

function Get-ScanMap {
    $code = @"
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Runtime.InteropServices;
public static class ScanMap2 {
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern IntPtr LoadKeyboardLayout(string id, uint flags);
    [DllImport("user32.dll")]
    static extern uint MapVirtualKeyEx(uint code, uint mapType, IntPtr hkl);
    public static Dictionary<int, int> Build(string klid) {
        IntPtr hkl = LoadKeyboardLayout(klid, 1);
        var map = new Dictionary<int, int>();
        for (uint sc = 1; sc <= 0xFF; sc++) {
            uint vk = MapVirtualKeyEx(sc, 1, hkl);
            if (vk == 0 || vk > 0xFF) continue;
            if (!map.ContainsKey((int)vk)) map[(int)vk] = (int)sc;
        }
        return map;
    }
}
"@
    if (-not ([System.Management.Automation.PSTypeName]'ScanMap2').Type) { Add-Type -TypeDefinition $code -Language CSharp }
    $m = [ScanMap2]::Build('00010453')
    $out = @{}
    foreach ($k in $m.Keys) { $out[$k] = $m[$k] }
    return $out
}

function New-VariantFromSpec($spec, $name, $slug, $ligatures) {
    $keys = @()
    foreach ($k in $spec.keys) {
        if (-not $k.scanCode) { continue }
        $scan = [Convert]::ToInt32(($k.scanCode -replace '^0x',''), 16)
        $levels = @()
        foreach ($s in $stateOrder) {
            $ch = $null
            if ($k.chars.PSObject.Properties.Name -contains $s) { $ch = $k.chars.$s }
            $txt = Get-Text $ch
            # note/isLigature are optional in the spec, so probe before reading
            $isLig = $false
            if ($ch) {
                if ($ch.PSObject.Properties.Name -contains 'isLigature') { $isLig = [bool]$ch.isLigature }
                elseif ($ch.PSObject.Properties.Name -contains 'note') { $isLig = ($ch.note -eq 'ligature') }
                if (-not $isLig -and $txt -and $txt.Length -gt 1) { $isLig = $true }
            }
            $levels += [PSCustomObject]@{
                Text = $txt
                Cps  = @(Get-CpArray $ch)
                IsLigature = $isLig
            }
        }
        $keys += [PSCustomObject]@{ Scan = $scan; Legend = $k.usLegend; Levels = $levels }
    }
    return [PSCustomObject]@{ Name = $name; Slug = $slug; Keys = $keys; Ligatures = $ligatures }
}

function New-VariantFromTables($tables, $name, $slug, $scanMap) {
    $main = $tables.characterTables | Sort-Object { -$_.entryCount } | Select-Object -First 1
    $lig = @($tables.ligatures | ForEach-Object {
        [PSCustomObject]@{
            Key = $_.vkName; Mod = [int]$_.modNumber
            Text = $_.text
            Cps  = @($_.codepoints | ForEach-Object { [Convert]::ToInt32(($_ -replace '^U\+',''), 16) })
        }
    })
    $keys = @()
    foreach ($e in $main.entries) {
        $vk = [int]$e.vk
        if (-not $scanMap.ContainsKey($vk)) { continue }
        $scan = $scanMap[$vk]
        $levels = @()
        foreach ($s in $stateOrder) {
            $st = $e.states | Where-Object { $_.name -eq $s } | Select-Object -First 1
            $txt = $null; $cps = @(); $isLig = $false
            if ($st -and $st.text) {
                $txt = [string]$st.text
                $cps = @(foreach ($c in $txt.ToCharArray()) { [int]$c })
                $isLig = ($txt.Length -gt 1)
            }
            $levels += [PSCustomObject]@{ Text = $txt; Cps = $cps; IsLigature = $isLig }
        }
        $keys += [PSCustomObject]@{ Scan = $scan; Legend = $e.usLegend; Levels = $levels }
    }
    return [PSCustomObject]@{ Name = $name; Slug = $slug; Keys = $keys; Ligatures = $lig }
}

# ---------------------------------------------------------------------------
# emitters
# ---------------------------------------------------------------------------
function ConvertTo-XmlAttr([string]$s) {
    if ($null -eq $s) { return '' }
    # The data contains " and & (e.g. Shift+3 is U+0022); unescaped they would
    # terminate the XML attribute and make the whole keylayout unparseable.
    $s.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;').Replace("'", '&apos;')
}

function Get-XkbKeysym($cps) {
    if ($null -eq $cps -or $cps.Count -eq 0) { return $null }
    $parts = @($cps | ForEach-Object { 'U{0:X4}' -f $_ })
    if ($parts.Count -eq 1) { return $parts[0] }
    return ($parts -join '')
}

function New-XkbFile($v, $source) {
    $hasLevel4 = @($v.Keys | Where-Object { $_.Levels.Count -gt 4 -and $_.Levels[4].Text }).Count -gt 0
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('// ' + $v.Name + ' - generated by scripts/build_platform_layouts.ps1')
    [void]$sb.AppendLine('// Source: ' + $source)
    [void]$sb.AppendLine('// DO NOT EDIT BY HAND - edit the generator, or fork it freely.')
    [void]$sb.AppendLine('//')
    [void]$sb.AppendLine('// LIGATURES: XKB maps one key to one keysym per level, so the')
    [void]$sb.AppendLine('// multi-code-point ligatures in the Windows driver cannot be reproduced')
    [void]$sb.AppendLine('// here. Those levels emit the FIRST code point only; see linux/m17n/ for')
    [void]$sb.AppendLine('// an input method that supports them properly.')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('default partial alphanumeric_keys')
    [void]$sb.AppendLine('xkb_symbols "' + $v.Slug + '" {')
    [void]$sb.AppendLine('    name[Group1]= "' + $v.Name + '";')
    [void]$sb.AppendLine('')
    if ($hasLevel4) {
        [void]$sb.AppendLine('    // five levels: Normal, Shift, Control, AltGr, Shift+AltGr')
        [void]$sb.AppendLine('    key.type[Group1]= "EIGHT_LEVEL";')
    } else {
        [void]$sb.AppendLine('    // four levels: Normal, Shift, Control, AltGr')
        [void]$sb.AppendLine('    key.type[Group1]= "FOUR_LEVEL";')
    }
    [void]$sb.AppendLine('')

    foreach ($k in $v.Keys | Sort-Object Scan) {
        $name = Get-XkbName $k.Scan
        if (-not $name) { continue }
        $syms = @()
        $ligNote = ''
        for ($i = 0; $i -lt 4; $i++) {
            $lv = $k.Levels[$i]
            if ($lv.IsLigature) {
                # XKB cannot express this; fall back to the first code point.
                $syms += (Get-XkbKeysym @($lv.Cps[0]))
                if (-not $ligNote) { $ligNote = ' // LIGATURE truncated to first code point' }
            } else {
                $syms += (Get-XkbKeysym $lv.Cps)
            }
        }
        if ($hasLevel4) {
            $lv4 = $k.Levels[4]
            if ($lv4.IsLigature) { $syms += (Get-XkbKeysym @($lv4.Cps[0])) }
            else { $syms += (Get-XkbKeysym $lv4.Cps) }
        }
        while ($syms.Count -lt 2) { $syms += 'NoSymbol' }
        $symList = (($syms | ForEach-Object { if ($_) { $_ } else { 'NoSymbol' } }) -join ', ')
        # A REAL tab, not the two characters ` + t: a literal backtick would be
        # parsed as part of the key name and silently break the whole file.
        $line = '    key <' + $name + '>' + [char]9 + '{ ' + $symList + ' };' + $ligNote
        [void]$sb.AppendLine($line)
    }
    [void]$sb.AppendLine('};')
    return $sb.ToString()
}

function New-MacKeylayout($v, $source) {
    # Standard Apple modifier map: index 0 none, 1 shift, 2 caps,
    # 3 option (AltGr), 4 shift+option, 5 caps+option, 6 caps+command, 7 other.
    $hasLevel4 = @($v.Keys | Where-Object { $_.Levels.Count -gt 4 -and $_.Levels[4].Text }).Count -gt 0

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
    [void]$sb.AppendLine('<!DOCTYPE keyboard PUBLIC "" "file://localhost/System/Library/DTDs/KeyboardLayout.dtd">')
    [void]$sb.AppendLine('<!-- ' + $v.Name + ' - generated by scripts/build_platform_layouts.ps1')
    [void]$sb.AppendLine('     Source: ' + $source + ' -->')
    [void]$sb.AppendLine('<keyboard group="0" id="1337" name="' + $v.Name + '" maxout="3">')
    [void]$sb.AppendLine('    <layouts>')
    [void]$sb.AppendLine('        <layout first="0" last="126" modifiers="mod" mapSet="ans"/>')
    [void]$sb.AppendLine('    </layouts>')
    [void]$sb.AppendLine('    <modifierMap id="mod" defaultIndex="7">')
    [void]$sb.AppendLine('        <keyMapSelect mapIndex="0">')
    [void]$sb.AppendLine('            <modifier keys="command?"/>')
    [void]$sb.AppendLine('            <modifier keys="anyShift? caps? command"/>')
    [void]$sb.AppendLine('        </keyMapSelect>')
    [void]$sb.AppendLine('        <keyMapSelect mapIndex="1">')
    [void]$sb.AppendLine('            <modifier keys="anyShift caps?"/>')
    [void]$sb.AppendLine('        </keyMapSelect>')
    [void]$sb.AppendLine('        <keyMapSelect mapIndex="2">')
    [void]$sb.AppendLine('            <modifier keys="caps"/>')
    [void]$sb.AppendLine('        </keyMapSelect>')
    [void]$sb.AppendLine('        <keyMapSelect mapIndex="3">')
    [void]$sb.AppendLine('            <modifier keys="anyOption"/>')
    [void]$sb.AppendLine('        </keyMapSelect>')
    [void]$sb.AppendLine('        <keyMapSelect mapIndex="4">')
    [void]$sb.AppendLine('            <modifier keys="anyShift caps? anyOption command?"/>')
    [void]$sb.AppendLine('        </keyMapSelect>')
    [void]$sb.AppendLine('        <keyMapSelect mapIndex="5">')
    [void]$sb.AppendLine('            <modifier keys="caps anyOption"/>')
    [void]$sb.AppendLine('        </keyMapSelect>')
    [void]$sb.AppendLine('        <keyMapSelect mapIndex="6">')
    [void]$sb.AppendLine('            <modifier keys="caps? anyOption command"/>')
    [void]$sb.AppendLine('        </keyMapSelect>')
    [void]$sb.AppendLine('        <keyMapSelect mapIndex="7">')
    [void]$sb.AppendLine('            <modifier keys="anyShift caps? option? command? control"/>')
    [void]$sb.AppendLine('            <modifier keys="shift? caps? anyOption command? control"/>')
    [void]$sb.AppendLine('            <modifier keys="caps? anyOption? command? control"/>')
    [void]$sb.AppendLine('        </keyMapSelect>')
    [void]$sb.AppendLine('    </modifierMap>')

    # keyMapSet: index 0 base, 1 shift, 2 caps (same as base), 3 option,
    # and 4 shift+option when the source layout defines that state.
    $mapCount = if ($hasLevel4) { 5 } else { 4 }
    [void]$sb.AppendLine('    <keyMapSet id="ans">')
    for ($i = 0; $i -lt $mapCount; $i++) {
        [void]$sb.AppendLine('        <keyMap index="' + $i + '">')
        foreach ($k in $v.Keys | Sort-Object Scan) {
            $code = Get-MacCode $k.Scan
            if ($null -eq $code) { continue }
            # mapIndex 0 = base, 1 = shift, 2 = caps (repeats base), 3 = option
            # (AltGr), 4 = shift+option (Shift+AltGr).
            $lvIndex = switch ($i) { 0 { 0 } 1 { 1 } 2 { 0 } 3 { 3 } default { 4 } }
            $lv = $k.Levels[$lvIndex]
            if ($lv.Text) {
                # macOS keylayout CAN emit several characters in one output, so
                # ligatures are reproduced faithfully here.
                [void]$sb.AppendLine('            <key code="' + $code + '" output="' + (ConvertTo-XmlAttr $lv.Text) + '"/>')
            }
        }
        # Return and Tab must stay reachable in every modifier state, otherwise
        # the layout would make it impossible to submit a line.
        [void]$sb.AppendLine('            <key code="36" output="&#x000D;"/>')
        [void]$sb.AppendLine('            <key code="48" output="&#x0009;"/>')
        [void]$sb.AppendLine('        </keyMap>')
    }
    [void]$sb.AppendLine('    </keyMapSet>')
    [void]$sb.AppendLine('</keyboard>')
    return $sb.ToString()
}

# ---------------------------------------------------------------------------
# build
# ---------------------------------------------------------------------------
$nidaSpec = Get-Content (Join-Path $root 'nida_layout.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$khmrTables = Get-Content (Join-Path $root 'tables_kbdkhmr.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$scanMap = Get-ScanMap

$variants = @()
if ($Variant -in @('both','nida')) {
    $variants += New-VariantFromSpec $nidaSpec 'Khmer NiDA' 'nida' @()
}
if ($Variant -in @('both','legacy')) {
    $variants += New-VariantFromTables $khmrTables 'Khmer NiDA Legacy' 'nida_legacy' $scanMap
}

foreach ($v in $variants) {
    $src = if ($v.Slug -eq 'nida') { 'nida_layout.json (kbdkni.dll, KLID 00010453)' } else { 'tables_kbdkhmr.json (kbdkhmr.dll, KLID 00000453)' }
    $macPath = Join-Path $OutRoot ("macos\$($v.Name).keylayout")
    New-Utf8File $macPath (New-MacKeylayout $v $src)
    $xkbPath = Join-Path $OutRoot "linux\$($v.Slug)"
    New-Utf8File $xkbPath (New-XkbFile $v $src)

    $ligCount = @($v.Keys | Where-Object { @($_.Levels | Where-Object { $_.IsLigature }).Count -gt 0 }).Count
    Write-Host ("{0,-22} macos/{1}.keylayout   linux/{2}   ({3} keys, {4} ligature keys)" -f `
        $v.Name, $v.Name, $v.Slug, $v.Keys.Count, $ligCount)
}
