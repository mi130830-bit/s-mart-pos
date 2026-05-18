part of '../pos_state_manager.dart';

extension PosDeliveryExtension on PosStateManager {
  Future<void> sendToDeliveryFromHistory(int orderId,
      {String jobType = 'delivery'}) async {
    final data = await _salesRepo.getOrderForDelivery(orderId);
    if (data == null) throw Exception('บิล #$orderId ไม่พบข้อมูล');

    final orderData = data['orderData'] as Map<String, dynamic>;
    final itemsData = data['items'] as List<Map<String, dynamic>>;

    final customer = orderData['customerId'] != null
        ? Customer.fromJson({...orderData, 'id': orderData['customerId']})
        : Customer(
            id: 0, memberCode: 'GENERAL', currentPoints: 0,
            firstName: 'ลูกค้า', lastName: 'ทั่วไป (Walk-in)',
            phone: orderData['phone']?.toString() ?? '',
            address: orderData['address']?.toString() ?? '');

    final List<OrderItem> items =
        itemsData.map((row) => OrderItem.fromJson(row)).toList();

    final gTotal = double.tryParse(orderData['grandTotal'].toString()) ?? 0.0;
    final received = double.tryParse(orderData['received']?.toString() ?? '0') ?? 0.0;
    final String? pm = orderData['paymentMethod']?.toString();

    final bool isCredit = pm != null &&
        (pm.toUpperCase().contains('CREDIT') ||
            pm.contains('เงินเชื่อ') || pm.contains('ลงบัญชี'));

    String deliveryNote = !isCredit && received >= gTotal - 0.01
        ? '✅ จ่ายเงินแล้ว (Paid)'
        : '📝 ลงบัญชี/เก็บปลายทาง (COD/Credit)';

    if (jobType == 'customer_pickup' || jobType == 'pickup') {
      deliveryNote += ' (รับเองที่ร้าน)';
    }

    final billPdfData = await ReceiptService().generateDeliveryNoteData(
      orderId: orderId, items: items, customer: customer,
      discount: double.tryParse(orderData['discount']?.toString() ?? '0') ?? 0,
      vatAmount: double.tryParse(orderData['vatAmount']?.toString() ?? '0') ?? 0.0,
      grandTotalOverride: gTotal,
    );

    Customer effectiveCustomer = customer;
    if (jobType == 'pickup' || jobType == 'customer_pickup') {
      effectiveCustomer = Customer(
        id: customer.id, firstName: customer.firstName,
        lastName: customer.lastName, phone: customer.phone,
        currentPoints: customer.currentPoints, memberCode: customer.memberCode,
        address: '', shippingAddress: '',
        firebaseUid: customer.firebaseUid, lineUserId: customer.lineUserId,
      );
    }

    await _deliveryService.createDeliveryJob(
        orderId: orderId, customer: effectiveCustomer, items: items,
        grandTotal: gTotal, isManual: true, note: deliveryNote,
        billPdfData: billPdfData, jobType: jobType,
        paymentMethod: isCredit ? 'credit' : 'cash',
        vatAmount: double.tryParse(orderData['vatAmount']?.toString() ?? '0') ?? 0.0);
  }

  Future<void> _processDeliveryJobInBackground(
    int orderId, DeliveryType deliveryType, Customer? currentCust,
    List<OrderItem> currentItems, double grandTotal, double received,
    double discountAmount, double vatAmount, List<PaymentRecord> payments, {
    String? manualNote,
  }) async {
    try {
      Customer effectiveCustomer = currentCust ??
          Customer(id: 0, memberCode: 'GENERAL', currentPoints: 0,
              firstName: 'ลูกค้า', lastName: 'ทั่วไป (Walk-in)', phone: '');

      if (effectiveCustomer.id > 0) {
        try {
          final fresh = await _custRepo.getCustomerById(effectiveCustomer.id);
          if (fresh != null) effectiveCustomer = fresh;
        } catch (e) {
          debugPrint('⚠️ Failed to refresh customer: $e');
        }
      }

      final pdfData = await ReceiptService().generateDeliveryNoteData(
        orderId: orderId, items: currentItems, customer: effectiveCustomer,
        discount: discountAmount, vatAmount: vatAmount,
        grandTotalOverride: grandTotal,
        pageFormatOverride: PdfPageFormat(
            22.86 * PdfPageFormat.cm, 13.97 * PdfPageFormat.cm, marginAll: 0),
      );

      final bool isCredit = payments.any((p) =>
          p.method.toUpperCase().contains('CREDIT') ||
          p.method.contains('เงินเชื่อ') || p.method.contains('ลงบัญชี'));

      String note = !isCredit && received >= grandTotal - 0.01
          ? '✅ จ่ายเงินแล้ว (Paid)'
          : '📝 ลงบัญชี/เก็บปลายทาง (COD/Credit)';

      if (deliveryType == DeliveryType.pickup) note = '$note (รับเองที่ร้าน)';
      if (manualNote != null && manualNote.isNotEmpty) {
        note += '\nหมายเหตุ: $manualNote';
      }

      await _deliveryService.createDeliveryJob(
        orderId: orderId, customer: effectiveCustomer, items: currentItems,
        grandTotal: grandTotal, isManual: false, note: note,
        billPdfData: pdfData, vatAmount: vatAmount,
        paymentMethod: isCredit ? 'credit' : 'cash',
        jobType: deliveryType == DeliveryType.pickup ? 'pickup' : 'delivery',
      );
      debugPrint('✅ [Background] Delivery Job #$orderId created.');
    } catch (e) {
      debugPrint('⚠️ [Background] Delivery Job Failed: $e');
    }
  }
}
