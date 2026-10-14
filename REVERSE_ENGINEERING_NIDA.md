# Reverse Engineering Khmer NiDA Keyboard Layout

## 1. Overview & Architecture

The **Khmer NiDA** keyboard layout was developed by the National Information Communications Technology Development Authority (NiDA) in Cambodia and serves as the de-facto standard phonetic keyboard layout for typing the Khmer script in modern operating systems.

On Windows 10/11, it is implemented natively as a kernel/Win32 keyboard driver:
- **Binary DLL**: `C:\Windows\System32\kbdkni.dll`
- **Keyboard Layout ID (KLID)**: `00010453` (Registry: `HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layouts\00010453`)
- **Display Name**: `@C:\Windows\system32\input.dll,-5200` ("Khmer (NIDA)")
- **Entry Point**: `KbdLayerDescriptor()` returning `PKBDTABLES`

In contrast, the older legacy layout in Windows is `kbdkhmr.dll` (KLID `00000453`, "Khmer").

---

## 2. Core Distinctions: NiDA vs Traditional Layout

| Feature | Khmer NiDA (`kbdkni.dll`) | Traditional / Old Khmer (`kbdkhmr.dll`) |
| :--- | :--- | :--- |
| **Coeng / Subscript Generator (`្` U+17D2)** | **Key `J`** (phonetically easy, mnemonic for ជើង) | **Spacebar** (Unshifted Space) |
| **Zero-Width Space (ZWSP `​` U+200B)** | **Spacebar** (Normal unshifted Space) | **Key `/?`** (Unshifted Slash) |
| **Visible Space (ASCII Space ` ` U+0020)** | **Shift + Space** | **Shift + Space** |
| **Letter Nyo (`ញ` U+1789)** | **Shift + J** | **Key `J`** |
| **Vowel Sign AM (`ាំ` U+17B6 U+17C6)** | **Shift + A** (Native Ligature) | **Shift + S** |
| **Vowel Sign OM (`ុំ` U+17BB U+17C6)** | **Key `,` (Comma)** (Native Ligature) | **Shift + J** |
| **Vowel Sign UH (`ុះ` U+17BB U+17C7)** | **Shift + `,`** (Native Ligature) | **Shift + G** |

---

## 3. Modification States (Modifier Table)

The driver sets `wMaxModBits = 6` with the following active modifier bits:
- **ModBit 0x01**: Shift (`VK_SHIFT`, 0x10)
- **ModBit 0x02**: Control (`VK_CONTROL`, 0x11)
- **ModBit 0x04**: Menu / Alt (`VK_MENU`, 0x12)

Mapping table:
- **State 0 (0)**: Normal / Unshifted
- **State 1 (1)**: Shift
- **State 2 (2)**: Control (Standard control characters `^C`, `^V`, etc.)
- **State 3 (6)**: AltGr (`Ctrl + Alt` or physical `AltGr` / `Right Alt`)
- *States 3, 4, 5, 7*: `SHFT_INVALID` (no character emission)

---

## 4. Multi-Character Ligatures (`pLigature`)

In Windows keyboard drivers, `pLigature` handles keys that emit multiple Unicode code points in a single keystroke. `kbdkni.dll` contains **5 distinct ligatures**:

| Key | State | Emitted Characters | Unicode Sequence | Khmer Description |
| :--- | :--- | :--- | :--- | :--- |
| **A** (`VK_A`, 0x41) | Shift | **ាំ** | `U+17B6` + `U+17C6` | ស្រៈ ាំ (Srak AM = Vowel AA + Nikahit) |
| **V** (`VK_V`, 0x56) | Shift | **េះ** | `U+17C1` + `U+17C7` | ស្រៈ េះ (Srak EH = Vowel E + Reahmuk) |
| **;** (`VK_OEM_1`, 0xBA) | Shift | **ោះ** | `U+17C4` + `U+17C7` | ស្រៈ ោះ (Srak AOH = Vowel OO + Reahmuk) |
| **,** (`VK_OEM_COMMA`, 0xBC) | Normal | **ុំ** | `U+17BB` + `U+17C6` | ស្រៈ ុំ (Srak OM = Vowel U + Nikahit) |
| **,** (`VK_OEM_COMMA`, 0xBC) | Shift | **ុះ** | `U+17BB` + `U+17C7` | ស្រៈ ុះ (Srak UH = Vowel U + Reahmuk) |

---

## 5. Invisible & Control Characters

Khmer word segmentation depends on zero-width characters:
- **`U+200B` (Zero-Width Space / ZWSP)**:
  - Input: **Normal Spacebar**
  - Role: Separates words without rendering a visible blank space.
- **`U+17D2` (Khmer Sign Coeng / ជើង)**:
  - Input: **Key `J`**
  - Role: Placed before a consonant to transform it into its subscript form (e.g. `ក` + `្` + `ខ` = `ក្ខ`).
- **`U+200C` (Zero-Width Non-Joiner / ZWNJ)**:
  - Input: **AltGr + `1`**
  - Role: Prevents coeng formation or contextual shaping where desired.
- **`U+200D` (Zero-Width Joiner / ZWJ)**:
  - Input: **AltGr + `` ` `` (Tilde)**
  - Role: Forces independent sub-base forms or ligature display.
- **`U+00A0` (Non-Breaking Space / NBSP)**:
  - Input: **AltGr + Spacebar**

---

## 6. Complete Keyboard Matrix

### Row 1: Number Row (`~` through `=`)

| Key | Normal | Unicode | Shift | Unicode | AltGr | Unicode |
| :--- | :---: | :--- | :---: | :--- | :---: | :--- |
| **\`** | `«` | U+00AB (Left Guillemet) | `»` | U+00BB (Right Guillemet) | `‍` | U+200D (ZWJ) |
| **1** | `១` | U+17E1 (Digit 1) | `!` | U+0021 | `‌` | U+200C (ZWNJ) |
| **2** | `២` | U+17E2 (Digit 2) | `ៗ` | U+17D7 (Lek To) | `@` | U+0040 |
| **3** | `៣` | U+17E3 (Digit 3) | `"` | U+0022 | `៑` | U+17D1 (Viriam) |
| **4** | `៤` | U+17E4 (Digit 4) | `៛` | U+17DB (Riel Sign) | `$` | U+0024 |
| **5** | `៥` | U+17E5 (Digit 5) | `%` | U+0025 | `€` | U+20AC |
| **6** | `៦` | U+17E6 (Digit 6) | `៍` | U+17CD (Toandakhiat) | `៙` | U+17D9 (Phnak Muan) |
| **7** | `៧` | U+17E7 (Digit 7) | `័` | U+17D0 (Samyok Sannya) | `៚` | U+17DA (Koomuut) |
| **8** | `៨` | U+17E8 (Digit 8) | `៏` | U+17CF (Ahsda) | `*` | U+002A |
| **9** | `៩` | U+17E9 (Digit 9) | `(` | U+0028 | `{` | U+007B |
| **0** | `០` | U+17E0 (Digit 0) | `)` | U+0029 | `}` | U+007D |
| **-** | `ឥ` | U+17A5 (Indep Vowel QI) | `៌` | U+17CC (Robat) | `×` | U+00D7 (Multiply) |
| **=** | `ឲ` | U+17B2 (Indep Vowel QOO-2) | `=` | U+003D | `៎` | U+17CE (Kakabat) |

---

### Row 2: Top Row (`Q` through `]`)

| Key | Normal | Unicode | Shift | Unicode | AltGr | Unicode |
| :--- | :---: | :--- | :---: | :--- | :---: | :--- |
| **Q** | `ឆ` | U+1786 (Cha) | `ឈ` | U+1788 (Cho) | | |
| **W** | `ឹ` | U+17B9 (Vowel Y) | `ឺ` | U+17BA (Vowel YY) | | |
| **E** | `េ` | U+17C1 (Vowel E) | `ែ` | U+17C2 (Vowel AE) | `ឯ` | U+17AF (Indep Vowel QE) |
| **R** | `រ` | U+179A (Ro) | `ឬ` | U+17AC (Indep Vowel RYY) | `ឫ` | U+17AB (Indep Vowel RY) |
| **T** | `ត` | U+178F (Ta) | `ទ` | U+1791 (To) | | |
| **Y** | `យ` | U+1799 (Yo) | `ួ` | U+17BD (Vowel UA) | | |
| **U** | `ុ` | U+17BB (Vowel U) | `ូ` | U+17BC (Vowel UU) | | |
| **I** | `ិ` | U+17B7 (Vowel I) | `ី` | U+17B8 (Vowel II) | `ឦ` | U+17A6 (Indep Vowel QII) |
| **O** | `ោ` | U+17C4 (Vowel OO) | `ៅ` | U+17C5 (Vowel AU) | `ឱ` | U+17B1 (Indep Vowel QOO-1) |
| **P** | `ផ` | U+1795 (Pha) | `ភ` | U+1797 (Pho) | `ឰ` | U+17B0 (Indep Vowel QAI) |
| **[** | `ៀ` | U+17C0 (Vowel IE) | `ឿ` | U+17BF (Vowel YA) | `ឩ` | U+17A9 (Indep Vowel QUU) |
| **]** | `ឪ` | U+17AA (Indep Vowel QAU) | `ឧ` | U+17A7 (Indep Vowel QU) | `ឳ` | U+17B3 (Indep Vowel QAU) |
| **\\** | `ឮ` | U+17AE (Indep Vowel LYY) | `ឭ` | U+17AD (Indep Vowel LY) | `\` | U+005C |

---

### Row 3: Home Row (`A` through `'`)

| Key | Normal | Unicode | Shift | Unicode | AltGr | Unicode |
| :--- | :---: | :--- | :---: | :--- | :---: | :--- |
| **A** | `ា` | U+17B6 (Vowel AA) | `ាំ` | U+17B6 U+17C6 (Srak AM) | | |
| **S** | `ស` | U+179F (Sa) | `ៃ` | U+17C3 (Vowel AI) | | |
| **D** | `ដ` | U+178A (Da) | `ឌ` | U+178C (Do) | | |
| **F** | `ថ` | U+1790 (Tha) | `ធ` | U+1792 (Tho) | | |
| **G** | `ង` | U+1784 (Ngo) | `អ` | U+17A2 (Qa) | | |
| **H** | `ហ` | U+17A0 (Ha) | `ះ` | U+17C7 (Reahmuk) | | |
| **J** | `្` | U+17D2 (Coeng / ជើង) | `ញ` | U+1789 (Nyo) | | |
| **K** | `ក` | U+1780 (Ka) | `គ` | U+1782 (Ko) | | |
| **L** | `ល` | U+179B (Lo) | `ឡ` | U+17A1 (La) | | |
| **;** | `ើ` | U+17BE (Vowel OE) | `ោះ` | U+17C4 U+17C7 (Srak AOH) | `៖` | U+17D6 (Camnuc Pii Kuuh) |
| **'** | `់` | U+17CB (Bantoc) | `៉` | U+17C9 (Muusikatoan) | `ៈ` | U+17C8 (Yuukaleapintu) |

---

### Row 4: Bottom Row (`Z` through `/`)

| Key | Normal | Unicode | Shift | Unicode | AltGr | Unicode |
| :--- | :---: | :--- | :---: | :--- | :---: | :--- |
| **Z** | `ឋ` | U+178B (Ttha) | `ឍ` | U+178D (Ttho) | | |
| **X** | `ខ` | U+1781 (Kha) | `ឃ` | U+1783 (Kho) | | |
| **C** | `ច` | U+1785 (Ca) | `ជ` | U+1787 (Co) | | |
| **V** | `វ` | U+179C (Vo) | `េះ` | U+17C1 U+17C7 (Srak EH) | | |
| **B** | `ប` | U+1794 (Ba) | `ព` | U+1796 (Po) | | |
| **N** | `ន` | U+1793 (No) | `ណ` | U+178E (Nno) | | |
| **M** | `ម` | U+1798 (Mo) | `ំ` | U+17C6 (Nikahit) | | |
| **,** | `ុំ` | U+17BB U+17C6 (Srak OM) | `ុះ` | U+17BB U+17C7 (Srak UH) | `,` | U+002C |
| **.** | `។` | U+17D4 (Khan / Period) | `៕` | U+17D5 (Bariyoosan) | `.` | U+002E |
| **/** | `៊` | U+17CA (Triisap) | `?` | U+003F | `/` | U+002F |

---

### Spacebar
- **Normal Space**: `U+200B` (Zero Width Space)
- **Shift + Space**: `U+0020` (Visible ASCII Space)
- **AltGr + Space**: `U+00A0` (Non-Breaking Space)

---

## 7. Artifacts in this Repository
- [kni_layout.csv](file:///c:/Users/Administrator/Documents/Better-NiDA/kni_layout.csv): Raw dump of all virtual keys, scan codes, and modifier outputs from `kbdkni.dll`.
- [khmr_layout.csv](file:///c:/Users/Administrator/Documents/Better-NiDA/khmr_layout.csv): Comparison dump from legacy `kbdkhmr.dll`.
- [nida_layout.json](file:///c:/Users/Administrator/Documents/Better-NiDA/nida_layout.json): Clean machine-readable JSON representation with full ligature and modifier schemas.
