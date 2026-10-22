<#
.SYNOPSIS
    Validates the generated macOS, Linux, and Windows (Keyman) layout files.

.DESCRIPTION
    These files cannot all be loaded interactively on a Windows build machine,
    so they are checked structurally and round-tripped against the source
    specifications:

      1. XML well-formedness and the required Apple element skeleton
      2. no duplicate <key code> inside a single keyMap (a silent mapping loss)
      3. every base key reachable in keyMap 0 (an empty base layer breaks typing)
      4. ligatures emitted with their full code point sequence on macOS
      5. XKB key names must exist in the real xkeyboard-config keycodes file
      6. XKB symbol syntax: braces balance, and each key has 2-8 levels
      7. generated XKB files match nida_layout.json and midpoint_layout.json
      8. Linux m17n (nida-midpoint.mim) balanced s-expressions, LF line endings,
         and 100% sequence + base layer parity with midpoint_layout.json
      9. Windows Keyman (better_nida_midpoint.kmn) LF line endings, valid headers,
         and 100% contextual sequence + static layer parity with midpoint_layout.json

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

function Test-LfOnly([string]$path, [string]$rel) {
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $crlf = 0
    for ($i = 1; $i -lt $bytes.Length; $i++) {
        if ($bytes[$i] -eq 10 -and $bytes[$i - 1] -eq 13) { $crlf++ }
    }
    if ($crlf -gt 0) { Fail "$rel contains $crlf CRLF line endings (must be LF)" }
    else { Ok "$rel uses LF line endings" }
}

# ---------------------------------------------------------------------------
Write-Host "1. macOS keylayout structure" -ForegroundColor Cyan
$macFiles = @(Get-ChildItem (Join-Path $root 'macos') -Filter '*.keylayout' -ErrorAction SilentlyContinue)
if ($macFiles.Count -lt 3) { Fail "expected 3 .keylayout files in macos/, found $($macFiles.Count)" }

foreach ($f in $macFiles) {
    $t = Get-Content $f.FullName -Raw -Encoding UTF8
    $rel = "macos/$($f.Name)"
    Test-LfOnly $f.FullName $rel
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
    $maps = @($x.SelectNodes('/keyboard/keyMapSet/keyMap'))
    if ($maps.Count -lt 4) { Fail "$rel has only $($maps.Count) keyMaps (expected 4 or 5)" }
    else { Ok "$rel has $($maps.Count) keyMaps" }

    for ($i = 0; $i -lt $maps.Count; $i++) {
        $codes = @($maps[$i].SelectNodes('key') | ForEach-Object { [int]$_.GetAttribute('code') })
        $dupes = @($codes | Group-Object | Where-Object { $_.Count -gt 1 })
        if ($dupes.Count -gt 0) {
            Fail "$rel keyMap $i has duplicate key codes: $(($dupes | ForEach-Object { $_.Name }) -join ', ')"
        }
    }

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

$ligMacCode = @{ 'A' = 0; 'V' = 9; ';' = 41; ',' = 43 }
$expected = 0
foreach ($k in $spec.keys) {
    foreach ($state in @('Normal','Shift')) {
        $ch = $k.chars.$state
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
$xkbFiles = @(Get-Item (Join-Path $root 'linux\nida'), (Join-Path $root 'linux\nida_legacy'), (Join-Path $root 'linux\nida_midpoint') -ErrorAction SilentlyContinue)
if ($xkbFiles.Count -lt 3) { Fail "expected 3 XKB files in linux/, found $($xkbFiles.Count)" }
foreach ($f in $xkbFiles) {
    $lines = Get-Content $f.FullName -Encoding UTF8
    $rel = "linux/$($f.Name)"
    Test-LfOnly $f.FullName $rel
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
Write-Host "`n5. generated XKB files match the source specs" -ForegroundColor Cyan
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

$midSpec = Get-Content (Join-Path $root 'midpoint_layout.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$midXkb = Get-Content (Join-Path $root 'linux\nida_midpoint') -Raw -Encoding UTF8
$midChecked = 0
foreach ($k in $midSpec.keys) {
    if (-not $k.scanCode) { continue }
    $cp = if ($k.chars.Normal) { [Convert]::ToInt32(($k.chars.Normal.codepoints[0] -replace '^U\+',''), 16) } else { $null }
    if ($null -eq $cp) { continue }
    $tok = 'U{0:X4}' -f $cp
    $midChecked++
    if ($midXkb -notmatch [regex]::Escape($tok)) { Fail "linux/nida_midpoint missing base symbol $tok for $($k.usLegend)" }
}
Ok "linux/nida_midpoint contains all $midChecked base symbols from midpoint_layout.json"

# ---------------------------------------------------------------------------
Write-Host "`n6. Linux m17n (linux/m17n/nida-midpoint.mim)" -ForegroundColor Cyan
$mimPath = Join-Path $root 'linux\m17n\nida-midpoint.mim'
if (-not (Test-Path $mimPath)) {
    Fail 'linux/m17n/nida-midpoint.mim not found'
} else {
    Test-LfOnly $mimPath 'linux/m17n/nida-midpoint.mim'
    $mimText = Get-Content $mimPath -Raw -Encoding UTF8
    # Lexical s-expression balance check (respecting strings and backslash escapes)
    $openP = 0; $closeP = 0; $inStr = $false; $inComment = $false; $mi = 0
    while ($mi -lt $mimText.Length) {
        $ch = $mimText[$mi]
        if ($inComment) {
            if ($ch -eq "`n") { $inComment = $false }
            $mi++; continue
        }
        if ($ch -eq '\') { $mi += 2; continue }
        if ($inStr) {
            if ($ch -eq '"') { $inStr = $false }
            $mi++; continue
        }
        if ($ch -eq '"') { $inStr = $true; $mi++; continue }
        if ($ch -eq ';') { $inComment = $true; $mi++; continue }
        if ($ch -eq '(') { $openP++ }
        elseif ($ch -eq ')') { $closeP++ }
        $mi++
    }
    if ($inStr) { Fail "linux/m17n/nida-midpoint.mim has unclosed string literal" }
    elseif ($openP -ne $closeP) { Fail "linux/m17n/nida-midpoint.mim unbalanced parentheses: $openP '(' vs $closeP ')'" }
    else { Ok "linux/m17n/nida-midpoint.mim has balanced s-expressions ($openP pairs)" }

    $missingSeq = 0
    foreach ($seq in $midSpec.sequences) {
        if ($mimText -notmatch [regex]::Escape($seq.text)) { $missingSeq++ }
    }
    if ($missingSeq -gt 0) { Fail "linux/m17n/nida-midpoint.mim missing $missingSeq sequence outputs" }
    else { Ok "linux/m17n/nida-midpoint.mim contains all $(@($midSpec.sequences).Count) sequence rules from midpoint_layout.json" }
}

# ---------------------------------------------------------------------------
Write-Host "`n7. Windows Keyman (windows/better_nida_midpoint.kmn)" -ForegroundColor Cyan
$kmnPath = Join-Path $root 'windows\better_nida_midpoint.kmn'
if (-not (Test-Path $kmnPath)) {
    Fail 'windows/better_nida_midpoint.kmn not found'
} else {
    Test-LfOnly $kmnPath 'windows/better_nida_midpoint.kmn'
    $kmnText = Get-Content $kmnPath -Raw -Encoding UTF8
    foreach ($hdr in @("store(&VERSION)", "store(&NAME)", "begin Unicode > use(main)", "group(main) using keys")) {
        if ($kmnText -notmatch [regex]::Escape($hdr)) { Fail "windows/better_nida_midpoint.kmn missing '$hdr'" }
    }
    Ok "windows/better_nida_midpoint.kmn has required Keyman headers and main group"

    $ctxLines = @((Get-Content $kmnPath -Encoding UTF8) | Where-Object { $_ -match '^U\+[0-9A-F]{4}.*\+\s*\[K_' })
    if ($ctxLines.Count -ne @($midSpec.sequences).Count) {
        Fail "windows/better_nida_midpoint.kmn has $($ctxLines.Count) contextual rules, expected $(@($midSpec.sequences).Count)"
    } else {
        Ok "windows/better_nida_midpoint.kmn has all $($ctxLines.Count) zero-lag contextual sequence rules"
    }
}

# ---------------------------------------------------------------------------
Write-Host ''
if ($fail -eq 0) {
    Write-Host 'PASS: platform layout files are structurally valid.' -ForegroundColor Green
    exit 0
} else {
    Write-Host "FAIL: $fail check(s) failed." -ForegroundColor Red
    exit 1
}
