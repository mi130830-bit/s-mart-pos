import 'dart:typed_data';
//import 'package:pdf/pdf.dart';
import '../../models/order_item.dart';
import '../../models/customer.dart';
import '../../models/shop_info.dart';
import 'delivery_note_a4_pdf.dart';

class CashReceiptA4Pdf {
  static Future<Uint8List> generate({
    required int orderId,
    required List<OrderItem> items,
    required Customer? customer,
    double discount = 0.0,
    double vatAmount = 0.0,
    double? grandTotalOverride,
    required ShopInfo shopInfo,
    bool showRuler = false,
    String? remark,
  }) async {
    // Re-uses the exact same logic and beautiful layout as DeliveryNoteA4Pdf
    // but overrides the title for Cash Receipts
    return DeliveryNoteA4Pdf.generate(
      orderId: orderId,
      items: items,
      customer: customer,
      discount: discount,
      vatAmount: vatAmount,
      grandTotalOverride: grandTotalOverride,
      shopInfo: shopInfo,
      showRuler: showRuler,
      remark: remark,
      documentTitleTh: 'บิลเงินสด',
      documentTitleEn: 'บิลเงินสด',
      signatureLabel: 'ผู้รับเงิน',
    );
  }
}
