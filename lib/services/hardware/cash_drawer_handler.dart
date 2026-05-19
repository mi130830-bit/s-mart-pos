import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../local_settings_service.dart';
import '../printing/utils/print_settings_helper.dart';
import '../printing/utils/print_data_helper.dart';
import '../pdf/thermal_receipt_pdf.dart';

class CashDrawerHandler {
  static Future<void> openDrawer({bool isTest = false}) async {
    final settings = LocalSettingsService();

    bool autoOpen = await settings.getDrawerAutoOpen();
    if (!isTest && !autoOpen) return;

    bool usePrinter = await settings.getDrawerUsePrinter();
    final String command = await settings.getDrawerCommand();

    try {
      if (usePrinter) {
        final printer = await PrintSettingsHelper.getPrinterBySettingKey(PrintSettingsHelper.keyCashPrinter);
        if (printer != null) {
          if (Platform.isWindows) {
            try {
              List<int> bytes = command
                  .split(',')
                  .map((e) => int.tryParse(e.trim()) ?? 0)
                  .toList();
              final tempFile =
                  File('${Directory.systemTemp.path}\\drawer_kick.bin');
              await tempFile.writeAsBytes(bytes);
              await Process.run('cmd', [
                '/c',
                'copy',
                '/b',
                tempFile.path,
                '\\\\127.0.0.1\\${printer.name}'
              ]);
            } catch (e) {
              debugPrint('Kick drawer windows error: $e');
            }
          }

          // ส่งคำสั่งผ่าน Printer Driver (กรณีไม่ใช่ Windows หรือ fallback)
          final pdf = await ThermalReceiptPdf.generate(
              orderId: 0,
              items: [],
              total: 0,
              grandTotal: 0,
              received: 0,
              change: 0,
              discount: 0,
              customer: null,
              pageFormat: PdfPageFormat.roll80,
              shopInfo: await PrintDataHelper.getShopInfo());

          await Printing.directPrintPdf(
              printer: printer,
              onLayout: (_) async => pdf,
              name: 'DrawerKick',
              usePrinterSettings: true);
        }
      } else {
        // ต่อตรงผ่าน COM Port หรือ IP
        final String port = await settings.getDrawerPort();
        List<int> bytes =
            command.split(',').map((e) => int.tryParse(e.trim()) ?? 0).toList();

        if (port.contains('.')) {
          // IP Address Printer
          String ip = port.trim();
          int p = 9100;
          if (ip.contains(':')) {
            final parts = ip.split(':');
            ip = parts[0];
            p = int.tryParse(parts[1]) ?? 9100;
          }
          final socket = await Socket.connect(ip, p, timeout: const Duration(seconds: 3));
          socket.add(bytes);
          await socket.flush();
          await socket.close();
        } else if (port.startsWith(r'\\') || port.startsWith('//')) {
          // Network Shared Printer Path (UNC)
          try {
             final logFile = File('C:\\pos_desktop\\drawer_log.txt');
             await logFile.writeAsString('[${DateTime.now()}] UNC Path sending to $port...\n', mode: FileMode.append);
          } catch (_) {}

          try {
             final tempFile = File('${Directory.systemTemp.path}\\drawer_kick.bin');
             await tempFile.writeAsBytes(bytes);
             final result = await Process.run('cmd', ['/c', 'copy', '/b', tempFile.path, port]);
             try {
                final logFile = File('C:\\pos_desktop\\drawer_log.txt');
                await logFile.writeAsString('[${DateTime.now()}] UNC SUCCESS exitCode: ${result.exitCode}\n', mode: FileMode.append);
             } catch (_) {}
          } catch (e) {
             debugPrint('UNC ERROR: $e');
             try {
                final logFile = File('C:\\pos_desktop\\drawer_log.txt');
                await logFile.writeAsString('[${DateTime.now()}] ERROR (UNC): $e\n', mode: FileMode.append);
             } catch (_) {}
          }
        } else {
          // COM Port
          try {
             final file = File('\\\\.\\$port');
             await file.writeAsBytes(bytes);
          } catch (e) {
             debugPrint('COM ERROR: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error Opening Drawer: $e');
    }
  }
}
