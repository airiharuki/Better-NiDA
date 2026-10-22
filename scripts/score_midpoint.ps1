<#
.SYNOPSIS
    Measures typing cost for stock NiDA and for Midpoint over the same text.

.DESCRIPTION
    The engine resolves keystrokes to characters. This inverts that: given text,
    it finds the cheapest way to type it, so the cost of a layout becomes a
    measurement rather than an assertion.

    Search is a shortest-path over character positions, not greedy. Greedy picks
    whatever matches first, which would favour a single key over an equally long
    sequence and would understate Midpoint's own benefit. Ties in total cost are
    broken towards fewer modifier presses.

    Cost model is the standard KSPC convention: every keypress counts once and
    every modifier press counts once more, so a Shift chord costs 2.

    Multi-character output is searched too. A single key that emits a two
    character ligature can cover more text per press, so it must be in the
    candidate set or the comparison is not fair to stock NiDA.

.PARAMETER Corpus
    UTF-8 text file to score. Defaults to the built-in smoke corpus.

.EXAMPLE
    .\score_midpoint.ps1
    .\score_midpoint.ps1 -Corpus .\mytext.txt
    .\score_midpoint.ps1 -Corpus .\mytext.txt -ShowTop
#>
[CmdletBinding()]
param(
    [string]$Corpus,
    [switch]$ShowTop
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'midpoint_engine.ps1') | Out-Null

# --- candidate construction --------------------------------------------------

function New-Candidate([int[]]$out, [int]$keys, [int]$shift, [int]$alt, [string]$via) {
    [PSCustomObject]@{
        Text = (-join ($out | ForEach-Object { [char]$_ }))
        Keys = $keys; Shift = $shift; Alt = $alt; Via = $via
        Cost = $keys + $shift + $alt
    }
}

# Returns, for every producible output string, the cheapest way to type it.
# When $isMidpoint is $false, builds pure stock NiDA (without Midpoint's static
# overrides). When $isMidpoint is $true, includes both Midpoint's static
# overrides and its sequence rules.
function Build-Index($isMidpoint) {
    $index = @{}

    function Consider($cand) {
        if (-not $cand.Text) { return }
        $prev = $index[$cand.Text]
        # Cheapest wins; on a tie prefer fewer modifiers, since that is what
        # Midpoint actually competes on.
        if (-not $prev -or $cand.Cost -lt $prev.Cost -or
            ($cand.Cost -eq $prev.Cost -and ($cand.Shift + $cand.Alt) -lt ($prev.Shift + $prev.Alt))) {
            $index[$cand.Text] = $cand
        }
    }

    foreach ($k in $stock.keys) {
        $legend = $k.usLegend
        # Overrides are keyed by a printable character, so Space has to be
        # mapped to ' '. Stock lookups must use the real legend, though:
        # $stockByKey is keyed 'Space', and looking up ' ' silently returns
        # nothing - which left U+200B (Space unshifted) with no candidate at
        # all and made the whole shortest path unreachable.
        $ov = if ($legend -eq 'Space') { ' ' } else { $legend.ToLower() }

        $normal = $null
        if ($isMidpoint -and $STATIC_NORMAL.ContainsKey($ov)) { $normal = $STATIC_NORMAL[$ov] }
        else { $normal = Get-Stock $legend 'Normal' }
        if ($normal) { Consider (New-Candidate $normal 1 0 0 "1") }

        $shift = $null
        if ($isMidpoint -and $STATIC_SHIFT.ContainsKey($ov)) { $shift = $STATIC_SHIFT[$ov] }
        else { $shift = Get-Stock $legend 'Shift' }
        if ($shift) { Consider (New-Candidate $shift 1 1 0 "S") }

        $alt = $null
        if ($isMidpoint -and $STATIC_ALTGR.ContainsKey($ov)) { $alt = $STATIC_ALTGR[$ov] }
        else { $alt = Get-Stock $legend 'AltGr' }
        if ($alt) { Consider (New-Candidate $alt 1 0 1 "A") }
    }

    if ($isMidpoint) {
        foreach ($r in $rules) {
            $shift = 0; $alt = 0
            foreach ($c in $r.Seq.ToCharArray()) {
                $cs = [string]$c
                if ($cs -cmatch '^[A-Z]$') { $shift++ }
                elseif ($cs -eq '~') { $alt++ }
            }
            Consider (New-Candidate ([int[]]$r.Out) $r.Seq.Length $shift $alt ("seq " + $r.Seq))
        }
    }

    return $index
}

# --- shortest-path typing ---------------------------------------------------

function Measure-Text($index, [string]$text, [hashtable]$charCost) {
    $n = $text.Length
    $INF = [int]::MaxValue
    $best = New-Object 'int[]' ($n + 1)
    $bestMod = New-Object 'int[]' ($n + 1)
    $prev = New-Object 'int[]' ($n + 1)
    $prevIdx = New-Object 'int[]' ($n + 1)
    for ($i = 0; $i -le $n; $i++) {
        $best[$i] = $INF
        $bestMod[$i] = $INF
        $prev[$i] = -1
        $prevIdx[$i] = -1
    }
    $best[0] = 0
    $bestMod[0] = 0

    $maxLen = 1
    foreach ($k in $index.Keys) { if ($k.Length -gt $maxLen) { $maxLen = $k.Length } }

    $unreachable = @{}

    for ($i = 0; $i -lt $n; $i++) {
        if ($best[$i] -eq $INF) { continue }

        $take = [Math]::Min($maxLen, $n - $i)
        $any = $false
        for ($len = 1; $len -le $take; $len++) {
            $piece = $text.Substring($i, $len)
            $cand = $index[$piece]
            if (-not $cand) { continue }
            $any = $true
            $to = $i + $len
            $cost = $best[$i] + $cand.Cost
            $mod  = $bestMod[$i] + $cand.Shift + $cand.Alt
            if ($cost -lt $best[$to] -or ($cost -eq $best[$to] -and $mod -lt $bestMod[$to])) {
                $best[$to] = $cost
                $bestMod[$to] = $mod
                $prev[$to] = $i
                $prevIdx[$to] = $len
            }
        }

        # No candidate of any length starts here, so this character cannot be
        # typed by this layout at all. Skip it at zero cost and record it.
        if (-not $any) {
            $to = $i + 1
            if ($best[$i] -lt $best[$to] -or ($best[$i] -eq $best[$to] -and $bestMod[$i] -lt $bestMod[$to])) {
                $best[$to] = $best[$i]
                $bestMod[$to] = $bestMod[$i]
                $prev[$to] = $i
                $prevIdx[$to] = 0     # 0 marks a skip, not a keystroke
            }
            $cp = [int]$text[$i]
            if (-not $unreachable.ContainsKey($cp)) { $unreachable[$cp] = 0 }
            $unreachable[$cp]++
        }
    }

    # Walk the path back and recount, so the breakdown matches the chosen route.
    $keys = 0; $shift = 0; $alt = 0; $skipped = 0
    $pos = $n
    while ($pos -gt 0 -and $prev[$pos] -ge 0) {
        $len = $prevIdx[$pos]
        if ($len -gt 0) {
            $piece = $text.Substring($prev[$pos], $len)
            $cand = $index[$piece]
            if ($cand) {
                $keys += $cand.Keys; $shift += $cand.Shift; $alt += $cand.Alt
                if ($charCost) {
                    if ($charCost.ContainsKey($piece)) { $charCost[$piece] += 1 }
                    else { $charCost[$piece] = 1 }
                }
            }
        }
        else {
            $skipped++
        }
        $pos = $prev[$pos]
    }
    $complete = ($best[$n] -ne $INF)
    $typed = $n - $skipped

    return [PSCustomObject]@{
        Complete    = $complete
        Chars       = $n
        Typed       = $typed
        Skipped     = $skipped
        Keys        = $keys; Shift = $shift; Alt = $alt
        Modifiers   = $shift + $alt
        # KSPC is per typed character. Including skipped ones would dilute the
        # ratio with characters no layout could ever produce.
        KSPC        = if ($typed -gt 0) { ($keys + $shift + $alt) / $typed } else { 0 }
        KeysPerChar = if ($typed -gt 0) { $keys / $typed } else { 0 }
        ShiftShare  = if ($keys -gt 0) { 100 * $shift / $keys } else { 0 }
        Unreachable = $unreachable
    }
}

# --- corpus -----------------------------------------------------------------

if ($Corpus) {
    if (-not (Test-Path $Corpus)) { throw "Corpus not found: $Corpus" }
    $text = [IO.File]::ReadAllText((Resolve-Path $Corpus), [Text.UTF8Encoding]::new($false))
}
else {
    $text = -join ([char]0x1780, [char]0x1798, [char]0x17D2, [char]0x1796, [char]0x17BB,
                    [char]0x1785, [char]0x17D2, [char]0x1787, [char]0x17B6, [char]0x200B,
                    [char]0x179F, [char]0x17A0, [char]0x200B, [char]0x17BB, [char]0x17C1,
                    [char]0x17D2, [char]0x1789, [char]0x200B)
    $Corpus = '(built-in smoke corpus)'
}

$text = $text -replace "`r`n", "`n" -replace "`r", "`n"
$lineBreaks = ([regex]::Matches($text, "`n")).Count
$text = ($text -replace "`n", '')
$text = $text.Trim()
if ($lineBreaks -gt 0) {
    Write-Output ("note: removed {0} line break(s) before scoring; a layout cannot type one" -f $lineBreaks)
}

# --- run both ---------------------------------------------------------------

$stockIndex  = Build-Index $false
$midIndex    = Build-Index $true

$stockM  = Measure-Text $stockIndex $text $null
$midM    = Measure-Text $midIndex   $text $null

Write-Output "corpus : $Corpus"
Write-Output "chars  : $($text.Length)"
Write-Output ""
Write-Output "Cost model: KSPC = (keypresses + modifier presses) / typeable characters."
Write-Output "A Shift chord therefore costs 2. See ROADMAP.md section 2."
Write-Output ""
Write-Output "=== side by side ==="
'{0,-22} {1,10} {2,10}' -f '', 'stock NiDA', 'Midpoint'
Write-Output ('-' * 44)
'{0,-22} {1,10} {2,10}' -f 'typeable chars',      $stockM.Typed,      $midM.Typed
'{0,-22} {1,10} {2,10}' -f 'untypable (skipped)', $stockM.Skipped,    $midM.Skipped
'{0,-22} {1,10} {2,10}' -f 'keypresses',          $stockM.Keys,       $midM.Keys
'{0,-22} {1,10:N3} {2,10:N3}' -f 'keys per char', $stockM.KeysPerChar, $midM.KeysPerChar
'{0,-22} {1,10} {2,10}' -f '  needing Shift',     $stockM.Shift,      $midM.Shift
'{0,-22} {1,10} {2,10}' -f '  needing AltGr',     $stockM.Alt,        $midM.Alt
'{0,-22} {1,10} {2,10}' -f 'total presses',       ($stockM.Keys + $stockM.Modifiers), ($midM.Keys + $midM.Modifiers)
'{0,-22} {1,10:N3} {2,10:N3}' -f 'KSPC',          $stockM.KSPC,       $midM.KSPC
'{0,-22} {1,9:N1}% {2,9:N1}%' -f 'Shift share of keys', $stockM.ShiftShare, $midM.ShiftShare
Write-Output ""

function Show-Delta($label, $a, $b, $lowerIsBetter) {
    if ($a -eq 0) { return }
    $pct = 100.0 * ($b - $a) / $a
    $good = if ($lowerIsBetter) { $pct -lt 0 } else { $pct -gt 0 }
    $sign = if ($pct -lt 0) { 'down' } else { 'up' }
    '{0,-22} {1,7:N1}% {2,4}  {3}' -f $label, [Math]::Abs($pct), $sign, $(if ($good) { 'better' } else { 'WORSE' })
}

Write-Output "=== Midpoint vs stock ==="
Show-Delta 'keypresses'    $stockM.Keys  $midM.Keys  $true
Show-Delta 'Shift presses' $stockM.Shift $midM.Shift $true
Show-Delta 'AltGr presses' $stockM.Alt   $midM.Alt   $true
Show-Delta 'KSPC'          $stockM.KSPC  $midM.KSPC  $true
Write-Output ""

if ($stockM.Unreachable.Count -gt 0 -or $midM.Unreachable.Count -gt 0) {
    Write-Output "=== characters with no keystroke ==="
    foreach ($label in @('stock NiDA', 'Midpoint')) {
        $r = if ($label -eq 'stock NiDA') { $stockM.Unreachable } else { $midM.Unreachable }
        if ($r.Count -eq 0) { "  {0,-12} none" -f $label; continue }
        "  {0,-12} {1} distinct: {2}" -f $label, $r.Count, (($r.Keys | Sort-Object | ForEach-Object { 'U+{0:X4}' -f $_ }) -join ' ')
    }
    Write-Output ""
    Write-Output "The counts below exclude untypable characters and are not comparable"
    Write-Output "to a fully-typed corpus until this is empty."
    Write-Output ""
}

if ($ShowTop) {
    $cc = @{}
    [void](Measure-Text $midIndex $text $cc)
    Write-Output "=== most frequent pieces in the Midpoint route ==="
    foreach ($p in ($cc.GetEnumerator() | Sort-Object { -$_.Value } | Select-Object -First 15)) {
        $cps = (($p.Key.ToCharArray() | ForEach-Object { '{0:X4}' -f [int]$_ }) -join ' ')
        "  {0,-14} x{1}" -f $cps, $p.Value
    }
    Write-Output ""
    Write-Output "Note: codepoints are shown because console Khmer rendering is unreliable."
}

exit 0
