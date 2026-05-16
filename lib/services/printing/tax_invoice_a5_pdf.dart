import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import '../../models/order_item.dart';
import '../../models/customer.dart';
import '../../models/shop_info.dart';
import 'tax_invoice_a4_pdf.dart';

// ใช้ Logic เดียวกับ A4 แต่เปลี่ยน Format เป็น A5 (หรือจะแยก Logic ก็ได้ถ้าต้องการจัดหน้าใหม่)
class TaxInvoiceA5Pdf {
  static Future<Uint8List> generate({
    required int orderId,
    required List<OrderItem> items,
    required double total,
    required double grandTotal,
    required double vatRate,
    required Customer customer,
    required ShopInfo shopInfo,
  }) async {
    // ในที่นี้ขอใช้ Logic เดียวกับ A4 ไปก่อนเพื่อความรวดเร็ว แต่ PDF จะถูกบีบลง A5
    // หากต้องการจัดหน้าเฉพาะ A5 ควรสร้าง Class แยกแบบ CashReceiptA5Pdf
    return TaxInvoiceA4Pdf.generate(
      orderId: orderId,
      items: items,
      total: total,
      grandTotal: grandTotal,
      vatRate: vatRate,
      customer: customer,
      shopInfo: shopInfo,
      pageFormat: PdfPageFormat.a5.copyWith(
        marginLeft: 1.0 * PdfPageFormat.cm,
        marginRight: 1.0 * PdfPageFormat.cm,
        marginTop: 1.0 * PdfPageFormat.cm,
        marginBottom: 1.0 * PdfPageFormat.cm,
      ),
    );
  }
}
