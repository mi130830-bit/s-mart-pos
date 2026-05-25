part of '../pos_state_manager.dart';

/// Extension สำหรับโหมดแก้ไขบิล UNPAID
/// เพิ่มเข้ามาโดยไม่แตะ Logic การขายปกติเดิม
extension PosEditOrderExtension on PosStateNotifier {
  // ── Internal state getters/setters ────────────────────────────────────────
  bool get isEditing => _editingOrderId != null;
  int? get editingOrderId => _editingOrderId;

  /// โหลดบิล UNPAID เข้าตะกร้า เพื่อเข้าสู่โหมดแก้ไข
  Future<bool> loadOrderForEditing(int orderId) async {
    try {
      final data = await _salesRepo.getOrderForEdit(orderId);
      if (data == null) return false;

      final orderMap = data['order'] as Map<String, dynamic>;
      final itemsRaw = data['items'] as List<Map<String, dynamic>>;

      // โหลดลูกค้าจากบิลเดิม (ล็อกไว้ ไม่ให้เปลี่ยน)
      final custId = int.tryParse(orderMap['customerId']?.toString() ?? '0') ?? 0;
      Customer? customer;
      if (custId > 0) {
        customer = await _custRepo.getCustomerById(custId);
      }

      // แปลงรายการสินค้าเป็น OrderItem
      final List<OrderItem> items = itemsRaw.map((row) {
        return OrderItem(
          productId: int.tryParse(row['productId'].toString()) ?? 0,
          productName: row['productName']?.toString() ?? '',
          quantity: Decimal.parse(row['quantity'].toString()),
          price: Decimal.parse(row['price'].toString()),
          discount: Decimal.parse(row['discount']?.toString() ?? '0'),
          total: Decimal.parse(row['total'].toString()),
          conversionFactor: double.tryParse(row['conversionFactor']?.toString() ?? '1') ?? 1.0,
        );
      }).toList();

      // ล้างตะกร้าเดิมและโหลดรายการจากบิล
      _cartService.setCart(items);
      _currentCustomer = customer;
      _billDiscount = double.tryParse(orderMap['discount']?.toString() ?? '0') ?? 0.0;
      _isPercentDiscount = false;
      _extraBillDiscount = 0.0;
      _editingOrderId = orderId;
      _editingOldStatus = orderMap['status']?.toString().toUpperCase();
      _editingOldGrandTotal = double.tryParse(orderMap['grandTotal']?.toString() ?? '0') ?? 0.0;

      _invalidateCalcCache();
      _notify();
      return true;
    } catch (e) {
      debugPrint('❌ [PosEditOrder] Error loading order #$orderId for edit: $e');
      return false;
    }
  }

  /// ออกจากโหมดแก้ไข และล้างตะกร้า
  Future<void> cancelOrderEditing() async {
    _editingOrderId = null;
    _editingOldStatus = null;
    _editingOldGrandTotal = 0.0;
    await clearCart(returnStock: false);
    _currentCustomer = null;
    _billDiscount = 0.0;
    _isPercentDiscount = false;
    _extraBillDiscount = 0.0;
    _invalidateCalcCache();
    _notify();
  }

  /// บันทึกการแก้ไขบิล (เรียกแทน saveOrder เมื่ออยู่ใน editingOrderId mode)
  Future<int> saveOrderAsEdit() async {
    final oid = _editingOrderId;
    if (oid == null) throw Exception('ไม่ได้อยู่ในโหมดแก้ไขบิล');

    await _salesRepo.updateEditedOrder(
      orderId: oid,
      newItems: cart,
      newTotal: total,
      newDiscountAmount: discountAmount,
      newGrandTotal: grandTotal,
    );

    // ✅ อัปเดตรายการใหม่ไปที่ Cloud จัดส่ง (เฉพาะบิลที่ส่งของแล้ว)
    try {
      await _deliveryService.updateDeliveryJobItems(
        orderId: oid,
        items: cart,
        grandTotal: grandTotal,
        oldStatus: _editingOldStatus,
        oldGrandTotal: _editingOldGrandTotal,
      );
    } catch (e) {
      debugPrint('❌ [PosEditOrder] Error sync update to delivery job: $e');
    }

    // รีเซ็ต editing state และล้างตะกร้า
    _editingOrderId = null;
    _editingOldStatus = null;
    _editingOldGrandTotal = 0.0;
    final currentItems = List<OrderItem>.from(cart);
    final currentCust = _currentCustomer;
    final currentTotal = grandTotal;

    _lastOrder = LastOrderInfo(
      orderId: oid,
      items: currentItems,
      customer: currentCust,
      grandTotal: currentTotal,
      received: 0,
      change: 0,
      paymentMethod: 'ค้างชำระ',
      discountAmount: discountAmount,
      payments: [],
      orderTime: DateTime.now(),
    );

    await clearCart(returnStock: false);
    _notify();
    return oid;
  }
}
