<#
.SYNOPSIS
    Generates the macOS, Linux, and Windows (Keyman) keyboard layouts from the
    verified specifications.

.DESCRIPTION
    Emits, from nida_layout.json, tables_kbdkhmr.json, and midpoint_layout.json:

      macos/Khmer NiDA.keylayout             Apple XML keylayout (stock NiDA)
      macos/Khmer NiDA Legacy.keylayout      Apple XML keylayout (legacy Khmer)
      macos/Khmer Better-NiDA.keylayout      Apple XML keylayout (Midpoint static)
      linux/nida                             XKB symbols (stock NiDA)
      linux/nida_legacy                      XKB symbols (legacy Khmer)
      linux/nida_midpoint                    XKB symbols (Midpoint static)
      linux/m17n/nida-midpoint.mim           m17n input method (Midpoint full)
      windows/better_nida_midpoint.kmn       Keyman keyboard source (Midpoint full)

    All variants are produced from the same generator pipeline, so the
    platforms can never drift apart.

    Modifier level mapping (XKB and macOS keyMap index):
      0 Normal   1 Shift   2 Control   3 AltGr   4 Shift+AltGr
    Control is empty in the source layouts, so level 2 is only emitted when
    the data actually defines level 4 (legacy Khmer and Better-NiDA Midpoint).

.PARAMETER Variant
    Limit generation to one variant (default: all).

.EXAMPLE
    .\scripts\build_platform_layouts.ps1
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('both', 'all', 'nida', 'legacy', 'midpoint')]
    [string]$Variant = 'all',

    [Parameter(Mandatory = $false)]
    [string]$OutRoot = $null
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# ASCII-only source: PowerShell 5.1 reads BOM-less .ps1 as ANSI and mangles
# non-ASCII literals. All Khmer text is written by New-Utf8File() below.

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not $OutRoot) { $OutRoot = $root }

function New-Utf8File([string]$Path, [string]$Content) {
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    # Force LF across all generated files (.keylayout, XKB, .mim, .kmn).
    $Content = $Content.Replace("`r`n", "`n")
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

# Keyman virtual key identifiers keyed by US legend.
$KeymanByLegend = @{
    '1'='K_1'; '2'='K_2'; '3'='K_3'; '4'='K_4'; '5'='K_5'
    '6'='K_6'; '7'='K_7'; '8'='K_8'; '9'='K_9'; '0'='K_0'
    '-'='K_HYPHEN'; '='='K_EQUAL'
    'Q'='K_Q'; 'W'='K_W'; 'E'='K_E'; 'R'='K_R'; 'T'='K_T'
    'Y'='K_Y'; 'U'='K_U'; 'I'='K_I'; 'O'='K_O'; 'P'='K_P'
    '['='K_LBRKT'; ']'='K_RBRKT'
    'A'='K_A'; 'S'='K_S'; 'D'='K_D'; 'F'='K_F'; 'G'='K_G'
    'H'='K_H'; 'J'='K_J'; 'K'='K_K'; 'L'='K_L'
    ';'='K_COLON'; "'"='K_QUOTE'; '\'='K_BKSLASH'
    'Z'='K_Z'; 'X'='K_X'; 'C'='K_C'; 'V'='K_V'; 'B'='K_B'
    'N'='K_N'; 'M'='K_M'; ','='K_COMMA'; '.'='K_PERIOD'; '/'='K_SLASH'
    '`'='K_BKQUOTE'; 'Space'='K_SPACE'; ' '='K_SPACE'
}

function Get-XkbName([int]$scan) { if ($XkbByScan.ContainsKey($scan)) { $XkbByScan[$scan] } else { $null } }
function Get-MacCode([int]$scan) { if ($MacByScan.ContainsKey($scan)) { $MacByScan[$scan] } else { $null } }

function Get-CpArray($ch) {
    if ($null -eq $ch) { return @() }
    return @($ch.codepoints | ForEach-Object { [Convert]::ToInt32(($_ -replace '^U\+',''), 16) })
}
function Get-Text($ch) { if ($null -eq $ch) { return $null } return [string]$ch.text }

# ---------------------------------------------------------------------------
# load the variants into a common shape
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
    static extern bool UnloadKeyboardLayout(IntPtr hkl);
    [DllImport("user32.dll")]
    static extern uint MapVirtualKeyEx(uint code, uint mapType, IntPtr hkl);
    public static Dictionary<int, int> Build(string klid) {
        IntPtr hkl = LoadKeyboardLayout(klid, 0);
        try {
            var map = new Dictionary<int, int>();
            for (uint sc = 1; sc <= 0xFF; sc++) {
                uint vk = MapVirtualKeyEx(sc, 1, hkl);
                if (vk == 0 || vk > 0xFF) continue;
                if (!map.ContainsKey((int)vk)) map[(int)vk] = (int)sc;
            }
            return map;
        } finally {
            UnloadKeyboardLayout(hkl);
        }
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
# emitters: XKB and macOS .keylayout
# ---------------------------------------------------------------------------
function ConvertTo-XmlAttr([string]$s) {
    if ($null -eq $s) { return '' }
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
        $line = '    key <' + $name + '>' + [char]9 + '{ ' + $symList + ' };' + $ligNote
        [void]$sb.AppendLine($line)
    }
    [void]$sb.AppendLine('};')
    return $sb.ToString()
}

function New-MacKeylayout($v, $source, [int]$kbId = 1337) {
    $hasLevel4 = @($v.Keys | Where-Object { $_.Levels.Count -gt 4 -and $_.Levels[4].Text }).Count -gt 0

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
    [void]$sb.AppendLine('<!DOCTYPE keyboard PUBLIC "" "file://localhost/System/Library/DTDs/KeyboardLayout.dtd">')
    [void]$sb.AppendLine('<!-- ' + $v.Name + ' - generated by scripts/build_platform_layouts.ps1')
    [void]$sb.AppendLine('     Source: ' + $source + ' -->')
    [void]$sb.AppendLine('<keyboard group="0" id="' + $kbId + '" name="' + $v.Name + '" maxout="3">')
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

    $mapCount = if ($hasLevel4) { 5 } else { 4 }
    [void]$sb.AppendLine('    <keyMapSet id="ans">')
    for ($i = 0; $i -lt $mapCount; $i++) {
        [void]$sb.AppendLine('        <keyMap index="' + $i + '">')
        foreach ($k in $v.Keys | Sort-Object Scan) {
            $code = Get-MacCode $k.Scan
            if ($null -eq $code) { continue }
            $lvIndex = switch ($i) { 0 { 0 } 1 { 1 } 2 { 0 } 3 { 3 } default { 4 } }
            $lv = $k.Levels[$lvIndex]
            if ($lv.Text) {
                [void]$sb.AppendLine('            <key code="' + $code + '" output="' + (ConvertTo-XmlAttr $lv.Text) + '"/>')
            }
        }
        [void]$sb.AppendLine('            <key code="36" output="&#x000D;"/>')
        [void]$sb.AppendLine('            <key code="48" output="&#x0009;"/>')
        [void]$sb.AppendLine('        </keyMap>')
    }
    [void]$sb.AppendLine('    </keyMapSet>')
    [void]$sb.AppendLine('</keyboard>')
    return $sb.ToString()
}

# ---------------------------------------------------------------------------
# emitter: Linux m17n (linux/m17n/nida-midpoint.mim)
# ---------------------------------------------------------------------------
function ConvertTo-MimString([string]$s) {
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $s.ToCharArray()) {
        if ($ch -eq '\') { [void]$sb.Append('\\') }
        elseif ($ch -eq '"') { [void]$sb.Append('\"') }
        else { [void]$sb.Append($ch) }
    }
    return $sb.ToString()
}

function New-MidpointMimFile($midSpec) {
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine(';; m17n input method for Khmer Better-NiDA (Midpoint).')
    [void]$sb.AppendLine(';; Generated by scripts/build_platform_layouts.ps1 from midpoint_layout.json.')
    [void]$sb.AppendLine(';; DO NOT EDIT BY HAND - edit scripts/midpoint_engine.ps1 and regenerate.')
    [void]$sb.AppendLine(';;')
    [void]$sb.AppendLine(';; Implements both the static layer overrides (Rules 2, 4, 5) and the')
    [void]$sb.AppendLine(';; prefix-buffered sequence rules (Rules 1, 2, 3):')
    [void]$sb.AppendLine(';;   - Rule 1: universal "/" series switch (k/ -> U+1782, b/ -> U+1796, etc.)')
    [void]$sb.AppendLine(';;   - Rule 2: rollover-safe Shift+J -> U+17D2, jj -> U+1789, j/ -> U+17D2 U+1789')
    [void]$sb.AppendLine(';;   - Rule 3: double-tap and two-key vowel, sign, and space upgrades')
    [void]$sb.AppendLine(';;   - Rule 4: unshifted ] -> U+17C6 (nikahit) and \ -> U+17C7 (reahmuk)')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('(input-method km nida-midpoint)')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('(description "Khmer Better-NiDA Midpoint (universal / series switch, low-Shift)")')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine(('(title "{0}/")' -f [char]0x1780))
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('(map')
    [void]$sb.AppendLine('  (trans')

    [void]$sb.AppendLine('    ;; --- sequence rules (Rules 1, 2, 3) ---')
    foreach ($seq in $midSpec.sequences) {
        $kStr = ConvertTo-MimString $seq.sequence
        $vStr = ConvertTo-MimString $seq.text
        $cps  = ($seq.codepoints -join ' ')
        [void]$sb.AppendLine(('    ("{0}" "{1}") ; {2} ({3} - {4})' -f $kStr, $vStr, $cps, $seq.rule, $seq.note))
    }

    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('    ;; --- unshifted base layer (Normal) ---')
    foreach ($k in $midSpec.keys) {
        if (-not $k.scanCode) { continue }
        $cell = $k.chars.Normal
        if (-not $cell -or -not $cell.text) { continue }
        $leg = if ($k.usLegend -eq 'Space') { ' ' } else { $k.usLegend.ToLower() }
        $kStr = ConvertTo-MimString $leg
        $vStr = ConvertTo-MimString $cell.text
        $cps  = ($cell.codepoints -join ' ')
        [void]$sb.AppendLine(('    ("{0}" "{1}") ; {2}' -f $kStr, $vStr, $cps))
    }

    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('    ;; --- shifted layer (Shift fallback + rollover-safe Shift+J) ---')
    $shiftSymbolMap = @{
        '1'='!'; '2'='@'; '3'='#'; '4'='$'; '5'='%'
        '6'='^'; '7'='&'; '8'='*'; '9'='('; '0'=')'
        '-'='_'; '='='+'; '['='{'; ']'='}'; '\'='|'
        ';'=':'; "'"='"'; ','='<'; '.'='>'; '/'='?'
        '`'='~'
    }
    foreach ($k in $midSpec.keys) {
        if (-not $k.scanCode) { continue }
        $cell = $k.chars.Shift
        if (-not $cell -or -not $cell.text) { continue }
        $leg = $k.usLegend
        if ($leg -eq 'Space') {
            $vStr = ConvertTo-MimString $cell.text
            $cps  = ($cell.codepoints -join ' ')
            [void]$sb.AppendLine(('    ((S-\ ) "{0}") ; {1}' -f $vStr, $cps))
            continue
        }
        $shKey = if ($leg -cmatch '^[A-Z]$') { $leg } elseif ($shiftSymbolMap.ContainsKey($leg)) { $shiftSymbolMap[$leg] } else { $null }
        if ($shKey) {
            $kStr = ConvertTo-MimString $shKey
            $vStr = ConvertTo-MimString $cell.text
            $cps  = ($cell.codepoints -join ' ')
            [void]$sb.AppendLine(('    ("{0}" "{1}") ; Shift+{2} -> {3}' -f $kStr, $vStr, $leg, $cps))
        }
    }

    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('    ;; --- AltGr layer (G- modifier in m17n) ---')
    foreach ($k in $midSpec.keys) {
        if (-not $k.scanCode) { continue }
        $cell = $k.chars.AltGr
        if (-not $cell -or -not $cell.text) { continue }
        $leg = if ($k.usLegend -eq 'Space') { '\ ' } else { $k.usLegend.ToLower() }
        if ($leg -eq '\') { $leg = '\\' }
        elseif ($leg -eq '"') { $leg = '\"' }
        elseif ($leg -eq ';') { $leg = '\;' }
        elseif ($leg -eq "'") { $leg = "\'" }
        elseif ($leg -eq '`') { $leg = '\`' }
        $vStr = ConvertTo-MimString $cell.text
        $cps  = ($cell.codepoints -join ' ')
        [void]$sb.AppendLine(('    ((G-{0}) "{1}") ; AltGr+{2} -> {3}' -f $leg, $vStr, $k.usLegend, $cps))
    }

    [void]$sb.AppendLine('  ))')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('(state')
    [void]$sb.AppendLine('  (init')
    [void]$sb.AppendLine('    (trans)))')
    return $sb.ToString()
}

# ---------------------------------------------------------------------------
# emitter: Windows Keyman (windows/better_nida_midpoint.kmn)
# ---------------------------------------------------------------------------
function Format-KeymanCps($cps) {
    return (($cps | ForEach-Object {
        if ($_ -is [string]) { $_ } else { 'U+{0:X4}' -f [int]$_ }
    }) -join ' ')
}

function New-MidpointKeymanFile($midSpec, $engineScript) {
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('c Khmer Better-NiDA (Midpoint) - Keyman keyboard source')
    [void]$sb.AppendLine('c Generated by scripts/build_platform_layouts.ps1 from midpoint_layout.json.')
    [void]$sb.AppendLine('c DO NOT EDIT BY HAND - edit scripts/midpoint_engine.ps1 and regenerate.')
    [void]$sb.AppendLine('c')
    [void]$sb.AppendLine('c Zero display lag: every key emits its base character immediately, and')
    [void]$sb.AppendLine('c multi-key sequences (k/, jj, j/, ii, ua, ai, double-space) replace the')
    [void]$sb.AppendLine('c already-emitted context inline on the completing keystroke.')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("store(&VERSION) '10.0'")
    [void]$sb.AppendLine("store(&NAME) 'Khmer Better-NiDA (Midpoint)'")
    [void]$sb.AppendLine("store(&COPYRIGHT) '(c) 2026 Better-NiDA Contributors'")
    [void]$sb.AppendLine("store(&KEYBOARDVERSION) '1.0'")
    [void]$sb.AppendLine("store(&TARGETS) 'windows macosx linux web'")
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('begin Unicode > use(main)')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('group(main) using keys')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('c --- contextual sequence rules (Rules 1, 2, 3) ---')

    # Dot-source the engine in a child scope helper so we can resolve prefixes.
    . $engineScript | Out-Null

    foreach ($seq in $midSpec.sequences) {
        $s = [string]$seq.sequence
        $prefix = $s.Substring(0, $s.Length - 1)
        $lastCh = [string]$s[$s.Length - 1]
        $kKey = $KeymanByLegend[$lastCh.ToUpper()]
        if (-not $kKey) { $kKey = $KeymanByLegend[$lastCh] }
        if (-not $kKey) { throw "No Keyman key identifier for '$lastCh' in sequence '$s'" }

        $prefixRes = Resolve-Sequence $prefix ($prefix.ToCharArray())
        $ctxCps = Format-KeymanCps $prefixRes.Emitted
        $outCps = ($seq.codepoints -join ' ')
        [void]$sb.AppendLine(('{0} + [{1}] > {2}   c {3} ({4}: {5})' -f $ctxCps, $kKey, $outCps, $s, $seq.rule, $seq.note))
    }

    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('c --- unshifted base layer (Normal) ---')
    foreach ($k in $midSpec.keys) {
        if (-not $k.scanCode) { continue }
        $cell = $k.chars.Normal
        if (-not $cell -or -not $cell.text) { continue }
        $kKey = $KeymanByLegend[$k.usLegend]
        if (-not $kKey) { continue }
        $outCps = ($cell.codepoints -join ' ')
        [void]$sb.AppendLine(('+ [{0}] > {1}' -f $kKey, $outCps))
    }

    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('c --- shifted layer (Shift fallback + rollover-safe Shift+J) ---')
    foreach ($k in $midSpec.keys) {
        if (-not $k.scanCode) { continue }
        $cell = $k.chars.Shift
        if (-not $cell -or -not $cell.text) { continue }
        $kKey = $KeymanByLegend[$k.usLegend]
        if (-not $kKey) { continue }
        $outCps = ($cell.codepoints -join ' ')
        [void]$sb.AppendLine(('+ [SHIFT {0}] > {1}' -f $kKey, $outCps))
    }

    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('c --- AltGr layer (Right Alt) ---')
    foreach ($k in $midSpec.keys) {
        if (-not $k.scanCode) { continue }
        $cell = $k.chars.AltGr
        if (-not $cell -or -not $cell.text) { continue }
        $kKey = $KeymanByLegend[$k.usLegend]
        if (-not $kKey) { continue }
        $outCps = ($cell.codepoints -join ' ')
        [void]$sb.AppendLine(('+ [RALT {0}] > {1}' -f $kKey, $outCps))
    }

    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('c --- Shift+AltGr layer (Rule 5 static second-series consonants) ---')
    foreach ($k in $midSpec.keys) {
        if (-not $k.scanCode) { continue }
        $cell = $k.chars.ShiftAltGr
        if (-not $cell -or -not $cell.text) { continue }
        $kKey = $KeymanByLegend[$k.usLegend]
        if (-not $kKey) { continue }
        $outCps = ($cell.codepoints -join ' ')
        [void]$sb.AppendLine(('+ [SHIFT RALT {0}] > {1}' -f $kKey, $outCps))
    }

    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('c ===========================================================================')
    [void]$sb.AppendLine('c SMART SYLLABLE REORDERING & ANTI-GLITCH NORMALIZATION')
    [void]$sb.AppendLine('c ===========================================================================')
    [void]$sb.AppendLine('store(sub_key)       [K_K] [K_X] [K_C] [K_Q] [K_D] [K_Z] [K_T] [K_F] [K_N] [K_P] [K_B] [K_M] [K_Y] [K_R] [K_L] [K_V] [K_S] [K_H] [K_G] [K_HYPHEN]')
    [void]$sb.AppendLine('store(sub_out)       U+1780 U+1782 U+1785 U+1787 U+178A U+1789 U+178F U+1791 U+1793 U+1796 U+1794 U+1798 U+1799 U+179A U+179B U+179C U+179F U+17A0 U+1784 U+17A2')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('store(sub_shift_key) [SHIFT K_K] [SHIFT K_X] [SHIFT K_C] [SHIFT K_Q] [SHIFT K_D] [SHIFT K_Z] [SHIFT K_T] [SHIFT K_F] [SHIFT K_N] [SHIFT K_P] [SHIFT K_B] [SHIFT K_L]')
    [void]$sb.AppendLine('store(sub_shift_out) U+1782 U+1783 U+1787 U+1788 U+178C U+178D U+1791 U+1792 U+178E U+1797 U+1796 U+17A1')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('store(vowel_all)     U+17B6 U+17B7 U+17B8 U+17B9 U+17BA U+17BB U+17BC U+17BD U+17BE U+17BF U+17C0 U+17C1 U+17C2 U+17C3 U+17C4 U+17C5')
    [void]$sb.AppendLine('store(pre_vowel)     U+17C1 U+17C2 U+17C3')
    [void]$sb.AppendLine('store(word_break)    U+0020 U+200B U+17D4 U+17D5 U+0028 U+00AB U+0022')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('c --- 1. Single vowel + Coeng + Subscript -> Coeng + Subscript + Vowel ---')
    [void]$sb.AppendLine('any(vowel_all) U+17D2 + any(sub_key) > U+17D2 index(sub_out, 3) index(vowel_all, 1)')
    [void]$sb.AppendLine('any(vowel_all) U+17D2 + any(sub_shift_key) > U+17D2 index(sub_shift_out, 3) index(vowel_all, 1)')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('c --- 2. Two-character vowels + Coeng + Subscript ---')
    [void]$sb.AppendLine('U+17B6 U+17C6 U+17D2 + any(sub_key) > U+17D2 index(sub_out, 4) U+17B6 U+17C6')
    [void]$sb.AppendLine('U+17B6 U+17C6 U+17D2 + any(sub_shift_key) > U+17D2 index(sub_shift_out, 4) U+17B6 U+17C6')
    [void]$sb.AppendLine('U+17C4 U+17C7 U+17D2 + any(sub_key) > U+17D2 index(sub_out, 4) U+17C4 U+17C7')
    [void]$sb.AppendLine('U+17C4 U+17C7 U+17D2 + any(sub_shift_key) > U+17D2 index(sub_shift_out, 4) U+17C4 U+17C7')
    [void]$sb.AppendLine('U+17BB U+17C7 U+17D2 + any(sub_key) > U+17D2 index(sub_out, 4) U+17BB U+17C7')
    [void]$sb.AppendLine('U+17BB U+17C7 U+17D2 + any(sub_shift_key) > U+17D2 index(sub_shift_out, 4) U+17BB U+17C7')
    [void]$sb.AppendLine('U+17C1 U+17C7 U+17D2 + any(sub_key) > U+17D2 index(sub_out, 4) U+17C1 U+17C7')
    [void]$sb.AppendLine('U+17C1 U+17C7 U+17D2 + any(sub_shift_key) > U+17D2 index(sub_shift_out, 4) U+17C1 U+17C7')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('c --- 3. Vowel + Shifter -> Shifter + Vowel ---')
    [void]$sb.AppendLine('any(vowel_all) + [K_QUOTE] > U+17C9 index(vowel_all, 1)')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('c --- 4. Pre-Base Vowel at Word Boundary -> Consonant + Pre-Base Vowel ---')
    [void]$sb.AppendLine('nul any(pre_vowel) + any(sub_key) > index(sub_out, 3) index(pre_vowel, 2)')
    [void]$sb.AppendLine('any(word_break) any(pre_vowel) + any(sub_key) > index(word_break, 1) index(sub_out, 3) index(pre_vowel, 2)')
    [void]$sb.AppendLine('nul any(pre_vowel) + any(sub_shift_key) > index(sub_shift_out, 3) index(pre_vowel, 2)')
    [void]$sb.AppendLine('any(word_break) any(pre_vowel) + any(sub_shift_key) > index(word_break, 1) index(sub_shift_out, 3) index(pre_vowel, 2)')

    return $sb.ToString()
}

# ---------------------------------------------------------------------------
# build
# ---------------------------------------------------------------------------
$nidaSpec = Get-Content (Join-Path $root 'nida_layout.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$khmrTables = Get-Content (Join-Path $root 'tables_kbdkhmr.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$midSpecPath = Join-Path $root 'midpoint_layout.json'
if (-not (Test-Path $midSpecPath)) {
    & (Join-Path $PSScriptRoot 'export_midpoint_spec.ps1') | Out-Null
}
$midSpec = Get-Content $midSpecPath -Raw -Encoding UTF8 | ConvertFrom-Json
$scanMap = Get-ScanMap

$variants = @()
if ($Variant -in @('all','both','nida')) {
    $variants += New-VariantFromSpec $nidaSpec 'Khmer NiDA' 'nida' @()
}
if ($Variant -in @('all','both','legacy')) {
    $variants += New-VariantFromTables $khmrTables 'Khmer NiDA Legacy' 'nida_legacy' $scanMap
}
if ($Variant -in @('all','midpoint')) {
    $variants += New-VariantFromSpec $midSpec 'Khmer Better-NiDA' 'nida_midpoint' @()
}

foreach ($v in $variants) {
    $src = switch ($v.Slug) {
        'nida'          { 'nida_layout.json (kbdkni.dll, KLID 00010453)' }
        'nida_legacy'   { 'tables_kbdkhmr.json (kbdkhmr.dll, KLID 00000453)' }
        'nida_midpoint' { 'midpoint_layout.json (scripts/midpoint_engine.ps1)' }
    }
    $macPath = Join-Path $OutRoot ("macos\$($v.Name).keylayout")
    New-Utf8File $macPath (New-MacKeylayout $v $src)
    $xkbPath = Join-Path $OutRoot "linux\$($v.Slug)"
    New-Utf8File $xkbPath (New-XkbFile $v $src)

    $ligCount = @($v.Keys | Where-Object { @($_.Levels | Where-Object { $_.IsLigature }).Count -gt 0 }).Count
    Write-Host ("{0,-22} macos/{1}.keylayout   linux/{2}   ({3} keys, {4} ligature keys)" -f `
        $v.Name, $v.Name, $v.Slug, $v.Keys.Count, $ligCount)
}

if ($Variant -in @('all','midpoint')) {
    $mimPath = Join-Path $OutRoot 'linux\m17n\nida-midpoint.mim'
    New-Utf8File $mimPath (New-MidpointMimFile $midSpec)
    $kmnPath = Join-Path $OutRoot 'windows\better_nida_midpoint.kmn'
    New-Utf8File $kmnPath (New-MidpointKeymanFile $midSpec (Join-Path $PSScriptRoot 'midpoint_engine.ps1'))
    Write-Host ("{0,-22} linux/m17n/nida-midpoint.mim   windows/better_nida_midpoint.kmn   ({1} sequences)" -f `
        'Khmer Better-NiDA IME', @($midSpec.sequences).Count)
}
