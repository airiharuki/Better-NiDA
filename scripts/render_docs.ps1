# Renders the verified layout data as GitHub-flavoured markdown fragments.
# Writes UTF-8 files directly: the Windows console cannot render Khmer reliably.
#
# ASCII-only source on purpose: Windows PowerShell 5.1 reads BOM-less .ps1 files
# as ANSI, which mangles (and can even break parsing of) non-ASCII literals.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)] [string]$SpecJson = 'nida_layout.json',
    [Parameter(Mandatory = $false)] [string]$OutDir = "$env:TEMP\opencode"
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$spec = Get-Content (Join-Path $root $SpecJson) -Raw -Encoding UTF8 | ConvertFrom-Json

function Cell($ch) {
    if ($null -eq $ch) { return '' }
    $cps = $ch.codepoints -join ' '
    # Zero-width and space characters are invisible in a table: label them.
    $shown = ''
    foreach ($c in $ch.text.ToCharArray()) {
        $cp = [int]$c
        $shown += switch ($cp) {
            0x00A0 { '<NBSP>' }
            0x200B { '<ZWSP>' }
            0x200C { '<ZWNJ>' }
            0x200D { '<ZWJ>' }
            default {
                if ($c -match '^[\x20-\x7E]$') { '`' + $c + '`' } else { $c }
            }
        }
    }
    if ($shown -match '^[\x20-\x7E]+$') { return ('{0} {1}' -f $shown, $cps) }
    return ('{0} {1}' -f $shown, $cps)
}

# ---- NiDA matrix -------------------------------------------------------------
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('| Key | VK | SC | Normal | Shift | AltGr |')
[void]$sb.AppendLine('| :-- | :-- | :-- | :-- | :-- | :-- |')
foreach ($k in $spec.keys) {
    if (-not $k.scanCode) { continue }
    $n = Cell $k.chars.Normal
    $s = Cell $k.chars.Shift
    $a = Cell $k.chars.AltGr
    $line = '| **{0}** | `{1}` | `{2}` | {3} | {4} | {5} |' -f $k.usLegend, $k.vkHex, $k.scanCode, $n, $s, $a
    [void]$sb.AppendLine($line)
}
[System.IO.File]::WriteAllText((Join-Path $OutDir 'matrix_nida.md'), $sb.ToString(), (New-Object System.Text.UTF8Encoding $false))

# ---- legacy Khmer comparison -------------------------------------------------
$cmp = @'
| Feature | Khmer NiDA (`kbdkni.dll`) | Legacy Khmer (`kbdkhmr.dll`) |
| :-- | :-- | :-- |
| Coeng subscript U+17D2 | key `J` | key `Space` |
| Zero-width space U+200B | key `Space` | key `/` |
| Visible space U+0020 | `Shift + Space` | `Shift + Space` |
| Letter Nyo U+1789 | `Shift + J` | key `J` |
| Srak AM (U+17B6 U+17C6) | `Shift + A` | `Shift + S` |
| Srak OM (U+17BB U+17C6) | key `,` | `Shift + J` |
| Srak UH (U+17BB U+17C7) | `Shift + ,` | `Shift + G` |
| Srah EH (U+17C1 U+17C7) | `Shift + V` | `Shift + V` |
| Srah AOH (U+17C4 U+17C7) | `Shift + ;` | `Shift + [` |
| Modifier states in main table | 4 (Normal / Shift / Control / AltGr) | 5 (+ Shift+AltGr) |
| Shift+AltGr characters | not defined | Khmer symbol set U+19E0..U+19FF |
'@
[System.IO.File]::WriteAllText((Join-Path $OutDir 'compare_khmer.md'), $cmp, (New-Object System.Text.UTF8Encoding $false))

Write-Host "wrote matrix_nida.md and compare_khmer.md to $OutDir"
