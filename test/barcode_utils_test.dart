import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_desktop/utils/barcode_utils.dart';

void main() {
  group('BarcodeUtils Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await BarcodeUtils.init();
    });

    test('fixThaiInput converts Thai chars to English correctly', () {
      // Test 1: "ข" -> "-"
      expect(BarcodeUtils.fixThaiInput('ข'), equals('-'));

      // Test 2: "จ" -> "0"
      expect(BarcodeUtils.fixThaiInput('จ'), equals('0'));

      // Test 3: "ๅ/-ภถุึคตจขช" -> "1234567890-="
      expect(BarcodeUtils.fixThaiInput('ๅ/-ภถุึคตจขช'), equals('1234567890-='));

      // Test 4: Mixed (Should convert ONLY Thai)
      expect(BarcodeUtils.fixThaiInput('AขB'), equals('A-B'));

      // Test 5: Shifted Chars (Shift key held)
      // "!" is "+" on US keyboard (Shift+1). On Thai keyboard shift+1 is "+" (actually !)
      // Wait, Thai 1 is ๅ. Shift+1 is +.
      // US 1 is 1. Shift+1 is !.
      // So if I type + (Thai Shift+1), it means I wanted '!' ?
      // No, usually barcode scanner sends US keycodes.
      // If scanner sends '!' (Shift+1), and keyboard is Thai, it types '+'.
      // So input is '+'. We want output implicitly... wait.
      // The logic is: User scanned, but keyboard was Thai.
      // Scanner sent keycode for '1'. Thai layout printed 'ๅ'. We convert 'ๅ' -> '1'.
      // Scanner sent keycode for 'Shift+1' (!). Thai layout printed '+'. We convert '+' -> '!'.
      expect(BarcodeUtils.fixThaiInput('+'), equals('!'));

      // Test Real World: "885..." typed as "คคถ..."
      expect(BarcodeUtils.fixThaiInput('คคถ'), equals('885'));
    });

    test('isThaiInput detects Thai characters', () {
      expect(BarcodeUtils.isThaiInput('abc'), isFalse);
      expect(BarcodeUtils.isThaiInput('123'), isFalse);
      expect(BarcodeUtils.isThaiInput('ก'), isTrue);
      expect(BarcodeUtils.isThaiInput('abcก'), isTrue);
    });

    test('Settings can disable fix', () async {
      await BarcodeUtils.saveSettings(
          enabled: false, mapping: BarcodeUtils.getCurrentMapping());

      expect(BarcodeUtils.fixThaiInput('ข'), equals('ข'),
          reason: 'Should not fix when disabled');
    });
  });
}
