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
  final bool showLineOa;
  final String? lineOaQrBase64;
  final String? lineOaUrl;
  final String? lineOaId;

  const QrSection({
    super.key,
    required this.state,
    required this.qrMode,
    required this.staticQrBase64,
    required this.bankName,
    required this.bankAccount,
    required this.bankAccountName,
    this.showLineOa = true,
    this.lineOaQrBase64,
    this.lineOaUrl,
    this.lineOaId,
  });

  @override
  Widget build(BuildContext context) {
    Widget qrWidget;

    final isPaymentMode = state.mode == CustomerDisplayMode.payment;

    if (isPaymentMode) {
      // ══════════════════════════════════════════════════════
      // 1. โหมดชำระเงิน (Payment Mode) - แสดง QR จ่ายเงิน 100%
      // ══════════════════════════════════════════════════════
      if (state.qrData != null && state.qrData!.isNotEmpty) {
        // 1.1 Dynamic PromptPay QR
        qrWidget = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF90CAF9)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.qr_code_scanner,
                      color: Color(0xFF1565C0), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    state.qrAmount > 0
                        ? 'สแกนจ่าย ฿${state.qrAmount.toStringAsFixed(2)}'
                        : 'สแกนจ่าย PromptPay',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1565C0),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      )
                    ],
                  ),
                  child: QrImageView(
                    data: state.qrData!,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      } else if (staticQrBase64 != null && staticQrBase64!.isNotEmpty) {
        // 1.2 Static Payment QR
        qrWidget = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF90CAF9)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.account_balance,
                      color: Color(0xFF1565C0), size: 20),
                  SizedBox(width: 8),
                  Text('สแกน QR โอนเงิน',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1565C0))),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: Image.memory(
                  base64Decode(staticQrBase64!),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        );
      } else {
        // 1.3 Bank Account Box fallback
        qrWidget = Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF90CAF9)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_balance,
                  size: 48, color: Color(0xFF1565C0)),
              const SizedBox(height: 8),
              const Text(
                'กรุณาโอนเงินเข้าบัญชีร้าน',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1565C0)),
              ),
              if (state.total > 0) ...[
                const SizedBox(height: 6),
                Text(
                  'ยอดชำระ: ฿${state.total.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0D47A1)),
                ),
              ],
            ],
          ),
        );
      }
    } else {
      // ══════════════════════════════════════════════════════
      // 2. โหมดปกติ (Idle / Cart / Success) - แสดง LINE OA QR
      // ══════════════════════════════════════════════════════
      if (showLineOa &&
          (lineOaQrBase64 != null ||
              (lineOaUrl != null && lineOaUrl!.isNotEmpty))) {
        qrWidget = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline,
                      color: Color(0xFF059669), size: 16),
                  SizedBox(width: 6),
                  Text('แอด LINE ร้าน สะสมแต้ม / สั่งของ',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF059669))),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      )
                    ],
                  ),
                  child: lineOaQrBase64 != null
                      ? Image.memory(
                          base64Decode(lineOaQrBase64!),
                          fit: BoxFit.contain,
                        )
                      : QrImageView(
                          data: lineOaUrl!,
                          backgroundColor: Colors.white,
                        ),
                ),
              ),
            ),
            if (lineOaId != null && lineOaId!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'LINE ID: $lineOaId',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF059669),
                ),
              ),
            ],
          ],
        );
      } else {
        qrWidget =
            const Opacity(opacity: 0.1, child: Icon(Icons.qr_code_2, size: 100));
      }
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
