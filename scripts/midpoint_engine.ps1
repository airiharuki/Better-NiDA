<#
.SYNOPSIS
    Single source of truth for the Khmer Better-NiDA (Midpoint) layout.

.DESCRIPTION
    Defines Midpoint as data, and provides a longest-prefix resolver that can
    simulate a keystroke string. Every platform target and every verification
    check is derived from this file, so the platforms cannot silently disagree
    with each other.

    Midpoint is split into two halves, because they have different host needs:

      STATIC subset   - plain layer remapping. No state machine, no display lag.
                        Rules 2 (Shift+J / AltGr+J), 4 (] and \), 5 (Shift+AltGr).
                        Works everywhere, including macOS .keylayout and Linux XKB.

      SEQUENCE subset - prefix-buffered / contextual rules:
                        Rule 1 (universal '/' series switch),
                        Rule 2 ('jj' -> nyo, 'jj/' -> nyo+muusikatoan, 'j/' -> coeng+nyo),
                        Rule 3 (double-tap and two-key vowel, sign, and space upgrades).
                        Implemented with zero display lag via contextual replacement
                        in Keyman (.kmn) and preedit maps in m17n (.mim).

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
# Bold Hybrid Rearrangement (Khmerism speed + NiDA accessibility):
#   - High-frequency 2nd-series consonants promoted to unshifted keys:
#       q -> U+1787 (co), f -> U+1791 (to), p -> U+1796 (po),
#       x -> U+1782 (ko), z -> U+1789 (nyo), - -> U+17A2 (qo)
#   - High-frequency vowel ai (U+17C3) promoted to unshifted '='
#   - High-frequency finals nikahit (U+17C6) and reahmuk (U+17C7) on ']' and '\'
#   - Displaced rare characters moved to AltGr (and reachable via '/' sequences),
#     preserving 100% of stock NiDA's character repertoire.

$STATIC_NORMAL = @{
    'q' = @(0x1787)   # was U+1786 (cho) -> promoted U+1787 (co)
    'f' = @(0x1791)   # was U+1790 (tho) -> promoted U+1791 (to)
    'p' = @(0x1796)   # was U+1795 (pho) -> promoted U+1796 (po)
    'x' = @(0x1782)   # was U+1781 (kha) -> promoted U+1782 (ko)
    'z' = @(0x1789)   # was U+178B (tha) -> promoted U+1789 (nyo)
    '-' = @(0x17A2)   # was U+17A5 (qi)  -> promoted U+17A2 (qo)
    '=' = @(0x17C3)   # was U+17B2 (qoo) -> promoted U+17C3 (vowel ai)
    ']' = @(0x17C6)   # was U+17AA (quv) -> promoted U+17C6 (nikahit)
    '\' = @(0x17C7)   # was U+17AE (lyy) -> promoted U+17C7 (reahmuk)
}
$STATIC_SHIFT  = @{ 'J' = @(0x17D2) }   # was U+1789 (Rule 2 rollover-safe coeng)
$STATIC_ALTGR  = @{
    'Q' = @(0x1786)   # displaced from Normal q (cho)
    'F' = @(0x1790)   # displaced from Normal f (tho)
    'P' = @(0x1795)   # displaced from Normal p (pho)
    'Y' = @(0x17B0)   # rescued from AltGr+P (stock AltGr+Y is empty)
    'X' = @(0x1781)   # displaced from Normal x (kha)
    'Z' = @(0x178B)   # displaced from Normal z (tha)
    '-' = @(0x17A5)   # displaced from Normal - (qi)
    'W' = @(0x00D7)   # rescued from AltGr+- (stock AltGr+W is empty)
    '=' = @(0x17B2)   # displaced from Normal = (qoo)
    'K' = @(0x17CE)   # rescued from AltGr+= (stock AltGr+K is empty)
    ']' = @(0x17AA)   # moved from Normal ]
    '\' = @(0x17AE)   # moved from Normal \
    'V' = @(0x005C)   # rescued from AltGr+\ (stock AltGr+V is empty)
    'J' = @(0x1789)   # static-layer fallback for nyo (U+1789)
    'U' = @(0x17B3)   # rescued from AltGr+] (stock AltGr+U is empty)
}

# Primary sequence for subscript coeng+nyo (U+17D2 U+1789), as in "khnhom" (I).
$SCRATCH_SUBSCRIPT = 'j/'

# Rule 5 / macOS and XKB static substitution for Rule 1: second-series
# consonants on Shift+AltGr. Stock NiDA leaves this level completely empty
# (0 of 49 keys), so nothing is displaced.
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

# Rule 1 - universal consonant series flip and aspirated progression via '/'.
# Preserves NiDA muscle memory (k/ -> ko, t/ -> to, b/ -> po, c/ -> co, g/ -> qo)
# AND lets the newly promoted unshifted keys (x, f, p, q, z) step to their
# displaced 1st-series aspirated and 2nd-series aspirated partners via '/' and '//'.
$consonantSlash = [ordered]@{
    'k/'  = @(0x1782); 'x/'  = @(0x1781); 'x//' = @(0x1783)
    'c/'  = @(0x1787); 'q/'  = @(0x1786); 'q//' = @(0x1788)
    'd/'  = @(0x178C); 'z/'  = @(0x1789, $SHIFTER_MUUSIKATOAN)
    'zz'  = @(0x178B); 'zz/' = @(0x178D)
    't/'  = @(0x1791); 'f/'  = @(0x1790); 'f//' = @(0x1792)
    'b/'  = @(0x1796); 'p/'  = @(0x1795); 'p//' = @(0x1797)
    'n/'  = @(0x178E); 'l/'  = @(0x17A1); 'g/'  = @(0x17A2)
}
foreach ($seq in $consonantSlash.Keys) {
    [void]$rules.Add((New-Rule $seq $consonantSlash[$seq] 'Rule 1' 'consonant series/aspirated flip'))
}
foreach ($key in @('m','y','r','v')) {
    $base = (Get-Stock $key 'Normal')
    [void]$rules.Add((New-Rule "$key/" @($base[0], $SHIFTER_MUUSIKATOAN) 'Rule 1' 'sonorant + muusikatoan'))
}
[void]$rules.Add((New-Rule 's/' @(0x179F, $SHIFTER_TRAYSAP)     'Rule 1' 'fricative + traysap'))
[void]$rules.Add((New-Rule 'h/' @(0x17A0, $SHIFTER_TRAYSAP)     'Rule 1' 'fricative + traysap'))

# Rule 2 - rollover-safe coeng and Shift-free / AltGr-free nyo (U+1789):
#   j       -> U+17D2 (coeng, single tap)
#   Shift+J -> U+17D2 (rollover-safe coeng during shifted clusters)
#   z / jj  -> U+1789 (standalone nyo, zero modifiers)
#   z/ / jj/-> U+1789 U+17C9 (nyo + muusikatoan, e.g. "nham" to eat)
#   j/      -> U+17D2 U+1789 (subscript coeng + nyo in 2 keys, e.g. "khnhom")
[void]$rules.Add((New-Rule 'jj'  @(0x1789)                         'Rule 2' 'double-tap j -> nyo'))
[void]$rules.Add((New-Rule 'j/'  @(0x17D2, 0x1789)                 'Rule 2' 'coeng + nyo'))

# Rule 3 - 100% universal '/' upgrades AND additive double-tap upgrades for
# every vowel, sign, number, and space on the keyboard.
$doubleTap = [ordered]@{
    'i' = @(0x17B8); 'u' = @(0x17BC); 'e' = @(0x17C2); 'w' = @(0x17BA)
    'o' = @(0x17C5); '[' = @(0x17BF); '.' = @(0x17D5)
    'a' = @(0x17B6, 0x17C6); ';' = @(0x17C4, 0x17C7)
    "'" = @(0x17C9);            ',' = @(0x17BB, 0x17C7)
    ']' = @(0x17A7);            '\' = @(0x17C8)
    'y' = @(0x17BD);            'v' = @(0x17C1, 0x17C7)
    'r' = @(0x17AC);            '`' = @(0x00BB)
    '-' = @(0x17CC);            '=' = @(0x003D)
    '/' = @(0x003F);            ' ' = @(0x0020)
}
foreach ($key in $doubleTap.Keys) {
    [void]$rules.Add((New-Rule ($key + $key) $doubleTap[$key] 'Rule 3' 'double-tap upgrade'))
}

# Universal '/' on vowels, signs, numbers, and symbols (where distinct from Rule 1):
$slashUpgrades = [ordered]@{
    'i/'  = @(0x17B8);           'u/'  = @(0x17BC)
    'e/'  = @(0x17C2);           'w/'  = @(0x17BA)
    'o/'  = @(0x17C5);           '[/'  = @(0x17BF)
    'a/'  = @(0x17B6, 0x17C6);   ';/'  = @(0x17C4, 0x17C7)
    ";//" = @(0x17D6);           "'/"  = @(0x17C9)
    "'//" = @(0x17C8);           ',/'  = @(0x17BB, 0x17C7)
    ',//' = @(0x002C);           './'  = @(0x17D5)
    './/' = @(0x002E);           ']/'  = @(0x17A7)
    ']//'= @(0x17AA);            '\/'  = @(0x17C8)
    '\//' = @(0x17AD);           '`/'  = @(0x00BB)
    ' /'  = @(0x0020);           '///' = @(0x002F)
    'rr/' = @(0x17AB);           '--/' = @(0x17A5)
    '=/'  = @(0x17B2);           '=//' = @(0x17CE)
    '1/'  = @(0x0021);           '2/'  = @(0x17D7)
    '3/'  = @(0x0022);           '3//' = @(0x17D1)
    '4/'  = @(0x17DB);           '5/'  = @(0x0025)
    '6/'  = @(0x17CD);           '6//' = @(0x17D9)
    '7/'  = @(0x17D0);           '7//' = @(0x17DA)
    '8/'  = @(0x17CF);           '9/'  = @(0x0028)
    '0/'  = @(0x0029)
}
foreach ($seq in $slashUpgrades.Keys) {
    [void]$rules.Add((New-Rule $seq $slashUpgrades[$seq] 'Rule 3' 'universal slash upgrade'))
}

# Composite two-key vowel shortcuts:
[void]$rules.Add((New-Rule 'ea' @(0x17C4) 'Rule 3' 'e then a -> au'))
[void]$rules.Add((New-Rule 'ei' @(0x17BE) 'Rule 3' 'e then i -> oe'))
[void]$rules.Add((New-Rule 'ua' @(0x17BD) 'Rule 3' 'u then a -> ua'))
[void]$rules.Add((New-Rule 'ai' @(0x17C3) 'Rule 3' 'a then i -> ai'))

# Keys that can begin a multi-key sequence under prefix buffering.
$pendingKeys = @{}
foreach ($r in $rules) {
    if ($r.Seq.Length -ge 2) { $pendingKeys[[string]$r.Seq[0]] = $true }
}

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
# Holds a prefix while it can still grow into a longer rule, commits immediately
# when a matched rule cannot grow further, and on a dead end commits the buffer
# left-to-right using longest-exact-rule matching before falling back to single
# static keys.

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

# Commit a pending buffer left to right, preferring longest exact sequence rules
# (e.g. 'jj' -> U+1789 when 'jj' was held waiting for a possible '/') before
# falling back to single-key static output.
function Add-Commit($emitted, $steps, [string]$buf) {
    $pos = 0
    while ($pos -lt $buf.Length) {
        $matched = $false
        for ($len = $buf.Length - $pos; $len -ge 2; $len--) {
            $sub = $buf.Substring($pos, $len)
            if ($sub -cmatch '[A-Z]') { continue }
            $ex = Get-ExactRule $sub
            if ($ex) {
                Add-Output $emitted $ex.Out
                [void]$steps.Add([PSCustomObject]@{ Keys = $sub; Shift = $false; Out = $ex.Out; Rule = $ex.Rule })
                $pos += $len
                $matched = $true
                break
            }
        }
        if (-not $matched) {
            $ch = [string]$buf[$pos]
            $sh = ($ch -cmatch '^[A-Z]')
            $one = Get-Static $ch.ToLower() $sh
            Add-Output $emitted $one
            [void]$steps.Add([PSCustomObject]@{ Keys = $ch; Shift = $sh; Out = $one; Rule = 'commit' })
            $pos++
        }
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
        $ch = [string]$keyStream[$i]
        if ($ch -eq '~') {
            $nxt = [string]$keyStream[$i + 1]
            $tokens += [PSCustomObject]@{ Raw = $nxt; Key = $nxt.ToLower(); Shift = $false; Alt = $true }
            $i += 2
        }
        elseif ($ch -eq '+') { $i++ }
        else {
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
            if ($pending.Length -gt 0) { Add-Commit $emitted $steps $pending; $pending = '' }
            $alt = $null
            if ($STATIC_ALTGR.ContainsKey($tok.Key)) { $alt = $STATIC_ALTGR[$tok.Key] }
            else { $alt = Get-Stock $tok.Key 'AltGr' }
            Add-Output $emitted $alt
            [void]$steps.Add([PSCustomObject]@{ Keys = '~' + $tok.Raw; Shift = $false; Out = $alt; Rule = 'altgr' })
            continue
        }

        # Only unshifted keys participate in sequence rules; shifted keys must
        # commit any pending buffer and resolve via Get-Static so Guardrail 3
        # (100% additive Shift chords) is never intercepted by a lowercase rule.
        if (-not $tok.Shift) {
            $trial = $pending + $tok.Raw
            if (Test-PendingPrefix $trial) { $pending = $trial; continue }
            $exact = Get-ExactRule $trial
            if ($exact) {
                Add-Output $emitted $exact.Out
                [void]$steps.Add([PSCustomObject]@{ Keys = $trial; Shift = $false; Out = $exact.Out; Rule = $exact.Rule })
                $pending = ''
                continue
            }
        }

        # Dead end or Shift chord: commit whatever was pending, in order, then
        # give this token a fresh chance to start its own sequence.
        if ($pending.Length -gt 0) { Add-Commit $emitted $steps $pending; $pending = '' }

        if (-not $tok.Shift) {
            if (Test-PendingPrefix $tok.Key) { $pending = $tok.Raw; continue }
            $exact = Get-ExactRule $tok.Key
            if ($exact) {
                Add-Output $emitted $exact.Out
                [void]$steps.Add([PSCustomObject]@{ Keys = $tok.Raw; Shift = $false; Out = $exact.Out; Rule = $exact.Rule })
                continue
            }
        }

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
    Rules        = @($rules)
    PendingKeys  = Get-PendingKeys
    SecondSeries = $SECOND_SERIES
    Static       = [PSCustomObject]@{
        Normal = $STATIC_NORMAL; Shift = $STATIC_SHIFT; AltGr = $STATIC_ALTGR
    }
}
