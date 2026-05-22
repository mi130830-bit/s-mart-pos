import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:decimal/decimal.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import '../../pos_state_manager.dart';
import '../../../../services/logger_service.dart';

mixin SlipVerificationControllerMixin<T extends StatefulWidget> on State<T> {
  static final http.Client _client = http.Client();
  bool isVerifyingSlip = false;
  String? slipVerificationMsg;
  bool? slipVerificationSuccess;

  Future<void> verifySlipFromBytes({
    required Uint8List bytes,
    required PosStateNotifier posState,
    required Decimal receivedAmount,
    required Decimal totalPaid,
    required Function(Decimal) onValidAmountApplied,
  }) async {
    setState(() {
      isVerifyingSlip = true;
      slipVerificationMsg = 'กำลังตรวจสอบสลิป...';
      slipVerificationSuccess = null;
    });

    try {
      final base64Image = base64Encode(bytes);

      if (!mounted) return;

      final Decimal grandTotal = Decimal.parse(posState.grandTotal.toString());
      Decimal amountToVerify = receivedAmount;
      if (amountToVerify <= Decimal.zero) {
        amountToVerify = grandTotal - totalPaid;
      }

      final apiUrl =
          Uri.parse('http://localhost:8080/api/v1/payment/verify-slip');

      final response = await _client.post(
        apiUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'image': base64Image,
          'amount': amountToVerify.toDouble(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (!mounted) return;
        setState(() {
          slipVerificationSuccess = data['success'] == true;
          slipVerificationMsg = data['message'];

          if (slipVerificationSuccess == true) {
            if (receivedAmount <= Decimal.zero) {
              onValidAmountApplied(amountToVerify);
            }
          }
        });
      } else {
        if (!mounted) return;
        setState(() {
          slipVerificationSuccess = false;
          slipVerificationMsg = 'Server Error: ${response.statusCode}';
        });
      }
    } catch (e, stackTrace) {
      LoggerService.error('PaymentModal', 'Verify Slip Error: $e', e, stackTrace);
      if (!mounted) return;
      setState(() {
        slipVerificationSuccess = false;
        slipVerificationMsg = 'Error: $e';
      });
    } finally {
      if (mounted) setState(() => isVerifyingSlip = false);
    }
  }

  Future<void> pickAndVerifySlip({
    required PosStateNotifier posState,
    required Decimal receivedAmount,
    required Decimal totalPaid,
    required Function(Decimal) onValidAmountApplied,
  }) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final bytes = await file.readAsBytes();
        await verifySlipFromBytes(
          bytes: bytes,
          posState: posState,
          receivedAmount: receivedAmount,
          totalPaid: totalPaid,
          onValidAmountApplied: onValidAmountApplied,
        );
      }
    } catch (e, stackTrace) {
      LoggerService.error('PaymentModal', 'Error picking file: $e', e, stackTrace);
    }
  }
}
