<#
.SYNOPSIS
    Verifies the Midpoint engine against the keystroke test matrix and measures
    the ergonomic claim against stock NiDA.

.DESCRIPTION
    Three gates:
      1. Every keystroke sequence in the matrix resolves to its expected code
         points, character for character.
      2. Midpoint is additive - every stock Shift+key chord still produces the
         stock character (except Shift+J, which Rule 2 deliberately changes),
         and every unshifted key (except ] and \) preserves its stock output.
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

# NOTE: strings here are deliberately ASCII-only. PS 5.1 mangles non-ASCII
# literals in a .ps1 and the resulting parse error is extremely confusing.
$matrix = @(
    @{ Id = 'T01';  Keys = 'pjr\-gjx';    Exp = '1796 17D2 179A 17C7 17A2 1784 17D2 1782'; Note = '1-key po (p), qo (-), ko (x), reahmuk (\) - Preah Ang' }
    @{ Id = 'T01b'; Keys = 'b/jr\g/gjk/'; Exp = '1796 17D2 179A 17C7 17A2 1784 17D2 1782'; Note = 'NiDA muscle-memory slash flips (b/, g/, k/)' }
    @{ Id = 'T02';  Keys = 'kmjpuqa';     Exp = '1780 1798 17D2 1796 17BB 1787 17B6';      Note = '1-key po (p) and co (q) (Kampuchea in 7 keys)' }
    @{ Id = 'T02b'; Keys = 'kmjb/uc/a';   Exp = '1780 1798 17D2 1796 17BB 1787 17B6';      Note = 'post-coeng flip, c-slash (Kampuchea)' }
    @{ Id = 'T03a'; Keys = 'za/';         Exp = '1789 17B6 17C6';                          Note = '1-key nyo (z) + universal a/ -> am' }
    @{ Id = 'T03b'; Keys = 'z/aa';        Exp = '1789 17C9 17B6 17C6';                     Note = 'z/ -> nyo + muusikatoan, then aa (nham)' }
    @{ Id = 'T04';  Keys = 'mi/n';        Exp = '1798 17B8 1793';                          Note = 'universal i/ -> vowel ii (and miin)' }
    @{ Id = 'T05';  Keys = 'min';         Exp = '1798 17B7 1793';                          Note = 'single tap commits cleanly' }
    @{ Id = 'T06a'; Keys = 'x/j/,';       Exp = '1781 17D2 1789 17BB 17C6';                Note = 'x/ -> kha, subscript coeng-nyo via j/ (khnhom)' }
    @{ Id = 'T06b'; Keys = 'x/j~j,';      Exp = '1781 17D2 1789 17BB 17C6';                Note = 'subscript coeng-nyo via AltGr fallback' }
    @{ Id = 'T07';  Keys = 'B+Jr\';       Exp = '1796 17D2 179A 17C7';                     Note = 'rollover-safe Shift+J emits coeng' }
    @{ Id = 'T08';  Keys = 'p//jn]pez';   Exp = '1797 17D2 1793 17C6 1796 17C1 1789';      Note = 'p// -> pho, ] -> nikahit, p -> po, z -> nyo (Phnom Penh)' }
    @{ Id = 'T09';  Keys = "bjjjcb'";     Exp = '1794 1789 17D2 1785 1794 17CB';           Note = 'jj + j + c resolves nyo + coeng + ca cleanly' }
    @{ Id = 'T10';  Keys = 'kua  k=';     Exp = '1780 17BD 0020 1780 17C3';                Note = 'ua -> vowel UA, double-space -> U+0020, = -> vowel AI' }
    @{ Id = 'T11';  Keys = 'g//,';        Exp = '17A2 17CA 17BB 17C6';                     Note = 'g/ commits qo, following / emits traysap' }
    @{ Id = 'T12';  Keys = 'fe/o/w/;/.';  Exp = '1791 17C2 17C5 17BA 17C4 17C7 17D4';      Note = '1-key to (f) + universal slash on vowels (e/, o/, w/, ;/)' }
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

$regressions = New-Object System.Collections.ArrayList
$shiftTested = 0
foreach ($k in $stock.keys) {
    $legend = $k.usLegend
    if ($legend -notmatch '^[A-Z]$') { continue }
    if ($STATIC_SHIFT.ContainsKey($legend)) { continue }   # Rule 2, intentional
    $raw = $k.chars.Shift
    if (-not $raw -or -not $raw.text) { continue }
    $shiftTested++
    $want = @($raw.text.ToCharArray() | ForEach-Object { [int]$_ })
    $res = ResolveKeys ([string]$legend)
    $got = (($res.Emitted | ForEach-Object { '{0:X4}' -f $_ }) -join ' ')
    $wantHex = (($want | ForEach-Object { '{0:X4}' -f $_ }) -join ' ')
    if ($got -ne $wantHex) { [void]$regressions.Add(("{0}: want {1} got {2}" -f $legend, $wantHex, $got)) }
}
Check ("{0} letter Shift chords preserved" -f $shiftTested) ($regressions.Count -eq 0) ($regressions -join '; ')

$normalRegressions = New-Object System.Collections.ArrayList
$normalTested = 0

# usLegend is not unique. The numpad period is also labelled '.', so 49 keys
# yield 48 legends. A legend-keyed resolver can only return one of them, and we
# keep the first, which is the main-area key carrying U+17D4/U+17D5.
$seen = @{}
$droppedIdx = @{}
$dropped = New-Object System.Collections.ArrayList
for ($ki = 0; $ki -lt $stock.keys.Count; $ki++) {
    $legend = $stock.keys[$ki].usLegend
    if ($seen.ContainsKey($legend)) {
        $raw = $stock.keys[$ki].chars.Normal
        $cps = if ($raw -and $raw.text) { ($raw.text.ToCharArray() | ForEach-Object { '{0:X4}' -f [int]$_ }) -join '+' } else { '(empty)' }
        [void]$dropped.Add(("{0} -> {1}" -f $legend, $cps))
        $droppedIdx[$ki] = $true
        continue
    }
    $seen[$legend] = $true
}

for ($ki = 0; $ki -lt $stock.keys.Count; $ki++) {
    if ($droppedIdx.ContainsKey($ki)) { continue }
    $k = $stock.keys[$ki]
    $legend = $k.usLegend
    $chars = (Legend-To-Chars $legend).ToLower()
    if ($chars.Length -ne 1) { continue }
    if ($STATIC_NORMAL.ContainsKey($chars)) { continue }
    $raw = $k.chars.Normal
    if (-not $raw -or -not $raw.text) { continue }
    $normalTested++
    $want = @($raw.text.ToCharArray() | ForEach-Object { [int]$_ })
    $res = ResolveKeys $chars
    $got = (($res.Emitted | ForEach-Object { '{0:X4}' -f $_ }) -join ' ')
    $wantHex = (($want | ForEach-Object { '{0:X4}' -f $_ }) -join ' ')
    if ($got -ne $wantHex) { [void]$normalRegressions.Add(("{0}: want {1} got {2}" -f $legend, $wantHex, $got)) }
}
Check ("{0} unshifted keys preserved (except ] and \)" -f $normalTested) ($normalRegressions.Count -eq 0) ($normalRegressions -join '; ')
if ($dropped.Count -gt 0) {
    Write-Output ("  NOTE  {0} key(s) dropped by the duplicate-legend lookup: {1}" -f $dropped.Count, ($dropped -join ', '))
}

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

if ($Corpus) {
    & (Join-Path $PSScriptRoot 'score_midpoint.ps1') -Corpus $Corpus
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
