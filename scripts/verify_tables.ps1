<#
.SYNOPSIS
    Cross-checks the ground-truth table dump (scripts/dump_kbd_tables.ps1)
    against the independent black-box ToUnicodeEx probe (scripts/dump_layout.ps1).

.DESCRIPTION
    Two independent paths to the same truth:
      * table path  - walking KbdLayerDescriptor() tables inside the DLL
      * probe path  - asking Windows ToUnicodeEx() what each key produces
    Any disagreement is either a decoding bug or a genuine finding.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)] [string]$TablesCsv = 'tables_kbdkni.csv',
    [Parameter(Mandatory = $false)] [string]$ProbeCsv  = 'kni_layout.csv'
)

$ErrorActionPreference = 'Stop'

$tables = Import-Csv -Encoding UTF8 $TablesCsv
$probe  = Import-Csv -Encoding UTF8 $ProbeCsv

# main character table = the one carrying the most VK entries
$mainTable = ($tables | Group-Object Table |
    Sort-Object { ($_.Group | Select-Object -ExpandProperty VK -Unique).Count } -Descending |
    Select-Object -First 1).Name

$map = @{}
$slotByName = @{}
foreach ($row in $tables) {
    if ($row.Table -ne $mainTable) { continue }
    $key = '{0}|{1}' -f [int]$row.VK, $row.StateIndex
    if (-not $map.ContainsKey($key)) {
        $map[$key] = [PSCustomObject]@{ Value = $row.Value; Note = $row.Note; Unicode = $row.Unicode }
    }
    if (-not $slotByName.ContainsKey($row.StateName)) { $slotByName[$row.StateName] = $row.StateIndex }
}

# the dump_layout.ps1 probe only recorded Normal / Shift / AltGr
$slots = @(
    @{ Probe = 'Normal'; State = $slotByName['Normal'] },
    @{ Probe = 'Shift';  State = $slotByName['Shift'] },
    @{ Probe = 'AltGr';  State = $slotByName['AltGr'] }
)

$checked = 0; $mismatch = 0; $unknown = 0
$report = @()

foreach ($row in $probe) {
    $vk = [Convert]::ToInt32(($row.VK -replace '^0x', ''), 16)
    foreach ($s in $slots) {
        $probeCol = $s.Probe
        $expected = [string]$row.$probeCol
        $key = '{0}|{1}' -f $vk, $s.State

        if (-not $map.ContainsKey($key)) {
            # key handled outside the main table (numpad, Ctrl-only, synthetic)
            if ($expected) { $unknown++ }
            continue
        }

        $actual = [string]$map[$key].Value
        $checked++

        if ($actual -ne $expected) {
            $mismatch++
            $report += [PSCustomObject]@{
                Key      = $row.Key
                VK       = ('0x{0:X2}' -f $vk)
                State    = $probeCol
                Probe    = $expected
                ProbeU   = $row.($probeCol + 'U')
                Tables   = $actual
                TablesU  = $map[$key].Unicode
                Note     = $map[$key].Note
            }
        }
    }
}

Write-Host ("main character table index : {0}" -f $mainTable)
Write-Host ("comparisons made            : {0}" -f $checked)
Write-Host ("mismatches                  : {0}" -f $mismatch)
Write-Host ("probe rows with no table row: {0}" -f $unknown)

if ($report.Count -gt 0) {
    Write-Host "`n--- differences ---" -ForegroundColor Yellow
    $report | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
}

if ($mismatch -eq 0 -and $checked -gt 0) {
    Write-Host "`nPASS: table decode matches ToUnicodeEx exactly." -ForegroundColor Green
    exit 0
} else {
    Write-Host "`nFAIL" -ForegroundColor Red
    exit 1
}
