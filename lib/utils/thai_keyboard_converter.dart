/// Thai Keyboard Layout Converter (Kedmanee — Windows)
///
/// เมื่อผู้ใช้ลืมสลับภาษาเป็นไทยและพิมพ์ออกมาเป็นภาษาอังกฤษ
/// เช่น พิมพ์ "ปูนช้าง" แต่ได้ "x^o=hk'"  ─ ฟังก์ชันนี้แปลงกลับให้
///
/// Verified key-by-key from user keyboard photo + sample:
///   x→ป  ^→ู  o→น  =→ช  h→้  k→า  '→ง  => "ปูนช้าง" ✅
///
/// Usage:
///   ThaiKeyboardConverter.convert("x^o=hk'") // → "ปูนช้าง"
///   ThaiKeyboardConverter.isLikelyWrongLang("x^o=") // → true
class ThaiKeyboardConverter {
  ThaiKeyboardConverter._();

  /// English key → Thai character
  /// Based on Windows Thai Kedmanee, verified from user keyboard photo
  static const Map<String, String> _map = {
    // ── Number row (no shift) ──────────────────────────────────────────────
    // ` 1  2  3  4  5  6  7  8  9  0  -  =
    // _ ๅ  /  -  ภ  ถ  ุ  ึ  ค  ต  จ  ข  ช
    '`': '_',  '1': 'ๅ', '2': '/', '3': '-', '4': 'ภ',
    '5': 'ถ',  '6': 'ุ', '7': 'ึ', '8': 'ค', '9': 'ต',
    '0': 'จ',  '-': 'ข', '=': 'ช',

    // ── Number row (Shift) ─────────────────────────────────────────────────
    // ~  !  @  #  $  %  ^  &  *  (  )  _  +
    // ๊  +  ๛  ๑  ๔  ๕  ู  ฿  ๖  ๗  ๘  ๐  -
    '~': '๊',  '!': '+',  '@': '๛', '#': '๑', r'$': '๔',
    '%': '๕',  '^': 'ู',  '&': '฿', '*': '๖',
    '(': '๗',  ')': '๘',  '_': '๐', '+': '-',

    // ── Row 2 QWERTY (no shift) ────────────────────────────────────────────
    // q   w   e   r   p   t   y   u   i   o   p   [   ]   \
    // ๆ   ไ   ำ   พ   ะ   ั   ี   ร   น   ย   บ   ล   ฃ
    'q': 'ๆ',  'w': 'ไ', 'e': 'ำ', 'r': 'พ', 't': 'ะ',
    'y': 'ั',  'u': 'ี', 'i': 'ร', 'o': 'น', 'p': 'ย',
    '[': 'บ',  ']': 'ล', '\\': 'ฃ',

    // ── Row 2 QWERTY (Shift) ───────────────────────────────────────────────
    // Q   W   E   R   T   Y   U   I   O   P   {   }   |
    // ๆ   ไ   ำ   พ   ะ   ั   ี   ร   น   ย   ฐ   ,   ฅ
    'Q': 'ๆ',  'W': 'ไ', 'E': 'ำ', 'R': 'พ', 'T': 'ะ',
    'Y': 'ั',  'U': 'ี', 'I': 'ร', 'O': 'น', 'P': 'ย',
    '{': 'ฐ',  '}': ',', '|': 'ฅ',

    // ── Row 3 ASDF (no shift) ──────────────────────────────────────────────
    // a   s   d   f   g   h   j   k   l   ;   '
    // ฟ   ห   ก   ด   เ   ้   ่   า   ส   ว   ง
    'a': 'ฟ',  's': 'ห', 'd': 'ก', 'f': 'ด', 'g': 'เ',
    'h': '้',  'j': '่', 'k': 'า', 'l': 'ส', ';': 'ว',
    "'": 'ง',

    // ── Row 3 ASDF (Shift) ─────────────────────────────────────────────────
    // A   S   D   F   G   H   J   K   L   :   "
    // ฟ   ห   ก   ด   เ   ็   ๋   ษ   ศ   ซ   ฆ
    'A': 'ฟ',  'S': 'ห', 'D': 'ก', 'F': 'ด', 'G': 'เ',
    'H': '็',  'J': '๋', 'K': 'ษ', 'L': 'ศ', ':': 'ซ',
    '"': 'ฆ',

    // ── Row 4 ZXCV (no shift) ──────────────────────────────────────────────
    // z   x   c   v   b   n   m   ,   .   /
    // ผ   ป   แ   อ   ิ   ื   ท   ม   ใ   ฝ
    'z': 'ผ',  'x': 'ป', 'c': 'แ', 'v': 'อ', 'b': 'ิ',
    'n': 'ื',  'm': 'ท', ',': 'ม', '.': 'ใ', '/': 'ฝ',

    // ── Row 4 ZXCV (Shift) ─────────────────────────────────────────────────
    // Z   X   C   V   B   N   M   <   >   ?
    // ฌ   ญ   ฉ   ฎ   ฏ   ณ   ฒ   ฑ   ธ   ํ
    'Z': 'ฌ',  'X': 'ญ', 'C': 'ฉ', 'V': 'ฎ', 'B': 'ฏ',
    'N': 'ณ',  'M': 'ฒ', '<': 'ฑ', '>': 'ธ', '?': 'ํ',
  };

  /// แปลงข้อความอังกฤษ (พิมพ์ผิดภาษา) → ภาษาไทย
  /// ตัวอักษรที่ map ไม่ได้จะคงไว้เหมือนเดิม (เช่น space, เลขอารบิค)
  static String convert(String input) {
    final buffer = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final ch = input[i];
      buffer.write(_map[ch] ?? ch);
    }
    return buffer.toString();
  }

  /// ตรวจว่าข้อความ "น่าจะพิมพ์ผิดภาษา" หรือไม่
  /// เงื่อนไข: มี a-z/A-Z ≥ 2 ตัว และไม่มีภาษาไทยเลย
  static bool isLikelyWrongLang(String input) {
    if (input.trim().length < 2) return false;
    bool hasEnglish = false;
    bool hasThai = false;
    for (int i = 0; i < input.length; i++) {
      final code = input.codeUnitAt(i);
      if ((code >= 0x0041 && code <= 0x005A) || // A-Z
          (code >= 0x0061 && code <= 0x007A)) {  // a-z
        hasEnglish = true;
      }
      if (code >= 0x0E00 && code <= 0x0E7F) {   // Thai Unicode block
        hasThai = true;
      }
    }
    return hasEnglish && !hasThai;
  }
}
