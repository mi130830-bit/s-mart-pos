import 'package:flutter/services.dart';

class QuickMenuKeyboardMapper {
  static final Map<LogicalKeyboardKey, int> _keyToSlot = {
    // Row 1 (0-4)
    LogicalKeyboardKey.keyQ: 0,
    LogicalKeyboardKey.keyW: 1,
    LogicalKeyboardKey.keyE: 2,
    LogicalKeyboardKey.keyR: 3,
    LogicalKeyboardKey.keyT: 4,
    // Row 2 (5-9)
    LogicalKeyboardKey.keyA: 5,
    LogicalKeyboardKey.keyS: 6,
    LogicalKeyboardKey.keyD: 7,
    LogicalKeyboardKey.keyF: 8,
    LogicalKeyboardKey.keyG: 9,
    // Row 3 (10-14)
    LogicalKeyboardKey.keyZ: 10,
    LogicalKeyboardKey.keyX: 11,
    LogicalKeyboardKey.keyC: 12,
    LogicalKeyboardKey.keyV: 13,
    LogicalKeyboardKey.keyB: 14,
    // Row 4 (15-19)
    LogicalKeyboardKey.keyY: 15,
    LogicalKeyboardKey.keyU: 16,
    LogicalKeyboardKey.keyI: 17,
    LogicalKeyboardKey.keyO: 18,
    LogicalKeyboardKey.keyP: 19,
  };

  static const Map<int, String> _slotToLabel = {
    0: 'Q',
    1: 'W',
    2: 'E',
    3: 'R',
    4: 'T',
    5: 'A',
    6: 'S',
    7: 'D',
    8: 'F',
    9: 'G',
    10: 'Z',
    11: 'X',
    12: 'C',
    13: 'V',
    14: 'B',
    15: 'Y',
    16: 'U',
    17: 'I',
    18: 'O',
    19: 'P',
  };

  /// Returns the slot index (0-19) for the given key, or null if not mapped.
  static int? getSlotIndex(LogicalKeyboardKey key) {
    return _keyToSlot[key];
  }

  /// Returns the display label for the hotkey at the given slot index.
  static String getLabel(int index) {
    return _slotToLabel[index] ?? '';
  }
}
