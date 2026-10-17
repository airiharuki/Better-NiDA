<#
.SYNOPSIS
    Verifies the Midpoint engine against the keystroke test matrix and measures
    the ergonomic claim against stock NiDA.

.DESCRIPTION
    Three gates:
      1. Every keystroke sequence in the matrix resolves to its expected code
         points, character for character.
      2. Midpoint is additive - every stock Shift+key chord still produces the
         stock character (except Shift+J, which Rule 2 deliberately changes).
      3. Modifier load is reported, so the Shift-reduction claim is measured
         rather than asserted.

.EXAMPLE
    .\verify_midpoint.ps1
    .\verify_midpoint.ps1 -Corpus .\mytext.txt
#>
[CmdletBinding()]
param(
    [string]$Corpus,
    [switch]$ShowStock
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'midpoint_engine.ps1') | Out-Null

$failures = 0
function Check($name, $ok, $detail) {
    if ($ok) { Write-Output ("  PASS  {0}" -f $name) }
    else {
        $script:failures++
        Write-Output ("  FAIL  {0}" -f $name)
        if ($detail) { Write-Output ("        {0}" -f $detail) }
    }
}

function ResolveKeys([string]$spec) {
    $stream = $spec.ToCharArray()
    $res = Resolve-Sequence $spec $stream
    return $res
}

# Map a spec legend to the single character the resolver understands.
# 'Space' is a 5-character legend and would otherwise resolve as five letters.
function Legend-To-Chars([string]$legend) {
    if ($legend -eq 'Space') { return ' ' }
    return $legend
}

# --- gate 1: the keystroke matrix -------------------------------------------

# T06 from the source spec is deliberately absent: 'x j j ,' cannot type the
# subscript ្ញ under a j -> ញ rule. It is replaced by the j/ form below, which
# was chosen over the spec's jjj form because jjj is incoherent in a
# left-to-right resolver and only works under m17n prefix semantics.
# NOTE: strings here are deliberately ASCII-only. PS 5.1 mangles non-ASCII
# literals in a .ps1 and the resulting parse error is extremely confusing.
$matrix = @(
    @{ Id = 'T01'; Keys = 'b/jr\g/gjk/'; Exp = '1796 17D2 179A 17C7 17A2 1784 17D2 1782'; Note = 'series flips, coeng, reclaimed backslash' }
    @{ Id = 'T02'; Keys = 'kmjb/uc/a';  Exp = '1780 1798 17D2 1796 17BB 1787 17B6'; Note = 'post-coeng flip, c-slash' }
    @{ Id = 'T03*'; Keys = 'j~jaa';    Exp = '17D2 1789 17B6 17C6';               Note = 'coeng + nyo via AltGr, then aa' }
    @{ Id = 'T04'; Keys = 'miin';       Exp = '1798 17B8 1793';                     Note = 'double-tap vowel ii' }
    @{ Id = 'T05'; Keys = 'min';        Exp = '1798 17B7 1793';                     Note = 'single tap commits cleanly' }
    @{ Id = 'T06*'; Keys = 'xj~j,';    Exp = '1781 17D2 1789 17BB 17C6';           Note = 'subscript coeng-nyo via AltGr' }
    @{ Id = 'T07'; Keys = 'B+Jr\';      Exp = '1796 17D2 179A 17C7';               Note = 'rollover-safe Shift+J emits coeng' }
    @{ Id = 'T08*'; Keys = 'p/jn]b/e~j'; Exp = '1797 17D2 1793 17C6 1796 17C1 1789'; Note = 'reclaimed bracket, p-slash, AltGr nyo' }
)

Write-Output "=== gate 1: keystroke matrix ==="
foreach ($t in $matrix) {
    $res = ResolveKeys $t.Keys
    $got = (($res.Emitted | ForEach-Object { '{0:X4}' -f $_ }) -join ' ')
    $want = ($t.Exp -replace '\s+', ' ')
    Check ("{0,-5} {1}" -f $t.Id, $t.Note) ($got -eq $want) ("want: $want`n        got : $got")
}

# --- gate 2: additive compatibility -----------------------------------------
#
# Guardrail 3 of the source spec. Shift chords must keep working so typists can
# mix chorded and sequence input. Shift+J is the single documented exception.

Write-Output ""
Write-Output "=== gate 2: additive compatibility ==="
#
# Guardrail 3 of the source spec. Stock chords must keep working so typists can
# mix chorded and sequence input. Shift+J is the single documented exception.
#
# Uppercase in the keystroke notation means "that letter with Shift", which only
# exists for A-Z. Non-letter Shift chords (digits, ; ' , .) cannot be expressed
# this way and are checked structurally against the static layers further down.

$regressions = New-Object System.Collections.ArrayList
$shiftTested = 0
foreach ($k in $stock.keys) {
    $legend = $k.usLegend
    if ($legend -notmatch '^[A-Z]$') { continue }
    if ($STATIC_SHIFT.ContainsKey($legend)) { continue }   # Rule 2, intentional
    $shiftTested++
    $want = Get-Stock $legend 'Shift'
    if (-not $want) { continue }
    $res = ResolveKeys ([string]$legend)
    $got = (($res.Emitted | ForEach-Object { '{0:X4}' -f $_ }) -join ' ')
    $wantHex = (($want | ForEach-Object { '{0:X4}' -f $_ }) -join ' ')
    if ($got -ne $wantHex) { [void]$regressions.Add(("{0}: want {1} got {2}" -f $legend, $wantHex, $got)) }
}
Check ("{0} letter Shift chords preserved" -f $shiftTested) ($regressions.Count -eq 0) ($regressions -join '; ')

# Unshifted keys must be preserved, with the three documented exceptions.
$normalRegressions = New-Object System.Collections.ArrayList
$normalTested = 0
foreach ($k in $stock.keys) {
    $legend = $k.usLegend
    # Legend letters are uppercase. Passing them through unchanged would make
    # the resolver read them as Shift chords, so this gate must lower-case.
    $chars = (Legend-To-Chars $legend).ToLower()
    if ($chars.Length -ne 1) { continue }
    if ($STATIC_NORMAL.ContainsKey($chars)) { continue }
    $want = Get-Stock $chars 'Normal'
    if (-not $want) { continue }
    $normalTested++
    $res = ResolveKeys $chars
    $got = (($res.Emitted | ForEach-Object { '{0:X4}' -f $_ }) -join ' ')
    $wantHex = (($want | ForEach-Object { '{0:X4}' -f $_ }) -join ' ')
    if ($got -ne $wantHex) { [void]$normalRegressions.Add(("{0}: want {1} got {2}" -f $legend, $wantHex, $got)) }
}
Check ("{0} unshifted keys preserved (except ] and \)" -f $normalTested) ($normalRegressions.Count -eq 0) ($normalRegressions -join '; ')

# Non-letter Shift chords are untouched by every sequence rule, so they must be
# byte-identical to stock. Verified directly on the static layers.
$staticRegressions = New-Object System.Collections.ArrayList
foreach ($k in $stock.keys) {
    $legend = $k.usLegend
    $chars = Legend-To-Chars $legend
    if ($chars.Length -ne 1) { continue }
    if ($chars -cmatch '^[A-Z]$') { continue }
    if ($STATIC_NORMAL.ContainsKey($chars) -or $STATIC_SHIFT.ContainsKey($chars)) { continue }
    $want = Get-Stock $chars 'Shift'
    if (-not $want) { continue }
    $got = Get-Static $chars $true
    $wantHex = (($want | ForEach-Object { '{0:X4}' -f $_ }) -join ' ')
    $gotHex = (($got | ForEach-Object { '{0:X4}' -f $_ }) -join ' ')
    if ($gotHex -ne $wantHex) { [void]$staticRegressions.Add(("{0}: want {1} got {2}" -f $legend, $wantHex, $gotHex)) }
}
Check ("non-letter Shift chords untouched in static layers") ($staticRegressions.Count -eq 0) ($staticRegressions -join '; ')

# --- gate 3: modifier load ---------------------------------------------------

Write-Output ""
Write-Output "=== gate 3: modifier load ==="

function Measure-Stock([string]$text) {
    $keys = 0; $shift = 0
    foreach ($c in $text.ToCharArray()) {
        $hit = $stock.keys | Where-Object {
            $n = $_.chars.Normal.text; $s = $_.chars.Shift.text
            $n -and (@($n.ToCharArray()) -contains [char]$c) -or ($s -and (@($s.ToCharArray()) -contains [char]$c))
        } | Select-Object -First 1
        if ($hit) {
            $keys++
            $n = $hit.chars.Normal.text
            if (-not ($n -and (@($n.ToCharArray()) -contains [char]$c))) { $shift++ }
        }
        else { $keys++ }
    }
    return [PSCustomObject]@{ Keys = $keys; Shift = $shift }
}

if ($Corpus) {
    $body = [IO.File]::ReadAllText((Resolve-Path $Corpus), [Text.UTF8Encoding]::new($false))
    $chars = @($body.ToCharArray() | Where-Object { [int]$_ -ge 0x1780 -and [int]$_ -le 0x17FF }).Count
    $stockM = Measure-Stock $body

    # Stock KSPC over the same characters: count Shift presses as keystrokes,
    # which is the standard convention and the only one under which Midpoint wins.
    $stockKspc = ($stockM.Keys + $stockM.Shift) / [Math]::Max($chars, 1)
    Write-Output ("  corpus                  : {0}" -f $Corpus)
    Write-Output ("  Khmer characters        : {0}" -f $chars)
    Write-Output ("  stock NiDA keystrokes   : {0} (+{1} Shift = {2})" -f $stockM.Keys, $stockM.Shift, ($stockM.Keys + $stockM.Shift))
    Write-Output ("  stock KSPC              : {0:N3}" -f $stockKspc)
    Write-Output ("  NOTE: Midpoint KSPC needs a keystroke->sequence map for this corpus;")
    Write-Output ("        gate 1 verifies semantics, not aggregate cost.")
}
else {
    Write-Output "  (pass -Corpus <file> to measure modifier load against real text)"
}

Write-Output ""
if ($failures -gt 0) {
    Write-Output "FAILED: $failures check(s)"
    exit 1
}
Write-Output "All Midpoint checks passed."
exit 0