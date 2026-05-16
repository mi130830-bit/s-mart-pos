import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import '../../models/order_item.dart';
import '../../models/customer.dart';
import '../../models/shop_info.dart';
import '../printing/delivery_note_pdf.dart';

// ใช้ Logic เดียวกับ DeliveryNotePdf แต่ Fix ขนาดเป็น A4 เพื่อความง่าย
class DeliveryNoteA4Pdf {
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
    return DeliveryNotePdf.generate(
        orderId: orderId,
        items: items,
        customer: customer,
        shopInfo: shopInfo,
        pageFormat: PdfPageFormat.a4,
        remark: remark);
  }
}
