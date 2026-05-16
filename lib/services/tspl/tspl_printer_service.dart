import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../../models/label_data.dart';
import '../../models/label_config.dart';
import 'tspl_templates.dart';
import 'label_transport.dart';

class TsplPrinterService {
  static final TsplPrinterService _instance = TsplPrinterService._internal();
  factory TsplPrinterService() => _instance;
  TsplPrinterService._internal();

  /// Constants for settings
  static const String keyUseTspl = 'printer_tspl_enabled';
  static const String keyTsplMode =
      'printer_tspl_mode'; // 'tcp' or 'windows_usb'
  static const String keyPrinterIp = 'printer_tspl_ip';
  static const String keyPrinterPort = 'printer_tspl_port';
  static const String keyWindowsPrinterName = 'printer_tspl_windows_name';

  Future<bool> isTsplEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyUseTspl) ?? false;
  }

  Future<void> printLabel({
    required LabelType type,
    required LabelData data,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(keyTsplMode) ?? 'windows_usb';

    LabelTransport transport;

    if (mode == 'tcp') {
      final ip = prefs.getString(keyPrinterIp) ?? '192.168.1.100';
      final port = prefs.getInt(keyPrinterPort) ?? 9100;
      transport = TcpLabelTransport(ip, port: port);
    } else {
      // Windows USB (Direct commands to local shared printer)
      final name = prefs.getString(keyWindowsPrinterName) ?? 'XP-420B';
      transport = WindowsUsbTransport(name);
    }

    final template = TsplTemplateFactory.getTemplate(type);
    final command = template.build(data);

    debugPrint('🚀 Dispatching TSPL Command via $mode...');
    await transport.sendRaw(command);
  }

  Future<void> testConnection({
    required String mode,
    required String ip,
    required int port,
    required String windowsName,
  }) async {
    LabelTransport transport;
    if (mode == 'tcp') {
      transport = TcpLabelTransport(ip, port: port);
    } else {
      transport = WindowsUsbTransport(windowsName);
    }

    // Send a simple TSPL command that just feeds half inch or does nothing but checks connection
    // SELFTEST is a good command for testing
    const command = 'SELFTEST\r\n';
    await transport.sendRaw(command);
  }
}
