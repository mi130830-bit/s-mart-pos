import 'package:flutter/material.dart';

enum PaymentType {
  cash('เงินสด', Icons.money),
  qr('QR/โอน', Icons.qr_code),
  card('บัตรเครดิต', Icons.credit_card),
  credit('เงินเชื่อ', Icons.credit_score);

  final String label;
  final IconData icon;
  const PaymentType(this.label, this.icon);
}
