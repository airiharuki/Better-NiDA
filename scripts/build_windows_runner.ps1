<#
.SYNOPSIS
    Builds dist/BetterNiDA-Midpoint-Windows.exe from midpoint_layout.json.

.DESCRIPTION
    Compiles a zero-dependency standalone Windows executable (.NET 4.x WinForms
    + Win32 WH_KEYBOARD_LL / SendInput unicode hook) directly from
    midpoint_layout.json using Windows PowerShell's built-in C# compiler.

    Provides two modes in one small executable:
      1. Built-in Live Typing Sandbox & Unicode Inspector (type immediately in
         the window and see both the rendered Khmer script and exact U+XXXX
         code points).
      2. System-Wide Hook Mode (toggle with Ctrl+Shift+Space or the UI button
         to type with Better-NiDA Midpoint in any Windows application with
         zero-lag inline sequence replacement).

.EXAMPLE
    .\scripts\build_windows_runner.ps1
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)] [string]$SpecPath = $null,
    [Parameter(Mandatory = $false)] [string]$OutExe   = $null
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not $SpecPath) { $SpecPath = Join-Path $root 'midpoint_layout.json' }
if (-not $OutExe)   { $OutExe   = Join-Path $root 'dist\BetterNiDA-Midpoint-Windows.exe' }

if (-not (Test-Path $SpecPath)) {
    & (Join-Path $PSScriptRoot 'export_midpoint_spec.ps1') | Out-Null
}

$midSpec = Get-Content $SpecPath -Raw -Encoding UTF8 | ConvertFrom-Json
$engineScript = Join-Path $PSScriptRoot 'midpoint_engine.ps1'
. $engineScript | Out-Null

function Format-U16Literal([string]$s) {
    if ($null -eq $s) { return '""' }
    $parts = foreach ($ch in $s.ToCharArray()) { '\u{0:X4}' -f [int]$ch }
    return '"' + ($parts -join '') + '"'
}

# Build C# table initialisers from midpoint_layout.json
$normalEntries = New-Object System.Collections.ArrayList
$shiftEntries  = New-Object System.Collections.ArrayList
$altGrEntries  = New-Object System.Collections.ArrayList
$shAltEntries  = New-Object System.Collections.ArrayList

foreach ($k in $midSpec.keys) {
    if (-not $k.scanCode) { continue }
    $vk = [int]$k.vk
    $leg = if ($k.usLegend -eq 'Space') { ' ' } else { $k.usLegend.ToLower() }
    if ($k.chars.Normal -and $k.chars.Normal.text) {
        [void]$normalEntries.Add(("            NormalByVk[{0}] = {1}; LegendByVk[{0}] = {2};" -f $vk, (Format-U16Literal $k.chars.Normal.text), (Format-U16Literal $leg)))
    }
    if ($k.chars.Shift -and $k.chars.Shift.text) {
        [void]$shiftEntries.Add(("            ShiftByVk[{0}] = {1};" -f $vk, (Format-U16Literal $k.chars.Shift.text)))
    }
    if ($k.chars.AltGr -and $k.chars.AltGr.text) {
        [void]$altGrEntries.Add(("            AltGrByVk[{0}] = {1};" -f $vk, (Format-U16Literal $k.chars.AltGr.text)))
    }
    if ($k.chars.ShiftAltGr -and $k.chars.ShiftAltGr.text) {
        [void]$shAltEntries.Add(("            ShiftAltGrByVk[{0}] = {1};" -f $vk, (Format-U16Literal $k.chars.ShiftAltGr.text)))
    }
}

$ctxEntries = New-Object System.Collections.ArrayList
foreach ($seq in $midSpec.sequences) {
    $s = [string]$seq.sequence
    $prefix = $s.Substring(0, $s.Length - 1)
    $lastCh = [string]$s[$s.Length - 1]
    $prefixRes = Resolve-Sequence $prefix ($prefix.ToCharArray())
    $prefixText = -join ($prefixRes.Emitted | ForEach-Object { [char]$_ })
    [void]$ctxEntries.Add(("            Rules.Add(new SeqRule({0}, {1}, {2}, {3}));" -f `
        (Format-U16Literal $prefixText),
        (Format-U16Literal $lastCh),
        (Format-U16Literal $seq.text),
        (Format-U16Literal "$($seq.sequence) -> $($seq.codepoints -join ' ') ($($seq.rule))")))
}

$csSource = @"
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;

namespace BetterNiDA {
    public class SeqRule {
        public string Context;
        public string KeyChar;
        public string Replacement;
        public string Description;
        public SeqRule(string ctx, string key, string rep, string desc) {
            Context = ctx; KeyChar = key; Replacement = rep; Description = desc;
        }
    }

    public static class LayoutTables {
        public static readonly Dictionary<int, string> NormalByVk = new Dictionary<int, string>();
        public static readonly Dictionary<int, string> ShiftByVk = new Dictionary<int, string>();
        public static readonly Dictionary<int, string> AltGrByVk = new Dictionary<int, string>();
        public static readonly Dictionary<int, string> ShiftAltGrByVk = new Dictionary<int, string>();
        public static readonly Dictionary<int, string> LegendByVk = new Dictionary<int, string>();
        public static readonly List<SeqRule> Rules = new List<SeqRule>();

        static LayoutTables() {
$($normalEntries -join "`n")
$($shiftEntries -join "`n")
$($altGrEntries -join "`n")
$($shAltEntries -join "`n")
$($ctxEntries -join "`n")
        }
    }

    public class MainForm : Form {
        private CheckBox chkGlobalHook;
        private TextBox txtSandbox;
        private TextBox txtCodepoints;
        private Label lblLastRule;
        private NotifyIcon trayIcon;
        private string emittedHistory = "";
        private static MainForm instance;

        // Win32 low-level keyboard hook + SendInput
        private const int WH_KEYBOARD_LL = 13;
        private const int WM_KEYDOWN = 0x0100;
        private const int WM_SYSKEYDOWN = 0x0104;
        private const uint KEYEVENTF_KEYUP = 0x0002;
        private const uint KEYEVENTF_UNICODE = 0x0004;
        private const int INPUT_KEYBOARD = 1;
        private const ushort VK_BACK = 0x08;
        private const ushort VK_SHIFT = 0x10;
        private const ushort VK_CONTROL = 0x11;
        private const ushort VK_MENU = 0x12;
        private const int LLKHF_INJECTED = 0x10;

        private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);
        private LowLevelKeyboardProc hookProc;
        private IntPtr hookId = IntPtr.Zero;

        [StructLayout(LayoutKind.Sequential)]
        private struct KBDLLHOOKSTRUCT {
            public uint vkCode;
            public uint scanCode;
            public uint flags;
            public uint time;
            public IntPtr dwExtraInfo;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct INPUT {
            public int type;
            public KEYBDINPUT ki;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct KEYBDINPUT {
            public ushort wVk;
            public ushort wScan;
            public uint dwFlags;
            public uint time;
            public IntPtr dwExtraInfo;
            public uint pad1;
            public uint pad2;
        }

        [DllImport("user32.dll", SetLastError = true)]
        private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool UnhookWindowsHookEx(IntPtr hhk);

        [DllImport("user32.dll")]
        private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

        [DllImport("user32.dll")]
        private static extern short GetAsyncKeyState(int vKey);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

        [DllImport("kernel32.dll", CharSet = CharSet.Auto)]
        private static extern IntPtr GetModuleHandle(string lpModuleName);

        public MainForm() {
            instance = this;
            Text = "Better-NiDA Midpoint - Live Tester & Windows Input Runner";
            Size = new Size(820, 600);
            StartPosition = FormStartPosition.CenterScreen;
            Font = new Font("Segoe UI", 9.5f);

            Panel topPanel = new Panel { Dock = DockStyle.Top, Height = 125, Padding = new Padding(12) };
            Label lblTitle = new Label {
                Text = "Khmer Better-NiDA (Midpoint) - Zero-Lag '/' Series Switch & Low-Shift Engine",
                Font = new Font("Segoe UI", 12f, FontStyle.Bold),
                AutoSize = true,
                Location = new Point(12, 10)
            };
            Label lblGuide = new Label {
                Text = "Rules: [Consonant + /] flips series (k/ -> \u1782, b/ -> \u1796, t/ -> \u1791, c/ -> \u1787, g/ -> \u17A2, m/ -> \u1798\u17C9, s/ -> \u179F\u17CA)  |  " +
                       "[jj] -> \u1789, [j/] -> \u17D2\u1789  |  \r\n" +
                       "Vowels: [ii] -> \u17B8, [uu] -> \u17BC, [ee] -> \u17C2, [aa] -> \u17B6\u17C6, [ea] -> \u17C4, [ei] -> \u17BE, [ua]/[u/] -> \u17BD, [ai]/[i/] -> \u17C3  |  " +
                       "Marks: []] -> \u17C6, [\\] -> \u17C7, [Space Space] -> ASCII Space",
                Location = new Point(12, 38),
                Size = new Size(780, 42)
            };

            chkGlobalHook = new CheckBox {
                Text = "Enable System-Wide Better-NiDA Typing across Windows (Shortcut: Ctrl + Shift + Space)",
                Font = new Font("Segoe UI", 10f, FontStyle.Bold),
                ForeColor = Color.DarkGreen,
                AutoSize = true,
                Checked = false,
                Location = new Point(12, 85)
            };
            chkGlobalHook.CheckedChanged += (s, e) => {
                emittedHistory = "";
                UpdateTrayText();
            };

            topPanel.Controls.Add(lblTitle);
            topPanel.Controls.Add(lblGuide);
            topPanel.Controls.Add(chkGlobalHook);

            Panel bottomPanel = new Panel { Dock = DockStyle.Bottom, Height = 135, Padding = new Padding(12) };
            lblLastRule = new Label {
                Text = "Last keystroke / rule: (type in the box below to test immediately!)",
                Font = new Font("Consolas", 9.5f, FontStyle.Bold),
                AutoSize = true,
                Location = new Point(12, 6)
            };
            Label lblCpTitle = new Label {
                Text = "Live Unicode Codepoints (U+XXXX):",
                AutoSize = true,
                Location = new Point(12, 30)
            };
            txtCodepoints = new TextBox {
                Multiline = true,
                ReadOnly = true,
                ScrollBars = ScrollBars.Vertical,
                Font = new Font("Consolas", 9.5f),
                Location = new Point(12, 52),
                Size = new Size(778, 70),
                Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right | AnchorStyles.Bottom
            };
            bottomPanel.Controls.Add(lblLastRule);
            bottomPanel.Controls.Add(lblCpTitle);
            bottomPanel.Controls.Add(txtCodepoints);

            Panel midPanel = new Panel { Dock = DockStyle.Fill, Padding = new Padding(12, 0, 12, 0) };
            txtSandbox = new TextBox {
                Multiline = true,
                Dock = DockStyle.Fill,
                ScrollBars = ScrollBars.Vertical,
                Font = new Font("Khmer OS Battambang", 18f)
            };
            txtSandbox.KeyDown += Sandbox_KeyDown;
            txtSandbox.TextChanged += (s, e) => UpdateCodepoints();
            midPanel.Controls.Add(txtSandbox);

            Controls.Add(midPanel);
            Controls.Add(bottomPanel);
            Controls.Add(topPanel);

            trayIcon = new NotifyIcon {
                Icon = SystemIcons.Application,
                Visible = true,
                Text = "Better-NiDA Midpoint (Sandbox Active)"
            };
            trayIcon.DoubleClick += (s, e) => { Show(); WindowState = FormWindowState.Normal; Activate(); };

            hookProc = HookCallback;
            hookId = SetWindowsHookEx(WH_KEYBOARD_LL, hookProc, GetModuleHandle(null), 0);

            FormClosing += (s, e) => {
                if (hookId != IntPtr.Zero) UnhookWindowsHookEx(hookId);
                trayIcon.Visible = false;
            };
        }

        private void UpdateTrayText() {
            trayIcon.Text = chkGlobalHook.Checked
                ? "Better-NiDA Midpoint: SYSTEM-WIDE ON"
                : "Better-NiDA Midpoint: Sandbox Only";
        }

        private void UpdateCodepoints() {
            StringBuilder sb = new StringBuilder();
            string t = txtSandbox.Text;
            for (int i = 0; i < t.Length; i++) {
                if (t[i] == '\r') continue;
                if (t[i] == '\n') { sb.AppendLine(); continue; }
                sb.AppendFormat("U+{0:X4} ", (int)t[i]);
            }
            txtCodepoints.Text = sb.ToString().TrimEnd();
        }

        private bool TryProcessVk(int vk, bool shift, bool ctrl, bool alt, out int backspaces, out string output, out string ruleNote) {
            backspaces = 0;
            output = null;
            ruleNote = null;

            bool altGr = (ctrl && alt) || ((GetAsyncKeyState(0xA5) & 0x8000) != 0); // RMENU
            if (ctrl && !altGr) return false;
            if (alt && !altGr) return false;

            if (vk == VK_BACK) {
                if (emittedHistory.Length > 0)
                    emittedHistory = emittedHistory.Substring(0, emittedHistory.Length - 1);
                return false;
            }

            if (altGr && shift) {
                if (LayoutTables.ShiftAltGrByVk.TryGetValue(vk, out output)) {
                    emittedHistory += output;
                    ruleNote = "Shift+AltGr static layer (Rule 5)";
                    return true;
                }
                return false;
            }

            if (altGr) {
                if (LayoutTables.AltGrByVk.TryGetValue(vk, out output)) {
                    emittedHistory += output;
                    ruleNote = "AltGr static layer";
                    return true;
                }
                return false;
            }

            if (shift) {
                if (LayoutTables.ShiftByVk.TryGetValue(vk, out output)) {
                    emittedHistory += output;
                    ruleNote = (vk == (int)Keys.J) ? "Shift+J -> U+17D2 (Rule 2 rollover-safe coeng)" : "Shift static layer";
                    return true;
                }
                return false;
            }

            string keyLegend;
            if (LayoutTables.LegendByVk.TryGetValue(vk, out keyLegend)) {
                for (int i = 0; i < LayoutTables.Rules.Count; i++) {
                    SeqRule r = LayoutTables.Rules[i];
                    if (r.KeyChar == keyLegend && emittedHistory.EndsWith(r.Context, StringComparison.Ordinal)) {
                        backspaces = r.Context.Length;
                        output = r.Replacement;
                        emittedHistory = emittedHistory.Substring(0, emittedHistory.Length - backspaces) + output;
                        ruleNote = r.Description;
                        return true;
                    }
                }
            }

            if (LayoutTables.NormalByVk.TryGetValue(vk, out output)) {
                emittedHistory += output;
                ruleNote = string.Format("Key '{0}' -> {1}", keyLegend, FormatCps(output));
                return true;
            }

            if (vk == (int)Keys.Return || vk == (int)Keys.Tab || vk == (int)Keys.Escape ||
                (vk >= (int)Keys.Left && vk <= (int)Keys.Down)) {
                emittedHistory = "";
            }
            return false;
        }

        private static string FormatCps(string s) {
            StringBuilder sb = new StringBuilder();
            for (int i = 0; i < s.Length; i++) {
                if (i > 0) sb.Append(" ");
                sb.AppendFormat("U+{0:X4}", (int)s[i]);
            }
            return sb.ToString();
        }

        private void Sandbox_KeyDown(object sender, KeyEventArgs e) {
            if (chkGlobalHook.Checked) return; // Global hook handles it

            if (e.Control && e.Shift && e.KeyCode == Keys.Space) {
                chkGlobalHook.Checked = !chkGlobalHook.Checked;
                e.SuppressKeyPress = true;
                return;
            }

            int bs;
            string outStr, note;
            if (TryProcessVk((int)e.KeyCode, e.Shift, e.Control, e.Alt, out bs, out outStr, out note)) {
                e.SuppressKeyPress = true;
                int selStart = txtSandbox.SelectionStart;
                if (txtSandbox.SelectionLength > 0) {
                    txtSandbox.SelectedText = "";
                    selStart = txtSandbox.SelectionStart;
                }
                if (bs > 0 && selStart >= bs) {
                    txtSandbox.Select(selStart - bs, bs);
                    txtSandbox.SelectedText = "";
                }
                txtSandbox.SelectedText = outStr;
                lblLastRule.Text = "Last keystroke / rule: " + note;
            }
        }

        private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
            if (nCode >= 0 && (wParam == (IntPtr)WM_KEYDOWN || wParam == (IntPtr)WM_SYSKEYDOWN)) {
                KBDLLHOOKSTRUCT kb = (KBDLLHOOKSTRUCT)Marshal.PtrToStructure(lParam, typeof(KBDLLHOOKSTRUCT));
                if ((kb.flags & LLKHF_INJECTED) == 0 && instance != null) {
                    bool shift = (GetAsyncKeyState(VK_SHIFT) & 0x8000) != 0;
                    bool ctrl  = (GetAsyncKeyState(VK_CONTROL) & 0x8000) != 0;
                    bool alt   = (GetAsyncKeyState(VK_MENU) & 0x8000) != 0;

                    if (ctrl && shift && kb.vkCode == 0x20) {
                        instance.BeginInvoke((Action)(() => {
                            instance.chkGlobalHook.Checked = !instance.chkGlobalHook.Checked;
                        }));
                        return (IntPtr)1;
                    }

                    if (instance.chkGlobalHook.Checked) {
                        int bs;
                        string outStr, note;
                        if (instance.TryProcessVk((int)kb.vkCode, shift, ctrl, alt, out bs, out outStr, out note)) {
                            SendReplacement(bs, outStr);
                            instance.BeginInvoke((Action)(() => {
                                instance.lblLastRule.Text = "Last keystroke / rule: " + note;
                            }));
                            return (IntPtr)1;
                        }
                    }
                }
            }
            return CallNextHookEx(instance != null ? instance.hookId : IntPtr.Zero, nCode, wParam, lParam);
        }

        private static void SendReplacement(int backspaces, string text) {
            List<INPUT> inputs = new List<INPUT>();
            for (int i = 0; i < backspaces; i++) {
                inputs.Add(MakeVkInput(VK_BACK, false));
                inputs.Add(MakeVkInput(VK_BACK, true));
            }
            for (int i = 0; i < text.Length; i++) {
                ushort ch = (ushort)text[i];
                inputs.Add(MakeUnicodeInput(ch, false));
                inputs.Add(MakeUnicodeInput(ch, true));
            }
            if (inputs.Count > 0) {
                INPUT[] arr = inputs.ToArray();
                SendInput((uint)arr.Length, arr, Marshal.SizeOf(typeof(INPUT)));
            }
        }

        private static INPUT MakeVkInput(ushort vk, bool keyUp) {
            INPUT inp = new INPUT();
            inp.type = INPUT_KEYBOARD;
            inp.ki.wVk = vk;
            inp.ki.dwFlags = keyUp ? KEYEVENTF_KEYUP : 0;
            return inp;
        }

        private static INPUT MakeUnicodeInput(ushort scan, bool keyUp) {
            INPUT inp = new INPUT();
            inp.type = INPUT_KEYBOARD;
            inp.ki.wVk = 0;
            inp.ki.wScan = scan;
            inp.ki.dwFlags = KEYEVENTF_UNICODE | (keyUp ? KEYEVENTF_KEYUP : 0);
            return inp;
        }

        [STAThread]
        public static void Main() {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new MainForm());
        }
    }
}
"@

$outDir = Split-Path -Parent $OutExe
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
if (Test-Path $OutExe) { Remove-Item $OutExe -Force }

$cp = New-Object System.CodeDom.Compiler.CompilerParameters
$cp.GenerateExecutable = $true
$cp.OutputAssembly = $OutExe
$cp.CompilerOptions = '/target:winexe /optimize+'
[void]$cp.ReferencedAssemblies.Add('System.dll')
[void]$cp.ReferencedAssemblies.Add('System.Drawing.dll')
[void]$cp.ReferencedAssemblies.Add('System.Windows.Forms.dll')

$provider = New-Object Microsoft.CSharp.CSharpCodeProvider
$cr = $provider.CompileAssemblyFromSource($cp, $csSource)
if ($cr.Errors.HasErrors) {
    foreach ($err in $cr.Errors) { Write-Host $err.ToString() -ForegroundColor Red }
    throw "Failed to compile $OutExe"
}

Write-Host ("Built standalone Windows runner: {0} ({1} bytes)" -f $OutExe, (Get-Item $OutExe).Length) -ForegroundColor Green
