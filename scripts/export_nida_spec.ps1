$rows = Import-Csv -Path "$PSScriptRoot\kni_layout.csv" -Encoding UTF8

$ligatures = @{
    "0x41" = @{
        "Shift" = @{
            Chars = "$([char]0x17B6)$([char]0x17C6)"
            Codepoints = @("U+17B6", "U+17C6")
            Names = @("KHMER VOWEL SIGN AA", "KHMER SIGN NIKAHIT")
            Description = "Srak AM"
        }
    }
    "0x56" = @{
        "Shift" = @{
            Chars = "$([char]0x17C1)$([char]0x17C7)"
            Codepoints = @("U+17C1", "U+17C7")
            Names = @("KHMER VOWEL SIGN E", "KHMER SIGN REAHMUK")
            Description = "Srak EH"
        }
    }
    "0xBA" = @{
        "Shift" = @{
            Chars = "$([char]0x17C4)$([char]0x17C7)"
            Codepoints = @("U+17C4", "U+17C7")
            Names = @("KHMER VOWEL SIGN OO", "KHMER SIGN REAHMUK")
            Description = "Srak AOH"
        }
    }
    "0xBC" = @{
        "Normal" = @{
            Chars = "$([char]0x17BB)$([char]0x17C6)"
            Codepoints = @("U+17BB", "U+17C6")
            Names = @("KHMER VOWEL SIGN U", "KHMER SIGN NIKAHIT")
            Description = "Srak OM"
        }
        "Shift" = @{
            Chars = "$([char]0x17BB)$([char]0x17C7)"
            Codepoints = @("U+17BB", "U+17C7")
            Names = @("KHMER VOWEL SIGN U", "KHMER SIGN REAHMUK")
            Description = "Srak UH"
        }
    }
}

$keyLabels = @{
    "0x01" = "Esc"; "0x02" = "1"; "0x03" = "2"; "0x04" = "3"; "0x05" = "4"; "0x06" = "5";
    "0x07" = "6"; "0x08" = "7"; "0x09" = "8"; "0x0A" = "9"; "0x0B" = "0"; "0x0C" = "-"; "0x0D" = "=";
    "0x0E" = "Backspace"; "0x0F" = "Tab";
    "0x10" = "Q"; "0x11" = "W"; "0x12" = "E"; "0x13" = "R"; "0x14" = "T"; "0x15" = "Y";
    "0x16" = "U"; "0x17" = "I"; "0x18" = "O"; "0x19" = "P"; "0x1A" = "["; "0x1B" = "]"; "0x1C" = "Enter";
    "0x1E" = "A"; "0x1F" = "S"; "0x20" = "D"; "0x21" = "F"; "0x22" = "G"; "0x23" = "H";
    "0x24" = "J"; "0x25" = "K"; "0x26" = "L"; "0x27" = ";"; "0x28" = "'"; '0x29' = '`';
    "0x2B" = "\"; "0x2C" = "Z"; "0x2D" = "X"; "0x2E" = "C"; "0x2F" = "V"; "0x30" = "B";
    "0x31" = "N"; "0x32" = "M"; "0x33" = ","; "0x34" = "."; "0x35" = "/"; "0x39" = "Space"
}

$keysArray = @()

foreach ($r in $rows) {
    $sc = $r.SC
    $vk = $r.VK
    $label = if ($keyLabels.ContainsKey($sc)) { $keyLabels[$sc] } else { $r.Key }

    function Get-KeySlot($char, $cpStr, $modName) {
        if ($ligatures.ContainsKey($vk) -and $ligatures[$vk].ContainsKey($modName)) {
            $lig = $ligatures[$vk][$modName]
            return [ordered]@{
                Text = $lig.Chars
                Codepoints = $lig.Codepoints
                Names = $lig.Names
                IsLigature = $true
                Description = $lig.Description
            }
        }
        if (-not $char -or $char -eq "") {
            return $null
        }
        $cps = $cpStr -split " "
        return [ordered]@{
            Text = $char
            Codepoints = $cps
            IsLigature = ($cps.Count -gt 1)
        }
    }

    $entry = [ordered]@{
        ScanCode = $sc
        VirtualKey = $vk
        KeyLabel = $label
        Normal = Get-KeySlot $r.Normal $r.NormalU "Normal"
        Shift = Get-KeySlot $r.Shift $r.ShiftU "Shift"
        AltGr = Get-KeySlot $r.AltGr $r.AltGrU "AltGr"
    }

    $keysArray += $entry
}

$meta = [ordered]@{
    LayoutName = "Khmer (NIDA)"
    LayoutFile = "KBDKNI.DLL"
    KLID = "00010453"
    Locale = "km-KH"
    Architecture = "Windows Win32 Keyboard Layout Driver"
    ModifierMapping = [ordered]@{
        "ModBit 0" = "State 0: Normal"
        "ModBit 1" = "State 1: Shift"
        "ModBit 2" = "State 2: Control"
        "ModBit 6" = "State 3: AltGr (Right Alt / Ctrl+Alt)"
    }
    SpecialKeys = [ordered]@{
        "J" = "Khmer Sign Coeng (Subscript Generator) U+17D2"
        "Space" = "Zero-Width Space (ZWSP) U+200B"
        "Shift+Space" = "ASCII Space U+0020"
        "AltGr+Space" = "Non-Breaking Space (NBSP) U+00A0"
        "AltGr+1" = "Zero-Width Non-Joiner (ZWNJ) U+200C"
        'AltGr+`' = "Zero-Width Joiner (ZWJ) U+200D"
    }
    Ligatures = @(
        [ordered]@{ Key = "Shift + A"; Codepoints = "U+17B6 U+17C6"; Description = "Khmer Vowel Sign AM" },
        [ordered]@{ Key = "Shift + V"; Codepoints = "U+17C1 U+17C7"; Description = "Khmer Vowel Sign EH" },
        [ordered]@{ Key = "Shift + ;"; Codepoints = "U+17C4 U+17C7"; Description = "Khmer Vowel Sign OH" },
        [ordered]@{ Key = ", (Comma)"; Codepoints = "U+17BB U+17C6"; Description = "Khmer Vowel Sign OM" },
        [ordered]@{ Key = "Shift + ,"; Codepoints = "U+17BB U+17C7"; Description = "Khmer Vowel Sign UH" }
    )
    Keys = $keysArray
}

$json = $meta | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText("$PSScriptRoot\nida_layout.json", $json, [System.Text.Encoding]::UTF8)
Write-Output "Successfully exported nida_layout.json"
