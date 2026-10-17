<#
.SYNOPSIS
    Single source of truth for the Khmer Better-NiDA (Midpoint) layout.

.DESCRIPTION
    Defines Midpoint as data, and provides a longest-prefix resolver that can
    simulate a keystroke string. Every platform target and every verification
    check is derived from this file, so the platforms cannot silently disagree
    with each other.

    Midpoint is split into two halves, because they have very different costs:

      STATIC subset  - plain layer remapping. No state machine, no display lag.
                       Rules 2, 4, 5. Works everywhere, including macOS.

      SEQUENCE subset - prefix-buffered rules. Rule 1 (series flip on '/') and
                       Rule 3 (double-tap vowels). Needs an input method that
                       holds output: m17n, Keyman, AutoHotkey.

    macOS gets the static subset only. Reason: Rule 3 makes every vowel key
    pending, and Rule 1 makes 21 consonant keys pending. That is 32 of 49 keys
    - 65% of the keyboard - invisible until the following keystroke. That is not
    an acceptable cost for a layout whose purpose is fluid typing. macOS
    .keylayout also has no backspace-and-re-emit primitive, so a retro-replace
    is impossible there regardless.

    Static layering recovers most of the benefit instead: the 13 second-series
    consonants move to Shift+AltGr, which stock NiDA leaves entirely unused
    (0 of 49 keys), so nothing is displaced.

.NOTES
    ASCII-only by design; see scripts\README.md. Khmer is written as hex.

.EXAMPLE
    .\midpoint_engine.ps1 -Resolve 'b/jr\g/gjk/'
#>
[CmdletBinding()]
param(
    # Simulate a keystroke string and print the resulting code points.
    [string]$Resolve,
    # Emit the static layer tables instead of simulating.
    [switch]$ShowLayers,
    [string]$Spec
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

if (-not $Spec) { $Spec = Join-Path (Split-Path -Parent $PSScriptRoot) 'nida_layout.json' }

# --- code point constants ----------------------------------------------------

$ZWSP = 0x200B
# Sonorant shifter (muusikatoan) and traysap, used by the series-flip outputs.
$SHIFTER_MUUSIKATOAN = 0x17C9
$SHIFTER_TRAYSAP     = 0x17CA

# --- load stock NiDA ---------------------------------------------------------

$stock = Get-Content $Spec -Raw -Encoding UTF8 | ConvertFrom-Json

# usLegend is NOT unique: 49 keys yield only 48 distinct legends, because the
# numeric-keypad period is also labelled '.'. Collapsing them loses a character -
# the main keyboard period carries U+17D4/U+17D5, the numpad one carries an
# ASCII comma and period.
#
# So store every candidate per legend and let Get-Stock take the first one that
# actually has output for the requested state. First wins, and the main-area key
# is listed first, which keeps the Khmer period and drops the numpad duplicate.
$stockByKey = @{}
foreach ($k in $stock.keys) {
    $legend = $k.usLegend
    if (-not $stockByKey.ContainsKey($legend)) { $stockByKey[$legend] = New-Object System.Collections.ArrayList }
    [void]$stockByKey[$legend].Add($k)
}

function Get-Stock($key, $state) {
    # The spacebar's legend is 'Space', but a resolver works in characters and
    # hands us ' '. Normalise here so every caller is covered.
    $legend = if ($key -eq ' ') { 'Space' } else { $key }
    if (-not $stockByKey.ContainsKey($legend)) { return $null }
    foreach ($k in $stockByKey[$legend]) {
        $cell = $k.chars.$state
        if (-not $cell -or -not $cell.text) { continue }
        return ,@($cell.text.ToCharArray() | ForEach-Object { [int]$_ })
    }
    return $null
}

# --- Midpoint static overrides ----------------------------------------------
#
# Rule 4: niakahit and reahmuk are extremely common word-final marks. Stock NiDA
# puts both behind Shift (Shift+M, Shift+H). Move them to unshifted ] and \ and
# push the two rare independent vowels down to AltGr, where every other
# independent vowel in NiDA already lives.

$STATIC_NORMAL = @{ ']' = @(0x17C6); '\' = @(0x17C7) }   # was U+17AA / U+17AE
$STATIC_SHIFT  = @{ 'J' = @(0x17D2) }                    # was U+1789
$STATIC_ALTGR  = @{ ']' = @(0x17AA); '\' = @(0x17AE); 'J' = @(0x1789) }

# How the subscript coeng+nyo (U+17D2 U+1789) is typed, as in the common word
# for "I". See the note on 'j' below for why neither 'jj' nor 'j/' is used.
$SCRATCH_SUBSCRIPT = 'j~j'

# Rule 5 / macOS substitution for Rule 1: second-series consonants on Shift+AltGr.
# Stock NiDA leaves this level completely empty, so this displaces nothing.
$SECOND_SERIES = [ordered]@{
    'k' = 0x1782; 'x' = 0x1783; 'c' = 0x1787; 'q' = 0x1788
    'd' = 0x178C; 'z' = 0x178D; 't' = 0x1791; 'f' = 0x1792
    'b' = 0x1796; 'p' = 0x1797; 'n' = 0x178E; 'l' = 0x17A1
    'g' = 0x17A2
}

# --- Midpoint sequence rules -------------------------------------------------

function New-Rule($seq, $out, $rule, $note) {
    [PSCustomObject]@{ Seq = $seq; Out = @($out); Rule = $rule; Note = $note }
}

$rules = New-Object System.Collections.ArrayList

# Rule 1 - universal series flip. '/' replaces the preceding base consonant.
# NOTE: for m, y, r, v the output is base+shifted, NOT stock's Shift character.
# Stock Shift+m is U+17C6 (niakahit) and Shift+v is a ligature, so the flip is
# genuinely different output rather than a Shift chord replacement.
$flipPlosive = [ordered]@{
    'k' = 0x1782; 'x' = 0x1783; 'c' = 0x1787; 'q' = 0x1788
    'd' = 0x178C; 'z' = 0x178D; 't' = 0x1791; 'f' = 0x1792
    'b' = 0x1796; 'p' = 0x1797
}
foreach ($key in $flipPlosive.Keys) {
    [void]$rules.Add((New-Rule "$key/" @($flipPlosive[$key]) 'Rule 1' 'plosive 1st -> 2nd series'))
}
foreach ($key in @('n','l','g')) {
    [void]$rules.Add((New-Rule "$key/" @($SECOND_SERIES[$key]) 'Rule 1' 'nasal/lateral/velar flip'))
}
foreach ($key in @('m','y','r','v')) {
    $base = (Get-Stock $key 'Normal')
    [void]$rules.Add((New-Rule "$key/" @($base[0], $SHIFTER_MUUSIKATOAN) 'Rule 1' 'sonorant + muusikatoan'))
}
[void]$rules.Add((New-Rule 's/' @(0x179F, $SHIFTER_TRAYSAP)     'Rule 1' 'fricative + traysap'))
[void]$rules.Add((New-Rule 'h/' @(0x17A0, $SHIFTER_TRAYSAP)     'Rule 1' 'fricative + traysap'))

# Rule 2 - rollover-safe coeng.
#
# Deliberately NOT defined, having been tested and rejected:
#
#   jj  -> U+1789   Breaks every coeng cluster whose subscript is a flipped
#                   consonant. 'kmjb/uc/a' (the word for "Cambodia") needs
#                   coeng then b-slash; with jj present the coeng stays pending
#                   and swallows the slash. Verified failing.
#   j/  -> coeng+nyo  Same collision, and worse: every post-coeng flip in the
#                   language dies with it.
#   jjj -> coeng+nyo  Incoherent in a left-to-right resolver. Once 'jj' has
#                   committed U+1789, a third j yields nyo+coeng, not
#                   coeng+nyo. Only works under m17n prefix semantics, so
#                   macOS and Linux would disagree.
#
# Instead: j gives coeng, Shift+J also gives coeng (so holding Shift through a
# cluster can never produce a stray nyo), and AltGr+J gives nyo. The subscript
# coeng+nyo is therefore 'j' then AltGr+J - two keys, no Shift, no collision.
# This keeps 'j' out of the pending set entirely, which also removes one of the
# keys whose lag motivated the macOS decision.

# Rule 3 - additive double-tap upgrades. Single taps keep stock output, and
# Shift+Key keeps working, so these are purely additive.
$doubleTap = [ordered]@{
    'i' = @(0x17B8); 'u' = @(0x17BC); 'e' = @(0x17C2); 'w' = @(0x17BA)
    'o' = @(0x17C5); '[' = @(0x17BF); '.' = @(0x17D5)
    'a' = @(0x17B6, 0x17C6); ';' = @(0x17C4, 0x17C7)
    "'" = @(0x17C9);            ',' = @(0x17BB, 0x17C7)
}
foreach ($key in $doubleTap.Keys) {
    [void]$rules.Add((New-Rule ($key + $key) $doubleTap[$key] 'Rule 3' 'double-tap upgrade'))
}
[void]$rules.Add((New-Rule 'ea' @(0x17C4) 'Rule 3' 'e then a'))
[void]$rules.Add((New-Rule 'ei' @(0x17BE) 'Rule 3' 'e then i'))

# Keys that become PENDING under the sequence subset, i.e. they emit nothing
# until the next keystroke resolves them.
$pendingKeys = @{}
foreach ($r in $rules) {
    if ($r.Seq.Length -ge 2) { $pendingKeys[$r.Seq[0]] = $true }
}
# Single-key j is pending only because 'j' can begin 'jj' or 'j/'.
$pendingKeys['j'] = $true

# --- static layer resolution (used as the sequence fallback) -----------------

function Get-Static($key, $shifted) {
    if ($shifted) {
        if ($STATIC_SHIFT.ContainsKey($key)) { return ,@($STATIC_SHIFT[$key]) }
        return Get-Stock $key 'Shift'
    }
    if ($STATIC_NORMAL.ContainsKey($key)) { return ,@($STATIC_NORMAL[$key]) }
    return Get-Stock $key 'Normal'
}

# --- longest-prefix resolver -------------------------------------------------
#
# Emits nothing while a prefix could still grow, commits on exact match, and on
# a dead end backtracks one character at a time. This is the same semantics m17n
# and Keyman use, so a sequence generated from here means the same thing on
# every platform that supports prefix buffering.

# These three are deliberately plain, script-scope functions that take and
# return data explicitly. An earlier version nested them inside the resolver and
# relied on closure captures, which silently returned nothing under PS 5.1 -
# Get-Stock answered correctly when called directly and empty when called from
# the nested scope. No closures, no surprises.

function Add-Output($list, $out) {
    if ($out) { foreach ($cp in $out) { [void]$list.Add([int]$cp) } }
}

function Get-ExactRule([string]$buf) {
    foreach ($r in $rules) {
        if ($r.Seq -ceq $buf) { return $r }
    }
    return $null
}

function Test-PendingPrefix([string]$buf) {
    if (-not $buf) { return $false }
    foreach ($r in $rules) {
        if ($r.Seq.Length -gt $buf.Length -and $r.Seq.StartsWith($buf, [StringComparison]::Ordinal)) { return $true }
    }
    return $false
}

# Commit a pending buffer as individual keys, left to right.
#
# Two things this must get right, both of which were bugs first:
#   - order. Emitting right to left, or deferring the remainder, produces text
#     whose characters appear before the ones they should follow.
#   - modifier state. The Shift path goes through Get-Static, not Get-Stock, so
#     Midpoint's own Shift overrides (Shift+J -> coeng) are honoured.
#
# The lists are passed in rather than captured, because a nested function
# relying on closure silently returned nothing under PS 5.1.
function Add-Commit($emitted, $steps, [string]$buf) {
    foreach ($raw in $buf.ToCharArray()) {
        # [string] cast is required: a [char] does not match a [string] key in a
        # .NET hashtable, so every lookup below silently returned null.
        $ch = [string]$raw
        $sh = ($ch -cmatch '^[A-Z]$')
        $one = Get-Static $ch.ToLower() $sh
        Add-Output $emitted $one
        [void]$steps.Add([PSCustomObject]@{ Keys = $ch; Shift = $sh; Out = $one; Rule = 'commit' })
    }
}

function Resolve-Sequence([string]$keys, $keyStream) {
    $emitted = New-Object System.Collections.ArrayList
    $steps   = New-Object System.Collections.ArrayList

    # A token is a plain character, an uppercase character (that letter with
    # Shift), or '~x' (AltGr + x). '+' is a readability separator and is ignored.
    $tokens = @()
    $i = 0
    while ($i -lt $keyStream.Length) {
        # Cast once: [char] has no string methods in PS 5.1, so ToLower() on a
        # char throws. Everything below works on [string].
        $ch = [string]$keyStream[$i]
        if ($ch -eq '~') {
            $nxt = [string]$keyStream[$i + 1]
            $tokens += [PSCustomObject]@{ Raw = $nxt; Key = $nxt.ToLower(); Shift = $false; Alt = $true }
            $i += 2
        }
        elseif ($ch -eq '+') { $i++ }
        else {
            # Raw keeps the original case. The pending buffer must retain it or
            # the Shift flag is lost: storing lowercase made 'B' commit as an
            # unshifted b, which silently downgraded every Shift chord.
            $tokens += [PSCustomObject]@{
                Raw = $ch
                Key = $ch.ToLower()
                Shift = ($ch -cmatch '^[A-Z]$')
                Alt = $false
            }
            $i++
        }
    }

    $pending = ''

    foreach ($tok in $tokens) {
        # AltGr chords are static and never participate in sequences.
        if ($tok.Alt) {
            # Any pending sequence must commit first. Emitting the chord while a
            # sequence is still buffered puts its character before the ones it
            # follows, which silently reorders the word.
            if ($pending.Length -gt 0) { Add-Commit $emitted $steps $pending; $pending = '' }
            $alt = $null
            if ($STATIC_ALTGR.ContainsKey($tok.Key)) { $alt = $STATIC_ALTGR[$tok.Key] }
            else { $alt = Get-Stock $tok.Key 'AltGr' }
            Add-Output $emitted $alt
            [void]$steps.Add([PSCustomObject]@{ Keys = '~' + $tok.Raw; Shift = $false; Out = $alt; Rule = 'altgr' })
            continue
        }

        $trial = $pending + $tok.Raw

        $exact = Get-ExactRule $trial.ToLower()
        if ($exact) {
            Add-Output $emitted $exact.Out
            [void]$steps.Add([PSCustomObject]@{ Keys = $trial; Shift = $tok.Shift; Out = $exact.Out; Rule = $exact.Rule })
            $pending = ''
            continue
        }

        if (Test-PendingPrefix $trial.ToLower()) { $pending = $trial; continue }

        # Dead end. Commit whatever was pending, in order, then give this key a
        # fresh chance to start its own sequence. Committing the buffer first is
        # what preserves ordering; skipping straight to the new key is what
        # previously inverted characters against the ones they should follow.
        if ($pending.Length -gt 0) { Add-Commit $emitted $steps $pending; $pending = '' }

        $exact = Get-ExactRule $tok.Key
        if ($exact) {
            Add-Output $emitted $exact.Out
            [void]$steps.Add([PSCustomObject]@{ Keys = $tok.Raw; Shift = $tok.Shift; Out = $exact.Out; Rule = $exact.Rule })
            continue
        }
        if (Test-PendingPrefix $tok.Key) { $pending = $tok.Raw; continue }

        $one = Get-Static $tok.Key $tok.Shift
        Add-Output $emitted $one
        [void]$steps.Add([PSCustomObject]@{ Keys = $tok.Raw; Shift = $tok.Shift; Out = $one; Rule = 'single' })
    }

    if ($pending.Length -gt 0) { Add-Commit $emitted $steps $pending }

    return [PSCustomObject]@{ Emitted = $emitted; Steps = $steps }
}

# --- entry points ------------------------------------------------------------

function Get-MidpointRules { , @($rules | Sort-Object { -$_.Seq.Length } | ForEach-Object { $_.Seq }) }
function Get-PendingKeys   { @($pendingKeys.Keys | Sort-Object) }

if ($ShowLayers) {
    Write-Output "=== Midpoint STATIC layers (usable on every platform, incl. macOS) ==="
    Write-Output ""
    Write-Output "Normal overrides (Rule 4):"
    foreach ($k in $STATIC_NORMAL.Keys) {
        "   {0,-3} -> U+{1:X4}   (stock was U+{2:X4})" -f $k, $STATIC_NORMAL[$k][0], (Get-Stock $k 'Normal')[0]
    }
    Write-Output ""
    Write-Output "Shift overrides (Rule 2, rollover-safe coeng):"
    foreach ($k in $STATIC_SHIFT.Keys) {
        "   {0,-3} -> U+{1:X4}   (stock was U+{2:X4})" -f $k, $STATIC_SHIFT[$k][0], (Get-Stock $k 'Shift')[0]
    }
    Write-Output ""
    Write-Output "AltGr overrides:"
    foreach ($k in $STATIC_ALTGR.Keys) {
        "   {0,-3} -> U+{1:X4}" -f $k, $STATIC_ALTGR[$k][0]
    }
    Write-Output ""
    Write-Output "Shift+AltGr, second-series consonants (Rule 5 / macOS stand-in for Rule 1):"
    foreach ($k in $SECOND_SERIES.Keys) {
        "   {0,-3} -> U+{1:X4}   (stock Shift+{0} was U+{2:X4})" -f $k, $SECOND_SERIES[$k], (Get-Stock $k 'Shift')[0]
    }
    Write-Output ""
    "   pending keys under SEQUENCE rules: {0} of {1} ({2:N0}%)" -f (Get-PendingKeys).Count, $stock.keys.Count, (100 * (Get-PendingKeys).Count / $stock.keys.Count)
    return
}

if ($Resolve) {
    # Split into individual key tokens so sequences like 'jJ' stay addressable.
    $stream = $Resolve.ToCharArray()
    $res = Resolve-Sequence $Resolve $stream
    Write-Output ("keystrokes : {0}" -f $Resolve)
    Write-Output ("emitted    : {0} code points" -f $res.Emitted.Count)
    Write-Output ("  {0}" -f (($res.Emitted | ForEach-Object { '{0:X4}' -f $_ }) -join ' '))
    Write-Output ""
    Write-Output "resolution:"
    foreach ($s in $res.Steps) {
        "   {0,-4} {1,-10} -> {2}   ({3})" -f $s.Keys, $s.Rule, (($s.Out | ForEach-Object { '{0:X4}' -f $_ }) -join ' '), $(if ($s.Shift) { 'shift' } else { '-' })
    }
    return
}

return [PSCustomObject]@{
    Rules       = @($rules)
    PendingKeys = Get-PendingKeys
    SecondSeries = $SECOND_SERIES
    Static      = [PSCustomObject]@{
        Normal = $STATIC_NORMAL; Shift = $STATIC_SHIFT; AltGr = $STATIC_ALTGR
    }
}
