<#
.SYNOPSIS
    Probes what the NiDA layout emits when Control is held, plus Ctrl+Shift.

.DESCRIPTION
    The table decode left one reading unverified: that the third slot of the
    special-keys table is the Control character. This asks Windows directly.

    dump_layout.ps1 covers Normal / Shift / AltGr. This adds Control and
    Ctrl+Shift over the same virtual keys, so the secondary tables can be
    checked against behaviour instead of inference.

    Scan codes are recovered by walking scan code -> virtual key upwards and
    keeping the first hit, because F7..F10 share virtual keys with A..D and a
    direct virtual key -> scan code query reports the wrong key.

.EXAMPLE
    .\scripts\dump_layout_control.ps1
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)] [string]$TablesCsv = 'tables_kbdkni.csv',
    [Parameter(Mandatory = $false)] [string]$Klid      = '00010453',
    [Parameter(Mandatory = $false)] [string]$OutCsv    = 'kni_control.csv'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$tablesPath = if ([System.IO.Path]::IsPathRooted($TablesCsv)) { $TablesCsv } else { Join-Path $root $TablesCsv }

$code = @"
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Runtime.InteropServices;
using System.Text;

public static class ControlProbe
{
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern IntPtr LoadKeyboardLayout(string id, uint flags);
    [DllImport("user32.dll")]
    static extern uint MapVirtualKeyEx(uint code, uint mapType, IntPtr hkl);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern int ToUnicodeEx(uint vk, uint sc, byte[] keyState,
        StringBuilder buffer, int length, uint flags, IntPtr hkl);

    const byte DOWN = 0x80;
    const byte VK_SHIFT = 0x10, VK_CONTROL = 0x11;

    public static string[] Run(string klid, int[] vks)
    {
        IntPtr hkl = LoadKeyboardLayout(klid, 1);

        var sc = new Dictionary<int, uint>();
        for (uint s = 1; s <= 0xFF; s++) {
            uint vk = MapVirtualKeyEx(s, 1 /* MAPVK_VSC_TO_VK */, hkl);
            if (vk == 0 || vk > 0xFF) continue;
            if (!sc.ContainsKey((int)vk)) sc[(int)vk] = s;
        }

        var rows = new List<string>();
        rows.Add("VK,VKHex,ScanCode,Ctrl,CtrlU,CtrlShift,CtrlShiftU");

        foreach (int vk in vks) {
            uint scan = sc.ContainsKey(vk) ? sc[vk] : MapVirtualKeyEx((uint)vk, 0 /* MAPVK_VK_TO_VSC */, hkl);

            byte[] normal = new byte[256];
            byte[] ctrl = new byte[256];
            ctrl[VK_CONTROL] = DOWN;
            byte[] ctrlShift = new byte[256];
            ctrlShift[VK_CONTROL] = DOWN;
            ctrlShift[VK_SHIFT] = DOWN;

            string[] a = Decode((uint)vk, scan, ctrl, hkl);
            string[] b = Decode((uint)vk, scan, ctrlShift, hkl);

            rows.Add(string.Format(CultureInfo.InvariantCulture,
                "{0},0x{0:X2},{1},\"{2}\",\"{3}\",\"{4}\",\"{5}\"",
                vk, scan.ToString("X2", CultureInfo.InvariantCulture),
                a[0], a[1], b[0], b[1]));
        }
        return rows.ToArray();
    }

    // returns { text, "U+XXXX U+YYYY" }
    // named Decode, not Convert: the latter collides with System.Convert
    static string[] Decode(uint vk, uint scan, byte[] state, IntPtr hkl)
    {
        var sb = new StringBuilder(8);
        int ret = ToUnicodeEx(vk, scan, state, sb, sb.Capacity, 0, hkl);
        if (ret < 0) return new string[] { "<dead>", "" };
        if (ret == 0) return new string[] { "", "" };
        var sb2 = new StringBuilder(16);
        foreach (char c in sb.ToString()) {
            if (sb2.Length > 0) sb2.Append(' ');
            sb2.Append("U+").Append(((int)c).ToString("X4", CultureInfo.InvariantCulture));
        }
        return new string[] { sb.ToString(), sb2.ToString() };
    }
}
"@
if (-not ([System.Management.Automation.PSTypeName]'ControlProbe').Type) { Add-Type -TypeDefinition $code -Language CSharp }

# Probe every virtual key that appears in any decoded table, so the special-keys,
# control-character and keypad tables are all covered.
$vks = @(Import-Csv -Encoding UTF8 $tablesPath |
         Select-Object -ExpandProperty VK -Unique |
         ForEach-Object { [int]$_ } |
         Sort-Object)

$rows = [ControlProbe]::Run($Klid, $vks)
$outPath = if ([System.IO.Path]::IsPathRooted($OutCsv)) { $OutCsv } else { Join-Path $root $OutCsv }
[System.IO.File]::WriteAllText($outPath, (($rows -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding $true))

$withCtrl = @($rows | Select-Object -Skip 1 | Where-Object { $_ -notmatch ',"","",' }).Count
Write-Host ("kni_control.csv: {0} keys probed, {1} emit something with Control held" -f $vks.Count, $withCtrl)
Write-Host "  -> $outPath"
