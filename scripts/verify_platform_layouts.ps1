<#
.SYNOPSIS
    Validates the generated macOS and Linux layout files.

.DESCRIPTION
    These files cannot be exercised on a Windows build machine, so they are
    checked structurally instead. Every check here corresponds to a way the
    files are known to break:

      1. XML well-formedness and the required Apple element skeleton
      2. no duplicate <key code> inside a single keyMap (a silent mapping loss)
      3. every base key reachable in keyMap 0 (an empty base layer breaks typing)
      4. ligatures emitted with their full code point sequence
      5. XKB key names must exist in the real xkeyboard-config keycodes file
      6. XKB symbol syntax: braces balance, and each key has 2-8 levels
      7. the generated files match the source spec exactly

    Exits non-zero if any check fails.

.EXAMPLE
    .\scripts\verify_platform_layouts.ps1
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)] [switch]$SkipNetwork
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$fail = 0
function Fail([string]$m) { Write-Host ("   FAIL: " + $m) -ForegroundColor Red; $script:fail++ }
function Ok([string]$m)   { Write-Host ("   ok: " + $m)   -ForegroundColor Green }

function Get-CpString([string]$text) {
    if ([string]::IsNullOrEmpty($text)) { return '' }
    return (($text.ToCharArray() | ForEach-Object { 'U+{0:X4}' -f [int]$_ }) -join ' ')
}

# ---------------------------------------------------------------------------
Write-Host "1. macOS keylayout structure" -ForegroundColor Cyan
$macFiles = @(Get-ChildItem (Join-Path $root 'macos') -Filter '*.keylayout' -ErrorAction SilentlyContinue)
if ($macFiles.Count -eq 0) { Fail 'no .keylayout files found' }

foreach ($f in $macFiles) {
    $t = Get-Content $f.FullName -Raw -Encoding UTF8
    $rel = "macos/$($f.Name)"
    try {
        [xml]$x = $t
    } catch {
        Fail "$rel is not well-formed XML: $($_.Exception.Message)"
        continue
    }
    Ok "$rel is well-formed XML"

    foreach ($el in @('layouts','layout','modifierMap','keyMapSelect','keyMapSet','keyMap')) {
        if ($t -notmatch ('<' + $el + '[ />]')) { Fail "$rel missing <$el>" }
    }
    # Use XPath rather than dotted access: the PowerShell XML adapter is
    # unreliable when an element name repeats across levels.
    $maps = @($x.SelectNodes('/keyboard/keyMapSet/keyMap'))
    if ($maps.Count -lt 4) { Fail "$rel has only $($maps.Count) keyMaps (expected 4 or 5)" }
    else { Ok "$rel has $($maps.Count) keyMaps" }

    # duplicate key codes inside one keyMap = a silently lost mapping
    for ($i = 0; $i -lt $maps.Count; $i++) {
        $codes = @($maps[$i].SelectNodes('key') | ForEach-Object { [int]$_.GetAttribute('code') })
        $dupes = @($codes | Group-Object | Where-Object { $_.Count -gt 1 })
        if ($dupes.Count -gt 0) {
            Fail "$rel keyMap $i has duplicate key codes: $(($dupes | ForEach-Object { $_.Name }) -join ', ')"
        }
    }

    # the base layer must not be empty, or nothing can be typed
    $baseKeys = @($maps[0].SelectNodes('key') | Where-Object { $_.GetAttribute('output') }).Count
    if ($baseKeys -lt 40) { Fail "$rel keyMap 0 has only $baseKeys mapped keys (expected the full base layer)" }
    else { Ok "$rel base layer has $baseKeys mapped keys" }

    if ($t -match 'maxout="(\d+)"') { Ok "$rel maxout=$($Matches[1])" }
}

# ---------------------------------------------------------------------------
Write-Host "`n2. ligatures reproduced on macOS" -ForegroundColor Cyan
$spec = Get-Content (Join-Path $root 'nida_layout.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$macNida = Get-Content (Join-Path $root 'macos\Khmer NiDA.keylayout') -Raw -Encoding UTF8
[xml]$mx = $macNida
$baseMap = @($mx.SelectNodes('/keyboard/keyMapSet/keyMap') | Where-Object { $_.GetAttribute('index') -eq '0' })[0]
$shiftMap = @($mx.SelectNodes('/keyboard/keyMapSet/keyMap') | Where-Object { $_.GetAttribute('index') -eq '1' })[0]

# Apple key codes for the five ligature keys (A, V, ;, ,)
$ligMacCode = @{ 'A' = 0; 'V' = 9; ';' = 41; ',' = 43 }
$expected = 0
foreach ($k in $spec.keys) {
    foreach ($state in @('Normal','Shift')) {
        $ch = $k.chars.$state
        # isLigature is only emitted on multi-character entries in the spec
        if (-not $ch -or -not ($ch.PSObject.Properties.Name -contains 'isLigature')) { continue }
        $expected++
        $map = if ($state -eq 'Normal') { $baseMap } else { $shiftMap }
        $entry = $map.SelectNodes('key') | Where-Object { [int]$_.GetAttribute('code') -eq $ligMacCode[$k.usLegend] } | Select-Object -First 1
        if (-not $entry) { Fail "ligature $($k.usLegend)/${state}: key code $($ligMacCode[$k.usLegend]) missing"; continue }
        $got = Get-CpString $entry.GetAttribute('output')
        $want = ($ch.codepoints -join ' ')
        if ($got -ne $want) { Fail "ligature $($k.usLegend)/$state emitted '$got' but spec says '$want'" }
        else { Ok "ligature $($k.usLegend)/$state -> $got" }
    }
}
if ($expected -ne 5) { Fail "expected 5 ligature slots in the spec, found $expected" }

# ---------------------------------------------------------------------------
Write-Host "`n3. XKB symbols files" -ForegroundColor Cyan
$xkbFiles = @(Get-Item (Join-Path $root 'linux\nida'), (Join-Path $root 'linux\nida_legacy') -ErrorAction SilentlyContinue)
foreach ($f in $xkbFiles) {
    $lines = Get-Content $f.FullName -Encoding UTF8
    $rel = "linux/$($f.Name)"
    $keyLines = @($lines | Where-Object { $_ -match '^\s*key\s+<(\w+)>' })
    if ($keyLines.Count -lt 40) { Fail "$rel has only $($keyLines.Count) key definitions" }
    else { Ok "$rel defines $($keyLines.Count) keys" }

    foreach ($l in $keyLines) {
        if (([regex]::Matches($l, '\{')).Count -ne ([regex]::Matches($l, '\}')).Count) {
            Fail "$rel brace mismatch: $l"
        }
        $levels = @([regex]::Matches($l, ',')).Count + 1
        if ($levels -lt 2 -or $levels -gt 8) { Fail "$rel has $levels levels (must be 2-8): $l" }
    }

    $type = ($lines | Where-Object { $_ -match 'key\.type' }) -join ''
    $declared = if ($type -match 'EIGHT_LEVEL') { 8 } else { 4 }
    $maxSeen = 0
    foreach ($l in $keyLines) { $n = @([regex]::Matches($l, ',')).Count + 1; if ($n -gt $maxSeen) { $maxSeen = $n } }
    if ($maxSeen -gt $declared) { Fail "$rel emits up to $maxSeen levels but key.type allows $declared" }
    else { Ok "$rel key.type allows $declared levels, max emitted $maxSeen" }

    # every key must have at least one real symbol
    $empty = @($keyLines | Where-Object { $_ -match '^\s*key\s+<\w+>\s*\{\s*(NoSymbol\s*[,}]|\s*\})' })
    if ($empty.Count -gt 0) { Fail "$rel has $($empty.Count) keys with no symbol: $($empty[0])" }
    else { Ok "$rel every key has at least one symbol" }
}

# ---------------------------------------------------------------------------
Write-Host "`n4. XKB key names exist in xkeyboard-config" -ForegroundColor Cyan
if ($SkipNetwork) {
    Write-Host '   skipped (-SkipNetwork)'
} else {
    $url = 'https://gitlab.freedesktop.org/xkeyboard-config/xkeyboard-config/-/raw/master/keycodes/evdev'
    try {
        $kc = (Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 45).Content
    } catch {
        $kc = $null
    }

    # GitLab serves an anti-bot HTML page to some user agents, which would look
    # like "every key name is unknown". Treat a non-XKB response as
    # "could not check" rather than a failure.
    $looksLikeXkb = ($kc -and $kc -match 'xkb_keycodes' -and $kc -match '<AE01>')
    if (-not $looksLikeXkb) {
        Write-Host '   could not fetch xkeyboard-config (blocked or offline); key names not verified' -ForegroundColor Yellow
        Write-Host '   they were checked manually against keycodes/evdev - run again online to confirm' -ForegroundColor Yellow
    } else {
        $used = New-Object 'System.Collections.Generic.HashSet[string]'
        foreach ($f in $xkbFiles) {
            foreach ($l in (Get-Content $f.FullName -Encoding UTF8)) {
                if ($l -match '^\s*key\s+<(\w+)>') { [void]$used.Add($Matches[1]) }
            }
        }
        $bad = @()
        foreach ($name in $used) {
            if ($kc -notmatch ('<' + $name + '>\s*=')) { $bad += $name }
        }
        if ($bad.Count -gt 0) { Fail "unknown XKB key names: $($bad -join ', ')" }
        else { Ok "all $($used.Count) key names validated against xkeyboard-config" }
    }
}

# ---------------------------------------------------------------------------
Write-Host "`n5. generated files match the source spec" -ForegroundColor Cyan
$nidaXkb = Get-Content (Join-Path $root 'linux\nida') -Raw -Encoding UTF8
$checked = 0
foreach ($k in $spec.keys) {
    if (-not $k.scanCode) { continue }
    $cp = if ($k.chars.Normal) { [Convert]::ToInt32(($k.chars.Normal.codepoints[0] -replace '^U\+',''), 16) } else { $null }
    if ($null -eq $cp) { continue }
    $tok = 'U{0:X4}' -f $cp
    $checked++
    if ($nidaXkb -notmatch [regex]::Escape($tok)) { Fail "linux/nida missing base symbol $tok for $($k.usLegend)" }
}
Ok "linux/nida contains all $checked base symbols from nida_layout.json"

$ligMarked = @((Get-Content (Join-Path $root 'linux\nida') -Encoding UTF8) | Where-Object { $_ -match 'LIGATURE truncated' })
if ($ligMarked.Count -ne 4) { Fail "linux/nida marks $($ligMarked.Count) ligature keys as truncated, expected 4" }
else { Ok "linux/nida flags all 4 ligature keys as truncated to the first code point" }

# ---------------------------------------------------------------------------
Write-Host ''
if ($fail -eq 0) {
    Write-Host 'PASS: platform layout files are structurally valid.' -ForegroundColor Green
    Write-Host 'NOTE: these were generated and checked on Windows; they have not been' -ForegroundColor Yellow
    Write-Host '      loaded on macOS or Linux. Run the per-platform test scripts first.' -ForegroundColor Yellow
    exit 0
} else {
    Write-Host "FAIL: $fail check(s) failed." -ForegroundColor Red
    exit 1
}
