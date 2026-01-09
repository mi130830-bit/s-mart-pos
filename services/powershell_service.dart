import 'dart:io';
import 'package:flutter/foundation.dart';

class PowerShellService {
  static final PowerShellService _instance = PowerShellService._internal();
  factory PowerShellService() => _instance;
  PowerShellService._internal();

  /// Sets the default paper size for a specific printer using PowerShell.
  /// This requires the 'PrintManagement' module (standard on Windows 8+).
  /// [printerName]: The exact name of the printer.
  /// [paperSizeName]: The name of the paper size/form (e.g., "barcode", "A4").
  Future<bool> setPrinterPaperSize(
      String printerName, String paperSizeName) async {
    if (!Platform.isWindows) return false;

    try {
      debugPrint(
          '🔧 PowerShell: Setting "$printerName" to PaperSize "$paperSizeName"...');

      // PowerShell command to set the Print Configuration
      // We use -ErrorAction Stop to catch failures
      final command =
          'Set-PrintConfiguration -PrinterName "$printerName" -PaperSize "$paperSizeName" -ErrorAction Stop';

      final result = await Process.run('powershell', ['-Command', command]);

      if (result.exitCode == 0) {
        debugPrint('✅ PowerShell: Success');
        return true;
      } else {
        debugPrint('❌ PowerShell Error: ${result.stderr}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ PowerShell Exception: $e');
      return false;
    }
  }
}
