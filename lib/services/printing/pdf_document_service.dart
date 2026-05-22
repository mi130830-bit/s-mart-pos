import 'package:flutter/services.dart';

import '../../models/billing_note.dart';
import '../pdf/billing_note_pdf.dart';
import '../pdf/purchase_order_pdf.dart';

// Service class remains the public interface
class PdfDocumentService {
  final PurchaseOrderPdfGenerator _poGenerator = PurchaseOrderPdfGenerator();
  final BillingNotePdfGenerator _billingGenerator = BillingNotePdfGenerator();

  Future<Uint8List> generateBillingNote({
    required BillingNote note,
    required List<Map<String, dynamic>> items,
  }) async {
    return await _billingGenerator.generate(note: note, items: items);
  }

  Future<Uint8List> generatePurchaseOrder({
    required Map<String, dynamic> header,
    required List<Map<String, dynamic>> items,
  }) async {
    return await _poGenerator.generate(header: header, items: items);
  }
}
