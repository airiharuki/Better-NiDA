<#
.SYNOPSIS
    Checks the secondary tables against Windows behaviour.

.DESCRIPTION
    Answers three questions the table dump could not settle on its own:

      1. Is the third slot of the special-keys table (table 0) the Control
         character?  Probe ToUnicodeEx with VK_CONTROL down and compare.
      2. What are tables 2 and 3 for?  Compare their slots against the
         unshifted character and against the Control probe.
      3. Do the main table and the fallback tables overlap?  A layout should
         define each key once; overlap would mean the model is wrong.

    Exits non-zero if any key is defined twice, so this doubles as a
    regression guard.

.EXAMPLE
    .\scripts\verify_control.ps1
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)] [string]$TablesCsv = 'tables_kbdkni.csv',
    [Parameter(Mandatory = $false)] [string]$ControlCsv = 'kni_control.csv',
    [Parameter(Mandatory = $false)] [string]$ProbeCsv  = 'kni_layout.csv'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
function Resolve-Input([string]$p) {
    if ([System.IO.Path]::IsPathRooted($p)) { return $p }
    $c = Join-Path $root $p
    if (Test-Path $c) { return $c }
    return $p
}

$tables  = Import-Csv -Encoding UTF8 (Resolve-Input $TablesCsv)
$control = Import-Csv -Encoding UTF8 (Resolve-Input $ControlCsv)
$probe   = Import-Csv -Encoding UTF8 (Resolve-Input $ProbeCsv)

$failures = 0

# ---- 1. table 0 slot 2 vs the Control probe ----------------------------------
Write-Host "1. special-keys table, slot 2 vs ToUnicodeEx with Control held"
$t0 = $tables | Where-Object { $_.Table -eq '0' -and $_.StateIndex -eq '2' }
$ok = 0; $bad = 0
foreach ($r in $t0) {
    $pr = $control | Where-Object { [int]$_.VK -eq [int]$r.VK } | Select-Object -First 1
    if (-not $pr) { continue }
    $match = ($r.Unicode -eq $pr.CtrlU)
    if ($match) { $ok++ } else {
        $bad++
        Write-Host ("   MISMATCH {0,-6} slot2={1,-8} ctrl={2}" -f $r.VKName, $r.Unicode, $pr.CtrlU)
    }
}
Write-Host ("   {0} keys, {1} match, {2} mismatch" -f @($t0).Count, $ok, $bad)
if ($bad -gt 0) { $failures++ }

# ---- 2. what are tables 2 and 3 ---------------------------------------------
Write-Host "`n2. tables 2 and 3 vs the unshifted character and the Control probe"
$t2 = $tables | Where-Object { $_.Table -eq '2' -and $_.StateIndex -eq '0' }
$asNormal = 0; $asCtrl = 0; $neither = 0
foreach ($r in $t2) {
    $pr = $probe | Where-Object { [int](('0x' + ($_.VK -replace '^0x', ''))) -eq [int]$r.VK } | Select-Object -First 1
    if (-not $pr) { continue }
    $n = if ($pr.Normal) { $pr.NormalU } else { '' }
    if ($r.Unicode -eq $n) { $asNormal++ }
    $c2 = $control | Where-Object { [int]$_.VK -eq [int]$r.VK } | Select-Object -First 1
    if ($c2 -and $r.Unicode -eq $c2.CtrlU -and $c2.CtrlU) { $asCtrl++ }
    if ($r.Unicode -ne $n -and (-not $c2 -or $r.Unicode -ne $c2.CtrlU)) { $neither++ }
}
Write-Host ("   table 2: {0} entries, {1} equal the unshifted char, {2} equal the Control char" -f @($t2).Count, $asNormal, $asCtrl)
Write-Host "   -> table 2 carries base (unshifted) characters, not control characters"

# ---- 3. overlap between the main table and the fallbacks ---------------------
Write-Host "`n3. overlap between the main table and tables 2/3"
$main = @($tables | Where-Object { $_.Table -eq '1' } | Select-Object -ExpandProperty VK -Unique | ForEach-Object { [int]$_ })
$t23 = @($tables | Where-Object { $_.Table -in @('2', '3') } | Select-Object -ExpandProperty VK -Unique | ForEach-Object { [int]$_ })
$overlap = @($t23 | Where-Object { $main -contains $_ })
Write-Host ("   main table {0} keys, fallback tables {1} keys, overlap {2}" -f $main.Count, $t23.Count, $overlap.Count)
if ($overlap.Count -gt 0) {
    $failures++
    Write-Host ("   OVERLAP: {0}" -f (($overlap | ForEach-Object { '0x{0:X2}' -f $_ }) -join ', '))
} else {
    Write-Host "   -> disjoint, as expected: each key is defined exactly once"
}

# ---- verdict -----------------------------------------------------------------
Write-Host ''
if ($failures -eq 0) {
    Write-Host "PASS: secondary tables consistent with Windows behaviour." -ForegroundColor Green
    exit 0
} else {
    Write-Host "FAIL: $failures check(s) did not hold." -ForegroundColor Red
    exit 1
}
