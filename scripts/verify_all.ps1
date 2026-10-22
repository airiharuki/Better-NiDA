<#
.SYNOPSIS
    Reproduces and verifies the entire Khmer layout analysis and Better-NiDA
    Midpoint build in one command.

.DESCRIPTION
    Runs the full chain from scratch and fails if any stage disagrees:

      1. dump_kbd_tables.ps1         structural decode of kbdkni, kbdkhmr, kbdus
      2. dump_layout.ps1             behavioural probe of both Khmer layouts
      3. dump_layout_control.ps1     behavioural probe with Control held
      4. build_unicode_names.ps1     official Unicode names for the characters used
      5. export_nida_spec.ps1        rebuild nida_layout.json
      6. export_midpoint_spec.ps1    rebuild midpoint_layout.json
      7. build_platform_layouts.ps1  generate macOS, Linux, and Windows (Keyman) files
      8. build_installers.ps1        build self-contained installers
      9. verify_tables.ps1           structural decode == behavioural probe
     10. verify_control.ps1          secondary tables == Control behaviour
     11. verify_midpoint.ps1         Midpoint engine keystroke matrix & guardrails
     12. verify_platform_layouts.ps1 validate macOS, Linux, m17n, and Keyman files

    Every stage runs even if an earlier one fails, so one run reports every
    problem rather than only the first. Exits 0 only if all checks pass.

.PARAMETER SkipRegenerate
    Run the verification stages against the committed artifacts instead of
    regenerating them first. Useful in CI, where the outputs are checked in.

.EXAMPLE
    .\scripts\verify_all.ps1

.EXAMPLE
    .\scripts\verify_all.ps1 -SkipRegenerate
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)] [switch]$SkipRegenerate
)

$ErrorActionPreference = 'Continue'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

$results = @()

function Invoke-Stage {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Script,
        [Parameter(Mandatory = $false)][string[]]$Arguments = @(),
        [Parameter(Mandatory = $false)][switch]$IsCheck
    )

    Write-Host ""
    Write-Host ("=" * 72) -ForegroundColor DarkGray
    Write-Host $Name -ForegroundColor Cyan
    Write-Host ("=" * 72) -ForegroundColor DarkGray

    $path = Join-Path $PSScriptRoot $Script
    $code = 0
    try {
        $invoke = @{
            FilePath     = 'powershell'
            ArgumentList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $path) + $Arguments
            Wait         = $true
            NoNewWindow  = $true
        }
        $proc = Start-Process @invoke -PassThru
        $code = $proc.ExitCode
    } catch {
        Write-Host ("   {0}" -f $_.Exception.Message) -ForegroundColor Red
        $code = 1
    }

    if ($IsCheck) { $ok = ($code -eq 0) } else { $ok = ($code -eq 0 -or $null -eq $code) }

    $script:results += [PSCustomObject]@{
        Stage = $Name
        Exit  = $code
        Ok    = $ok
    }
    if (-not $ok) { Write-Host "STAGE FAILED: $Name (exit $code)" -ForegroundColor Red }
}

Write-Host "Khmer layout verification chain" -ForegroundColor White
Write-Host "repository: $root"

if (-not $SkipRegenerate) {
    Invoke-Stage -Name '1/11 Decode driver tables (kbdkni)'   -Script 'dump_kbd_tables.ps1'      -Arguments @('-Dll', 'kbdkni.dll')
    Invoke-Stage -Name '2/11 Decode driver tables (kbdkhmr)'  -Script 'dump_kbd_tables.ps1'      -Arguments @('-Dll', 'kbdkhmr.dll')
    Invoke-Stage -Name '3/11 Decode driver tables (kbdus)'    -Script 'dump_kbd_tables.ps1'      -Arguments @('-Dll', 'kbdus.dll')
    Invoke-Stage -Name '4/11 Probe layout behaviour'          -Script 'dump_layout.ps1'
    Invoke-Stage -Name '5/11 Probe Control behaviour (NiDA)'  -Script 'dump_layout_control.ps1'
    Invoke-Stage -Name '6/11 Probe Control behaviour (US)'    -Script 'dump_layout_control.ps1' `
        -Arguments @('-TablesCsv', 'tables_kbdus.csv', '-Klid', '00000409', '-OutCsv', 'us_control.csv')
    Invoke-Stage -Name '7/11 Build Unicode name table'        -Script 'build_unicode_names.ps1'
    Invoke-Stage -Name '8/11 Rebuild nida_layout.json'        -Script 'export_nida_spec.ps1'
    Invoke-Stage -Name '9/11 Rebuild midpoint_layout.json'    -Script 'export_midpoint_spec.ps1'
    Invoke-Stage -Name '10/11 Generate platform layouts'      -Script 'build_platform_layouts.ps1'
    Invoke-Stage -Name '11/11 Build self-contained installers' -Script 'build_installers.ps1'
} else {
    Write-Host "`n-SkipRegenerate: verifying the committed artifacts as-is." -ForegroundColor Yellow
}

Invoke-Stage -Name 'CHECK  NiDA tables vs ToUnicodeEx'          -Script 'verify_tables.ps1'   -Arguments @('-TablesCsv', 'tables_kbdkni.csv',   '-ProbeCsv', 'kni_layout.csv') -IsCheck
Invoke-Stage -Name 'CHECK  legacy Khmer tables vs ToUnicodeEx'  -Script 'verify_tables.ps1'   -Arguments @('-TablesCsv', 'tables_kbdkhmr.csv', '-ProbeCsv', 'khmr_layout.csv') -IsCheck
Invoke-Stage -Name 'CHECK  secondary tables vs Control'         -Script 'verify_control.ps1'  -IsCheck
Invoke-Stage -Name 'CHECK  Better-NiDA Midpoint engine'         -Script 'verify_midpoint.ps1' -IsCheck
Invoke-Stage -Name 'CHECK  Platform layout files'               -Script 'verify_platform_layouts.ps1' -IsCheck

Write-Host ""
Write-Host ("=" * 72) -ForegroundColor DarkGray
Write-Host "Summary" -ForegroundColor White
Write-Host ("=" * 72) -ForegroundColor DarkGray
$results | Format-Table -AutoSize | Out-String -Width 120 | Write-Host

$failed = @($results | Where-Object { -not $_.Ok })
if ($failed.Count -eq 0) {
    Write-Host "ALL CHECKS PASSED" -ForegroundColor Green
    exit 0
} else {
    Write-Host ("{0} stage(s) failed:" -f $failed.Count) -ForegroundColor Red
    foreach ($f in $failed) { Write-Host ("  - {0} (exit {1})" -f $f.Stage, $f.Exit) -ForegroundColor Red }
    exit 1
}
