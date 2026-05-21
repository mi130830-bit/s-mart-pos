import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:qr_flutter/qr_flutter.dart';
import '../customer_display_provider.dart';

/// Right-bottom panel: shows a static QR image, a dynamic PromptPay QR,
/// or a placeholder when no payment QR is available.
class QrSection extends StatelessWidget {
  final CustomerDisplayState state;
  final String qrMode;
  final String? staticQrBase64;
  final String? bankName;
  final String? bankAccount;
  final String? bankAccountName;

  const QrSection({
    super.key,
    required this.state,
    required this.qrMode,
    required this.staticQrBase64,
    required this.bankName,
    required this.bankAccount,
    required this.bankAccountName,
  });

  @override
  Widget build(BuildContext context) {
    Widget qrWidget;

    if (qrMode == 'static' && staticQrBase64 != null) {
      qrWidget = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('ช่องทางชำระเงินอื่น',
              style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 10),
          Flexible(
            child: Image.memory(
              base64Decode(staticQrBase64!),
              fit: BoxFit.contain,
            ),
          ),
        ],
      );
    } else if (qrMode == 'dynamic' &&
        state.mode == CustomerDisplayMode.payment &&
        state.qrData != null) {
      qrWidget = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('สแกนจ่าย PromptPay',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54)),
          const SizedBox(height: 10),
          Flexible(
            child: AspectRatio(
              aspectRatio: 1,
              child: QrImageView(
                data: state.qrData!,
                backgroundColor: Colors.white,
              ),
            ),
          ),
        ],
      );
    } else {
      qrWidget = const Opacity(opacity: 0.1, child: Icon(Icons.qr_code_2, size: 100));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 15),
      child: Column(
        children: [
          Expanded(child: Center(child: qrWidget)),

          // Bank Info Section
          if (bankName != null &&
              bankName!.isNotEmpty &&
              bankAccount != null &&
              bankAccount!.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(indent: 20, endIndent: 20, height: 20),
            const Text('หรือโอนเงินผ่านบัญชี',
                style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 2),
            Text(bankName!,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue)),
            if (bankAccountName != null && bankAccountName!.isNotEmpty)
              Text(bankAccountName!,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54)),
            Text(bankAccount!,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: Colors.black87)),
          ],
        ],
      ),
    );
  }
}
