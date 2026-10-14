using assembly System.Windows.Forms;

<#
.SYNOPSIS
    Behavioural probe of the NiDA and legacy Khmer layouts.

.DESCRIPTION
    Asks Windows directly what each key produces, via ToUnicodeEx, for every
    scan code in every modifier state. This is the independent oracle the
    structural decode in dump_kbd_tables.ps1 is checked against.

    Kept deliberately separate from the table dump: the two paths must not
    share assumptions, or agreeing proves nothing.

.EXAMPLE
    .\scripts\dump_layout.ps1
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)] [string]$OutDir = $null
)

$code = @"
using System;
using System.Text;
using System.Runtime.InteropServices;

public class KbdDumper {
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern IntPtr LoadKeyboardLayout(string pwszKLID, uint Flags);

    [DllImport("user32.dll")]
    public static extern bool UnloadKeyboardLayout(IntPtr hkl);

    [DllImport("user32.dll")]
    public static extern int ToUnicodeEx(uint wVirtKey, uint wScanCode, byte[] lpKeyState,
        [Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pwszBuff, int cchBuff, uint wFlags, IntPtr dwhkl);

    [DllImport("user32.dll")]
    public static extern uint MapVirtualKeyEx(uint uCode, uint uMapType, IntPtr dwhkl);
}
"@
if (-not ([System.Management.Automation.PSTypeName]'KbdDumper').Type) {
    Add-Type -TypeDefinition $code
}

$hklKni = [KbdDumper]::LoadKeyboardLayout("00010453", 1)
$hklKhmr = [KbdDumper]::LoadKeyboardLayout("00000453", 1)

function Dump-Layout($hkl, $layoutName) {
    $results = @()
    $modStates = @(
        @{ Name = "Normal"; State = New-Object byte[] 256 },
        @{ Name = "Shift"; State = New-Object byte[] 256 },
        @{ Name = "AltGr"; State = New-Object byte[] 256 },
        @{ Name = "ShiftAltGr"; State = New-Object byte[] 256 }
    )
    $modStates[1].State[0x10] = 0x80 # VK_SHIFT
    
    # AltGr is Ctrl + Alt
    $modStates[2].State[0x11] = 0x80 # VK_CONTROL
    $modStates[2].State[0x12] = 0x80 # VK_MENU
    
    $modStates[3].State[0x10] = 0x80 # VK_SHIFT
    $modStates[3].State[0x11] = 0x80 # VK_CONTROL
    $modStates[3].State[0x12] = 0x80 # VK_MENU

    # All standard scan codes 0x01 to 0x58 (covers primary US keyboard keys)
    for ($sc = 1; $sc -le 0x58; $sc++) {
        $vk = [KbdDumper]::MapVirtualKeyEx($sc, 1, $hkl) # MAPVK_VSC_TO_VK
        if ($vk -eq 0) { continue }

        $row = [ordered]@{
            SC = ("0x{0:X2}" -f $sc)
            VK = ("0x{0:X2}" -f $vk)
            Key = [System.Windows.Forms.Keys]$vk
            Normal = ""
            NormalU = ""
            Shift = ""
            ShiftU = ""
            AltGr = ""
            AltGrU = ""
            ShiftAltGr = ""
            ShiftAltGrU = ""
        }

        $hasAny = $false
        foreach ($m in $modStates) {
            $sb = New-Object System.Text.StringBuilder 16
            $ret = [KbdDumper]::ToUnicodeEx($vk, $sc, $m.State, $sb, $sb.Capacity, 0, $hkl)
            if ($ret -gt 0) {
                $str = $sb.ToString()
                $row[$m.Name] = $str
                $uhex = ($str.ToCharArray() | ForEach-Object { "U+{0:X4}" -f [int]$_ }) -join " "
                $row[$m.Name + "U"] = $uhex
                $hasAny = $true
            } elseif ($ret -lt 0) {
                $row[$m.Name] = "<DeadKey>"
                $hasAny = $true
            }
        }
        if ($hasAny) {
            $results += [PSCustomObject]$row
        }
    }
    return $results
}

$kniData = Dump-Layout $hklKni "Khmer (NiDA)"
$khmrData = Dump-Layout $hklKhmr "Khmer"

# Resolve next to the repository root rather than against the current directory,
# so the probe can be run from anywhere (scripts/verify_all.ps1 relies on this).
if (-not $OutDir) { $OutDir = Join-Path $PSScriptRoot '..' }
$kniPath = Join-Path $OutDir 'kni_layout.csv'
$khmrPath = Join-Path $OutDir 'khmr_layout.csv'

$kniData | Export-Csv -Path $kniPath -NoTypeInformation -Encoding UTF8
$khmrData | Export-Csv -Path $khmrPath -NoTypeInformation -Encoding UTF8

Write-Output ("dumped {0} and {1}" -f (Split-Path -Leaf $kniPath), (Split-Path -Leaf $khmrPath))
