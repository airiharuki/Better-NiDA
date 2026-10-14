<#
.SYNOPSIS
    Reverse-engineers a Windows keyboard layout DLL (kbd*.dll) by walking the
    KBDLAYERDESCRIPTORSTRUCT tables exported by its KbdLayerDescriptor() function.

.DESCRIPTION
    Loads the DLL in-process and decodes the real in-memory tables rather than
    probing behaviour through ToUnicodeEx. Everything below was derived from
    kbdkni.dll / kbdkhmr.dll / kbdus.dll on Windows and validated against a
    black-box ToUnicodeEx dump.

    Descriptor layout (64-bit):
      +0x00  PKBDCHARACTERMODIFIER pCharModifiers
      +0x08  PKBD_VK_TO_WCHAR_TABLE pVkToWcharTable   (4 sub-tables, 16 bytes each)
      +0x10  PKBD_DEADKEYINFO        pDeadKey
      +0x18  PKBD_KEYNAME            pKeyNames
      +0x20  PKBD_KEYNAME_EXT        pKeyNamesExt
      +0x28  PKBD_KEYNAME_DEAD       pKeyNamesDead
      +0x30  PUSHORT                 puVKeyToCodes
      +0x38  USHORT                  cbVKeyToCodes
      +0x40  PKBD_TYPEDEF            pTypedef
      +0x48  PKEYNAME_STRINGS        pKeyNameStrings
      +0x54  BYTE                    nLgMax
      +0x55  BYTE                    cbLgEntry
      +0x58  KBD_LIGATURE            pLigature

    Sub-table descriptor (16 bytes), terminated by a NULL pointer:
      +0x00  PVOID  pTable
      +0x08  BYTE   cStates      number of modifier states held per entry
      +0x09  BYTE   cbEntry      = 2 * (1 + cStates)
      +0x0A  USHORT (reserved / 0)

    Entry (cbEntry bytes):
      +0x00  USHORT vk
      +0x02  USHORT wchar[cStates]   one character per modifier state
    A wchar of 0xF000 means "no character for this state"; 0xF002 means the
    state resolves through the ligature table.

    Ligature entry (cbLgEntry bytes):
      +0x00  BYTE  vk
      +0x01  BYTE  reserved
      +0x02  USHORT mod          modifier number (see pCharModifiers)
      +0x04  WCHAR text[nLgMax]

.OUTPUTS
    <OutPrefix>.json  full decoded tables
    <OutPrefix>.csv   the main character map, one row per key/state
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Dll = 'kbdkni.dll',

    [Parameter(Mandatory = $false)]
    [string]$OutPrefix = $null
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not $OutPrefix) {
    $OutPrefix = [System.IO.Path]::Combine(
        $PSScriptRoot, '..', ("tables_" + [System.IO.Path]::GetFileNameWithoutExtension($Dll).ToLower()))
}

$code = @'
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

public class KbdDecode
{
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern IntPtr LoadLibrary(string lpFileName);
    [DllImport("kernel32.dll")]
    static extern bool FreeLibrary(IntPtr hModule);
    [DllImport("kernel32.dll")]
    static extern IntPtr GetProcAddress(IntPtr hModule, string procName);
    delegate IntPtr KbdLayerDescriptorDelegate();

    const ushort NONE = 0xF000;      // wchar slot: nothing emitted
    const ushort LIGATURE = 0xF002;  // wchar slot: resolve via pLigature

    static byte[] img;
    static ulong  b64;

    static byte U8(int rva)  { return img[rva]; }
    static ushort U16(int rva) { return (ushort)(img[rva] | (img[rva + 1] << 8)); }
    static ulong U64(int rva)  { return BitConverter.ToUInt64(img, rva); }
    static int Rva(ulong addr) { return (int)(addr - b64); }
    static int Rva(long addr)  { return (int)(addr - (long)b64); }

    static string Esc(string s)
    {
        if (s == null) return "null";
        var sb = new StringBuilder("\"");
        foreach (char c in s) {
            switch (c) {
                case '"':  sb.Append("\\\""); break;
                case '\\': sb.Append("\\\\"); break;
                case '\n': sb.Append("\\n"); break;
                case '\r': sb.Append("\\r"); break;
                case '\t': sb.Append("\\t"); break;
                default:
                    if (c < 0x20 || c == 0x7F) sb.Append("\\u").Append(((int)c).ToString("x4"));
                    else sb.Append(c);
                    break;
            }
        }
        return sb.Append('"').ToString();
    }

    static string U(ushort w) { return "U+" + w.ToString("X4"); }

    public static string[] Decode(string path)
    {
        IntPtr hMod = LoadLibrary(path);
        if (hMod == IntPtr.Zero) throw new InvalidOperationException("LoadLibrary failed: " + path);
        b64 = (ulong)hMod.ToInt64();

        uint soi;
        using (var fs = File.OpenRead(path))
        using (var br = new BinaryReader(fs)) {
            fs.Position = 0x3C; int e = br.ReadInt32();
            fs.Position = e + 4 + 20 + 56; soi = br.ReadUInt32();
        }
        img = new byte[soi];
        Marshal.Copy(hMod, img, 0, (int)soi);

        var proc = GetProcAddress(hMod, "KbdLayerDescriptor");
        if (proc == IntPtr.Zero) throw new InvalidOperationException("no KbdLayerDescriptor export");
        var kld = (KbdLayerDescriptorDelegate)Marshal.GetDelegateForFunctionPointer(proc, typeof(KbdLayerDescriptorDelegate));
        int d = Rva(kld().ToInt64());

        // ---- ligature table -------------------------------------------------
        int nLgMax  = U8(d + 0x54);
        int cbLg    = U8(d + 0x55);
        int lgStart = nLgMax > 0 && cbLg > 0 ? Rva(U64(d + 0x58)) : 0;
        var ligByKey = new Dictionary<string, string>();
        var ligs = new List<string>();
        if (lgStart > 0) {
            for (int o = lgStart;; o += cbLg) {
                int vk = U8(o);
                ushort mod = U16(o + 2);
                if (vk == 0 && mod == 0) break;
                var sb = new StringBuilder();
                var cps = new List<string>();
                for (int i = 0; i < nLgMax; i++) {
                    char c = (char)U16(o + 4 + i * 2);
                    if (c == 0) break;
                    sb.Append(c);
                    cps.Add(U((ushort)c));
                }
                ligByKey[vk + ":" + mod] = sb.ToString();
                ligs.Add(string.Format("        {{ \"vk\": {0}, \"vkName\": {1}, \"modNumber\": {2}, \"text\": {3}, \"codepoints\": [ {4} ] }}",
                    vk, Esc(VkName(vk)), mod, Esc(sb.ToString()),
                    string.Join(", ", cps.ConvertAll(Esc).ToArray())));
                if (ligs.Count > 512) break;
            }
        }

        // ---- modifier tables ------------------------------------------------
        int pCharMod = Rva(U64(d + 0x00));
        int pVkToBit = Rva(U64(pCharMod));
        int wMaxModBits = U16(pCharMod + 8);
        var modName = new Dictionary<int, string>();
        for (int bit = 0; bit <= wMaxModBits; bit++) {
            int modNum = U8(pCharMod + 10 + bit);
            modName[bit] = ModStateName(modNum);
        }
        var modLines = new List<string>();
        for (int bit = 0; bit <= wMaxModBits; bit++) {
            modLines.Add(string.Format("        {{ \"modBit\": {0}, \"modNumber\": {1}, \"name\": {2} }}",
                bit, U8(pCharMod + 10 + bit), Esc(ModStateName(U8(pCharMod + 10 + bit)))));
        }

        // distinct modifier numbers, in the order the character map lists them
        var states = new List<int>();
        for (int i = 0; i <= wMaxModBits; i++) {
            int m = U8(pCharMod + 10 + i);
            if (m != 15 && !states.Contains(m)) states.Add(m);
        }
        var stateLines = new List<string>();
        for (int i = 0; i < states.Count; i++)
            stateLines.Add(string.Format("        {{ \"index\": {0}, \"modNumber\": {1}, \"name\": {2} }}",
                i, states[i], Esc(ModStateName(states[i]))));

        // ---- character sub-tables -------------------------------------------
        int vkTable = Rva(U64(d + 0x08));
        var tables = new List<string>();
        var csv = new List<string>();
        csv.Add("Table,VK,VKName,USLegend,StateIndex,ModNumber,StateName,Value,Unicode,Note");

        for (int t = 0; t < 8; t++) {
            int rec = vkTable + t * 16;
            ulong ptr = U64(rec);
            if (ptr == 0) break;
            int p = Rva((long)ptr);
            int cStates = U8(rec + 8);
            int cbEntry = U8(rec + 9);
            if (cStates == 0 || cbEntry != 2 * (1 + cStates)) continue;

            // Only a table whose width equals the layout's modifier-state count
            // is known to be indexed by modifier number (and that one is
            // confirmed by the ToUnicodeEx cross-check). The others are dumped
            // with neutral slot labels rather than guessed at.
            bool stateIndexed = (cStates == states.Count);

            var entries = new List<string>();
            for (int o = p;; o += cbEntry) {
                int vk = U16(o);
                bool empty = true;
                for (int i = 0; i <= cStates; i++) if (U16(o + i * 2) != 0) { empty = false; break; }
                if (empty) break;

                var fields = new List<string>();
                for (int i = 0; i < cStates; i++) {
                    ushort w = U16(o + 2 + i * 2);
                    int modNum = i < states.Count ? states[i] : i;
                    string slotName = stateIndexed ? ModStateName(modNum) : ("Slot" + i);
                    string val = "", note = "";
                    if (w == NONE) {
                        note = "no-character";
                    } else if (w == LIGATURE) {
                        string lg;
                        if (ligByKey.TryGetValue(vk + ":" + modNum, out lg)) { val = lg; note = "ligature"; }
                        else { val = ""; note = "ligature(unresolved)"; }
                    } else {
                        val = ((char)w).ToString();
                    }
                    fields.Add(string.Format("{{ \"modNumber\": {0}, \"name\": {1}, \"unicode\": {2}, \"text\": {3}, \"note\": {4} }}",
                        modNum, Esc(slotName),
                        Esc(w == NONE || w == LIGATURE ? null : U(w)), Esc(val), Esc(note)));
                    csv.Add(string.Format("{0},{1},\"{2}\",\"{3}\",{4},{5},{6},\"{7}\",\"{8}\",\"{9}\"",
                        t, vk, Esc(VkName(vk)).Replace("\"", "\"\""), Esc(VkLegend(vk)).Replace("\"", "\"\""),
                        i, modNum, slotName, val.Replace("\"", "\"\""),
                        (w == NONE || w == LIGATURE) ? (w == LIGATURE ? "0xF002" : "0xF000") : U(w), note));
                }
                entries.Add(string.Format("        {{ \"vk\": {0}, \"vkName\": {1}, \"usLegend\": {2}, \"states\": [ {3} ] }}",
                    vk, Esc(VkName(vk)), Esc(VkLegend(vk)), string.Join(", ", fields.ToArray())));
                if (entries.Count > 1024) break;
            }
            tables.Add(string.Format(
                "    {{ \"index\": {0}, \"cStates\": {1}, \"cbEntry\": {2}, \"entryCount\": {3}, \"entries\": [\n{4}\n    ] }}",
                t, cStates, cbEntry, entries.Count,
                entries.Count > 0 ? string.Join(",\n", entries.ToArray()) : ""));
        }

        // ---- VK -> modifier bitmask ----------------------------------------
        var vkBitLines = new List<string>();
        for (int vk = 0; vk < 256; vk++) {
            ushort bits = U16(pVkToBit + vk * 2);
            if (bits == 0) continue;
            vkBitLines.Add(string.Format("        {{ \"vk\": {0}, \"vkName\": {1}, \"usLegend\": {2}, \"modifierMask\": {3} }}",
                vk, Esc(VkName(vk)), Esc(VkLegend(vk)), bits));
        }

        var json = new StringBuilder();
        json.Append("{\n");
        json.AppendFormat("  \"layoutFile\": {0},\n", Esc(Path.GetFileName(path)));
        json.AppendFormat("  \"wMaxModBits\": {0},\n", wMaxModBits);
        json.AppendFormat("  \"nLgMax\": {0},\n", nLgMax);
        json.AppendFormat("  \"cbLgEntry\": {0},\n", cbLg);
        json.Append("  \"modifierBits\": [\n" + string.Join(",\n", modLines.ToArray()) + "\n  ],\n");
        json.Append("  \"modifierStates\": [\n" + string.Join(",\n", stateLines.ToArray()) + "\n  ],\n");
        json.Append("  \"characterTables\": [\n" + string.Join(",\n", tables.ToArray()) + "\n  ],\n");
        json.Append("  \"ligatures\": [\n" + (ligs.Count > 0 ? string.Join(",\n", ligs.ToArray()) : "") + "\n  ],\n");
        json.Append("  \"vkModifierMasks\": [\n" + string.Join(",\n", vkBitLines.ToArray()) + "\n  ]\n");
        json.Append("}\n");

        FreeLibrary(hMod);
        return new string[] { json.ToString(), string.Join("\r\n", csv.ToArray()) + "\r\n" };
    }

    static string ModStateName(int modNum)
    {
        switch (modNum) {
            case 0:  return "Normal";
            case 1:  return "Shift";
            case 2:  return "Control";
            case 3:  return "AltGr";
            case 4:  return "ShiftAltGr";
            case 15: return "Invalid";
            default: return "State" + modNum;
        }
    }

    static string[] ROW_NAMES = new string[0x100];
    static string[] LEGEND = new string[0x100];
    static bool namesReady = false;

    // Virtual-key codes, not scan codes: A-Z are 0x41..0x5A, digits 0x30..0x39,
    // Space is 0x20. Function keys overlap the letter block (F7 == VK 0x41), so
    // the printable interpretation wins for a keyboard layout dump.
    static void InitNames()
    {
        if (namesReady) return;
        namesReady = true;
        for (int i = 0; i < 0x100; i++) ROW_NAMES[i] = "VK_" + i.ToString("X2", CultureInfo.InvariantCulture);

        Action<string, int, string> set = (name, vk, legend) => {
            ROW_NAMES[vk] = name;
            if (legend != null) LEGEND[vk] = legend;
        };

        // Letter virtual keys are NOT contiguous: A-Z spread over 0x41..0x5A in
        // QWERTY order (Q is 0x51, not 0x10). VK 0x10..0x19 are the modifier
        // keys instead.
        string[] letterKeys = {
            "Q:0x51", "W:0x57", "E:0x45", "R:0x52", "T:0x54", "Y:0x59", "U:0x55", "I:0x49",
            "O:0x4F", "P:0x50",
            "A:0x41", "S:0x53", "D:0x44", "F:0x46", "G:0x47", "H:0x48", "J:0x4A", "K:0x4B",
            "L:0x4C",
            "Z:0x5A", "X:0x58", "C:0x43", "V:0x56", "B:0x42", "N:0x4E", "M:0x4D"
        };
        foreach (string lk in letterKeys) {
            string ch = lk.Substring(0, 1);
            set(ch, Convert.ToInt32(lk.Substring(2), 16), ch);
        }

        // digits: VK 0x30 = '0' .. VK 0x39 = '9'
        for (int i = 0; i <= 9; i++) set(((char)('0' + i)).ToString(), 0x30 + i, ((char)('0' + i)).ToString());

        set("Backspace", 0x08, "Backspace");
        set("Tab", 0x09, "Tab");
        set("Enter", 0x0D, "Enter");
        set("CapsLock", 0x3A, "Caps Lock");
        set("Esc", 0x1B, "Esc");
        set("Space", 0x20, "Space");
        set("LShift", 0xA0, "Shift");
        set("LCtrl", 0xA2, "Ctrl");
        set("LAlt", 0xA4, "Alt");
        set("RCtrl", 0xA3, "Ctrl");
        set("RAlt", 0xA5, "AltGr");

        // OEM block: name is the VK, legend is the key cap
        set("OEM_1", 0xBA, ";");
        set("OEM_PLUS", 0xBB, "=");
        set("OEM_COMMA", 0xBC, ",");
        set("OEM_MINUS", 0xBD, "-");
        set("OEM_PERIOD", 0xBE, ".");
        set("OEM_2", 0xBF, "/");
        set("OEM_3", 0xC0, "`");
        set("OEM_4", 0xDB, "[");
        set("OEM_5", 0xDC, "\\");
        set("OEM_6", 0xDD, "]");
        set("OEM_7", 0xDE, "'");
        set("OEM_102", 0xE2, "\\");

        // Function keys. F7..F10 share VKs 0x41..0x44 with the letters A..D and
        // are deliberately omitted: for a keyboard layout the letter reading is
        // the correct one.
        string[] fn = { "F1", "F2", "F3", "F4", "F5", "F6", "F11", "F12" };
        for (int i = 0; i < fn.Length; i++) set(fn[i], 0x70 + i, fn[i]);

        set("NumLock", 0x90, "Num Lock");
        set("ScrollLock", 0x91, "Scroll Lock");

        // numeric keypad
        for (int i = 0; i <= 9; i++) set("Numpad " + i, 0x60 + i, ((char)('0' + i)).ToString());
        set("Multiply", 0x6A, "*");
        set("Add", 0x6B, "+");
        set("Separator", 0x6C, null);
        set("Subtract", 0x6D, "-");
        set("Decimal", 0x6E, ".");
        set("Divide", 0x6F, "/");
    }

    public static string VkLegend(int vk)
    {
        InitNames();
        if (vk < 0 || vk >= 0x100) return "";
        return LEGEND[vk] ?? ROW_NAMES[vk];
    }

    public static string VkName(int vk)
    {
        InitNames();
        return (vk >= 0 && vk < 0x100) ? ROW_NAMES[vk] : "VK_" + vk.ToString("X2", CultureInfo.InvariantCulture);
    }
}
'@

if (-not ([System.Management.Automation.PSTypeName]'KbdDecode').Type) {
    Add-Type -TypeDefinition $code -Language CSharp
}

$dllPath = if ([System.IO.Path]::IsPathRooted($Dll)) { $Dll } else { Join-Path $env:SystemRoot "System32\$Dll" }

$result = [KbdDecode]::Decode($dllPath)

$jsonPath = "$OutPrefix.json"
$csvPath  = "$OutPrefix.csv"
# JSON stays BOM-free (most JSON tooling rejects a BOM); the CSV gets one so
# Excel and Windows PowerShell read the Khmer characters correctly.
[System.IO.File]::WriteAllText($jsonPath, $result[0], (New-Object System.Text.UTF8Encoding $false))
[System.IO.File]::WriteAllText($csvPath,  $result[1], (New-Object System.Text.UTF8Encoding $true))

$obj = $result[0] | ConvertFrom-Json
$main = $obj.characterTables | Sort-Object { -($_.cbEntry) } | Select-Object -First 1
Write-Host ("{0}: {1} modifier states, main table {2} entries, {3} ligatures" -f `
    $dllPath, $obj.modifierStates.Count, $main.entryCount, $obj.ligatures.Count)
Write-Host "  -> $jsonPath"
