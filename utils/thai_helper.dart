class ThaiHelper {
  static const Map<String, String> _thaiToEngMap = {
    // Row 1 (Numbers)
    'ๅ': '1', '/': '2', '-': '3', 'ภ': '4', 'ถ': '5', 'ุ': '6', 'ึ': '7',
    'ค': '8', 'ต': '9', 'จ': '0', 'ข': '-', 'ช': '=',
    // Row 2
    'ๆ': 'q', 'ไ': 'w', 'ำ': 'e', 'พ': 'r', 'ะ': 't', 'ั': 'y', 'ี': 'u',
    'ร': 'i', 'น': 'o', 'ย': 'p', 'บ': '[', 'ล': ']', '\\': '\\',
    // Row 3
    'ฟ': 'a', 'ห': 's', 'ก': 'd', 'ด': 'f', 'เ': 'g', '้': 'h', '่': 'j',
    'า': 'k', 'ส': 'l', 'ว': ';', 'ง': '\'',
    // Row 4
    'ผ': 'z', 'ป': 'x', 'แ': 'c', 'อ': 'v', 'ิ': 'b', 'ื': 'n', 'ท': 'm',
    'ม': ',', 'ใ': '.', 'ฝ': '/',

    // Shifted Chars (Less common for barcode, but good to have)
    '+': '!', '๑': '@', '๒': '#', '๓': '\$', '๔': '%', 'ู': '^', '฿': '&',
    '๕': '*', '๖': '(', '๗': ')', '๘': '_', '๙': '+',
    '๐': 'Q', '"': 'W', 'ฎ': 'E', 'ฑ': 'R', 'ธ': 'T', 'ํ': 'Y', '๊': 'U',
    'ณ': 'I', 'ฯ': 'O', 'ญ': 'P', 'ฐ': '{', ',': '}', 'ฅ': '|',
    'ฤ': 'A', 'ฆ': 'S', 'ฏ': 'D', 'โ': 'F', 'ฌ': 'G', '็': 'H', '๋': 'J',
    'ษ': 'K', 'ศ': 'L', 'ซ': ':', '.': '"',
    '(': 'Z', ')': 'X', 'ฉ': 'C', 'ฮ': 'V', 'ฺ': 'B', '์': 'N', '?': 'M',
    'ฒ': '<', 'ฬ': '>', 'ฦ': '?',
  };

  static String normalizeBarcode(String input) {
    if (input.isEmpty) return input;

    final buffer = StringBuffer();
    // Iterate over code units/runes to handle combining chars (like ุ) individually
    for (var char in input.split('')) {
      buffer.write(_thaiToEngMap[char] ?? char);
    }
    return buffer.toString();
  }
}
