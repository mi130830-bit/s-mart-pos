import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

abstract class LabelTransport {
  Future<void> sendRaw(String tsplCommand);
}

/// Transport for LAN/Wi-Fi printers (Android & Windows)
class TcpLabelTransport implements LabelTransport {
  final String host;
  final int port;
  TcpLabelTransport(this.host, {this.port = 9100});

  @override
  Future<void> sendRaw(String tsplCommand) async {
    try {
      final socket =
          await Socket.connect(host, port, timeout: const Duration(seconds: 3));
      // TSPL usually expects Thai characters in CP874 or UTF-8 if specified in command.
      // For now, we use Tis-620/CP874 for better compatibility with standard firmware.
      socket.add(utf8.encode(tsplCommand));
      await socket.flush();
      await socket.close();
      debugPrint('[SUCCESS] TSPL sent to $host:$port');
    } catch (e) {
      debugPrint('[ERROR] TCP Print Error: $e');
      rethrow;
    }
  }
}

/// Transport for USB printers on Windows (Using Raw Write / Shared Name)
class WindowsUsbTransport implements LabelTransport {
  final String printerName;
  WindowsUsbTransport(this.printerName);

  @override
  Future<void> sendRaw(String tsplCommand) async {
    try {
      // Create a temporary file for the raw command
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
          '${tempDir.path}\\tspl_job_${DateTime.now().millisecondsSinceEpoch}.bin');

      // Write bytes (Xprinter usually handles raw bytes well)
      await tempFile.writeAsBytes(utf8.encode(tsplCommand));

      // Windows RAW print command: copy /b file \\IP\PrinterName or \\computer\printer
      // If the printer name already starts with \\, we use it as a full UNC path.
      // Otherwise, we assume it's a local shared printer and prepend \\127.0.0.1\
      final String fullPrinterPath = printerName.startsWith('\\\\')
          ? printerName
          : '\\\\127.0.0.1\\$printerName';

      final result = await Process.run(
          'cmd', ['/c', 'copy', '/b', tempFile.path, fullPrinterPath]);

      if (result.exitCode != 0) {
        throw Exception('Raw print failed: ${result.stderr}');
      }

      debugPrint('[SUCCESS] Raw TSPL sent to Windows Printer: $printerName');

      // Cleanup
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    } catch (e) {
      debugPrint('[ERROR] Windows USB Print Error: $e');
      rethrow;
    }
  }
}
