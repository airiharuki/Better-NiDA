<#
.SYNOPSIS
    Scores a keyboard layout spec against a text corpus.

.DESCRIPTION
    Walks a corpus and reports what the layout actually costs to type:
    keystrokes, modifier load, how much the ligature table saves, and which
    characters the layout cannot produce at all.

    Matching is greedy longest-match, so a two-character ligature entry is
    preferred over two single-character entries when one is available.

.PARAMETER Corpus
    Path to a UTF-8 text file. Any bytes are counted as one character each,
    so run this on plain text, not markup.

.PARAMETER Spec
    Layout spec to score. Defaults to nida_layout.json in the repo root.

.PARAMETER Top
    How many rows to show in the per-character table.

.PARAMETER Strict
    Exit 1 if the corpus contains any character the layout cannot produce.
    Makes the scorer usable as a CI gate.

.EXAMPLE
    .\score_layout.ps1 -Corpus .\mytext.txt
    .\score_layout.ps1 -Corpus .\mytext.txt -Spec .\some_other_layout.json
    .\score_layout.ps1 -Corpus .\mytext.txt -Strict
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Corpus,
    [string]$Spec,
    [int]$Top = 25,
    [switch]$Strict
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

# ASCII-only by design: see scripts\README.md. Non-ASCII literals here get
# mangled by the PowerShell 5.1 parser depending on how the file was saved.

$ZWSP = [char]0x200B
$SPACE = [char]0x0020

if (-not $Spec) {
    $Spec = Join-Path (Split-Path -Parent $PSScriptRoot) 'nida_layout.json'
}
if (-not (Test-Path $Spec))   { throw "Spec not found: $Spec" }
if (-not (Test-Path $Corpus)) { throw "Corpus not found: $Corpus" }

# --- load spec ---------------------------------------------------------------

$layout = Get-Content $Spec -Raw -Encoding UTF8 | ConvertFrom-Json
$states = @('Normal', 'Shift', 'Control', 'AltGr', 'ShiftAltGr')

# --- build the reverse index -------------------------------------------------
#
# text -> { state, key }. Greedy matching later means we only need the longest
# producible string per state, but we index everything and let the matcher
# decide, so a future spec with 3-character entries needs no change here.

$index = @{}          # produced text -> @{ State = 'Shift'; Key = 'A' }
$maxLen = 1

foreach ($k in $layout.keys) {
    foreach ($s in $states) {
        $cell = $k.chars.$s
        if (-not $cell) { continue }
        $text = $cell.text
        if (-not $text) { continue }

        $len = $text.Length
        if ($len -gt $maxLen) { $maxLen = $len }

        $existing = $index[$text]
        if ($existing) {
            # A character reachable two ways: prefer the cheaper modifier so
            # the reported load reflects what a typist would actually use.
            $cost = @{ 'Normal' = 0; 'Shift' = 1; 'AltGr' = 2; 'ShiftAltGr' = 3; 'Control' = 4 }
            if ($cost[$s] -lt $cost[$existing.State]) {
                $index[$text] = @{ State = $s; Key = $k.usLegend }
            }
        }
        else {
            $index[$text] = @{ State = $s; Key = $k.usLegend }
        }
    }
}

# --- read corpus -------------------------------------------------------------

$text = [IO.File]::ReadAllText((Resolve-Path $Corpus), [Text.UTF8Encoding]::new($false))

# --- walk it -----------------------------------------------------------------

$state = @{
    keys        = 0
    chars       = 0
    byState     = @{}
    perChar     = @{}     # codepoint -> keystrokes spent producing it
    untypeable  = @{}     # codepoint -> occurrences
    ligatures   = 0
    ligSaved    = 0       # keystrokes saved by ligature entries
    unknown     = New-Object 'System.Collections.Generic.List[string]'
}

$states | ForEach-Object { $state.byState[$_] = 0 }

$i = 0
while ($i -lt $text.Length) {
    # Greedy longest-match over the ligature-capable index.
    $hit = $null
    $hitLen = 0
    $take = [Math]::Min($maxLen, $text.Length - $i)
    for ($len = $take; $len -ge 1; $len--) {
        $candidate = $text.Substring($i, $len)
        if ($index.ContainsKey($candidate)) {
            $hit = $candidate
            $hitLen = $len
            break
        }
    }

    if ($null -eq $hit) {
        $cp = [int]$text[$i]
        if ($state.untypeable.ContainsKey($cp)) {
            $state.untypeable[$cp]++
        }
        else {
            $state.untypeable[$cp] = 1
        }
        if ($state.unknown.Count -lt 40) {
            $state.unknown.Add(('U+{0:X4}' -f $cp))
        }
        $i++
        continue
    }

    $entry = $index[$hit]
    $state.keys++
    $state.byState[$entry.State]++

    if ($hitLen -gt 1) {
        $state.ligatures++
        $state.ligSaved += ($hitLen - 1)
    }

    for ($c = 0; $c -lt $hitLen; $c++) {
        $cp = [int]$hit[$c]
        if ($state.perChar.ContainsKey($cp)) { $state.perChar[$cp]++ }
        else { $state.perChar[$cp] = 1 }
        $state.chars++
    }

    $i += $hitLen
}

# --- report ------------------------------------------------------------------

$total = $text.Length

Write-Output "corpus : $Corpus"
Write-Output "spec   : $Spec"
Write-Output "bytes  : $total characters (including any unmatchable ones)"
Write-Output ""

Write-Output "=== keystroke load ==="
"  characters in corpus        : {0,7}" -f $total
"  characters matched          : {0,7}" -f $state.chars
"  keystrokes required         : {0,7}" -f $state.keys
if ($state.chars -gt 0) {
    "  keystrokes per character   : {0,7:N3}" -f ($state.keys / $state.chars)
}
"  characters NOT typeable     : {0,7}" -f (($state.untypeable.Values | Measure-Object -Sum).Sum)
Write-Output ""

Write-Output "=== modifier load ==="
foreach ($s in $states) {
    $n = $state.byState[$s]
    if ($state.keys -gt 0) {
        "  {0,-12} {1,7} keystrokes  {2,6:N1}%" -f $s, $n, (100 * $n / $state.keys)
    }
    else {
        "  {0,-12} {1,7}" -f $s, 0
    }
}
Write-Output ""

Write-Output "=== ligature contribution ==="
"  ligature keypresses         : {0,7}" -f $state.ligatures
"  characters they emitted     : {0,7}" -f ($state.ligatures + $state.ligSaved)
"  keystrokes saved            : {0,7}" -f $state.ligSaved
if ($state.chars -gt 0) {
    "  saving vs one char per key : {2,6:N1}% of all characters" -f 0, 0, (100 * $state.ligSaved / $state.chars)
}
Write-Output ""

if ($state.untypeable.Count -gt 0) {
    Write-Output "=== characters this layout cannot type ==="
    foreach ($cp in ($state.untypeable.Keys | Sort-Object)) {
        "  U+{0:X4}  {1,6} occurrence(s)" -f $cp, $state.untypeable[$cp]
    }
    Write-Output ""
}

Write-Output "=== top characters by count (matched only) ==="
Write-Output "  codepoints are used rather than glyphs: console Khmer rendering is unreliable."
foreach ($cp in ($state.perChar.Keys | Sort-Object { -$state.perChar[$_] } | Select-Object -First $Top)) {
    "  U+{0:X4}    {1,7}" -f $cp, $state.perChar[$cp]
}

$untypeableTotal = 0
if ($state.untypeable.Count -gt 0) {
    $untypeableTotal = ($state.untypeable.Values | Measure-Object -Sum).Sum
}

if ($Strict -and $untypeableTotal -gt 0) {
    Write-Output ""
    Write-Output "-Strict: $untypeableTotal unmatchable character(s); exiting 1."
    exit 1
}

exit 0
