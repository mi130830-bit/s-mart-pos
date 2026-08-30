import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/online_order_model.dart';
import '../../models/customer.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/customer_repository.dart';
import '../../repositories/reward_repository.dart';
import '../../services/sales/coupon_eligibility_rules.dart';
import '../../state/navigation_provider.dart';
import '../../state/online_orders_provider.dart';
import '../pos/pos_state_manager.dart';
import '../../services/alert_service.dart';

class OnlineOrdersScreen extends ConsumerStatefulWidget {
  const OnlineOrdersScreen({super.key});

  @override
  ConsumerState<OnlineOrdersScreen> createState() => _OnlineOrdersScreenState();
}

class _OnlineOrdersScreenState extends ConsumerState<OnlineOrdersScreen> {
  final _currencyFormat = NumberFormat('#,##0.00', 'th_TH');
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'th_TH');

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onlineOrdersProvider);
    final notifier = ref.read(onlineOrdersProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        elevation: 1,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: const Icon(Icons.shopping_bag_outlined,
                  color: Color(0xFF059669), size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              'จัดการออเดอร์ออนไลน์ (LINE OA & Web)',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A)),
            ),
            const SizedBox(width: 12),
            if (state.pendingCount > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade600,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'รอตรวจสอบ ${state.pendingCount} รายการ',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code, color: Color(0xFF059669)),
            tooltip: 'เปิด QR Code หน้าร้านออนไลน์',
            onPressed: () => _showShopQrDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF64748B)),
            tooltip: 'รีเฟรชรายการ',
            onPressed: () => notifier.fetchOrders(),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs Bar
          _buildFilterTabs(state, notifier),

          // Main Content
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.orders.isEmpty
                    ? _buildEmptyState()
                    : _buildOrdersList(state.orders),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(
      OnlineOrdersState state, OnlineOrdersNotifier notifier) {
    final filters = [
      {'key': 'ALL', 'label': 'ทั้งหมด'},
      {'key': 'PENDING', 'label': 'รอตรวจสอบ', 'badge': state.pendingCount},
      {'key': 'CONFIRMED', 'label': 'ยืนยันแล้ว'},
      {'key': 'DISPATCHED', 'label': 'กำลังจัดส่ง'},
      {'key': 'COMPLETED', 'label': 'สำเร็จ'},
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: filters.map((f) {
          final isSelected = state.selectedFilter == f['key'];
          final badgeCount = f['badge'] as int? ?? 0;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    f['label'] as String,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color:
                          isSelected ? Colors.white : const Color(0xFF475569),
                    ),
                  ),
                  if (badgeCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badgeCount.toString(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? const Color(0xFF059669)
                              : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              selected: isSelected,
              selectedColor: const Color(0xFF059669),
              backgroundColor: const Color(0xFFF1F5F9),
              onSelected: (_) => notifier.setFilter(f['key'] as String),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox_outlined, size: 64, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 12),
          const Text(
            'ยังไม่มีรายการสั่งซื้อในหมวดหมู่นี้',
            style: TextStyle(
                fontSize: 16,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'เมื่อลูกค้าสั่งซื้อผ่าน LINE OA หรือ Web Shop รายการจะเด้งขึ้นที่นี่ทันที',
            style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList(List<OnlineOrder> orders) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        return _buildOrderCard(orders[index]);
      },
    );
  }

  Widget _buildOrderCard(OnlineOrder order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: order.isPending
              ? const Color(0xFFFCD34D)
              : const Color(0xFFE2E8F0),
          width: order.isPending ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: order.isPending
                  ? const Color(0xFFFFFBEB)
                  : const Color(0xFFF8FAFC),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(11)),
              border:
                  const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                _buildStatusBadge(order.status),
                const SizedBox(width: 10),
                Text(
                  order.orderNumber,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF1E293B)),
                ),
                const Spacer(),
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  _dateFormat.format(order.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),

          // Order Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer & Delivery Info Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Customer info
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person,
                                  size: 18, color: Color(0xFF059669)),
                              const SizedBox(width: 6),
                              Text(
                                order.customerName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              if (order.lineDisplayName.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '(LINE: ${order.lineDisplayName})',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.phone,
                                  size: 16, color: Color(0xFF64748B)),
                              const SizedBox(width: 6),
                              SelectableText(
                                order.customerPhone.isNotEmpty
                                    ? order.customerPhone
                                    : 'ไม่ระบุเบอร์',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: Color(0xFF2563EB)),
                              ),
                              if (order.customerPhone.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => _callPhone(order.customerPhone),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: const Color(0xFFBFDBFE)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.call,
                                            size: 12, color: Color(0xFF2563EB)),
                                        SizedBox(width: 4),
                                        Text('โทร',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF2563EB),
                                                fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Delivery Type & Address
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: order.isDelivery
                                      ? const Color(0xFFECFDF5)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: order.isDelivery
                                          ? const Color(0xFFA7F3D0)
                                          : const Color(0xFFCBD5E1)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      order.isDelivery
                                          ? Icons.local_shipping
                                          : Icons.store,
                                      size: 14,
                                      color: order.isDelivery
                                          ? const Color(0xFF059669)
                                          : const Color(0xFF475569),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      order.isDelivery
                                          ? 'จัดส่งถึงที่'
                                          : 'รับเองที่ร้าน',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: order.isDelivery
                                            ? const Color(0xFF059669)
                                            : const Color(0xFF475569),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (order.gpsLocation.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () => _openMap(order.gpsLocation),
                                  icon: const Icon(Icons.map,
                                      size: 14, color: Color(0xFF059669)),
                                  label: const Text('ดูแผนที่ GPS',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF059669))),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    side: const BorderSide(
                                        color: Color(0xFFA7F3D0)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (order.deliveryAddress.isNotEmpty &&
                              order.isDelivery) ...[
                            const SizedBox(height: 6),
                            Text(
                              '📍 ${order.deliveryAddress}',
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF334155)),
                            ),
                          ],
                          if (order.notes.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              '📝 หมายเหตุ: ${order.notes}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: Color(0xFF64748B)),
                            ),
                          ],
                          if (order.notes.contains('🎨') || order.notes.contains('สั่งผสมสี')) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF38BDF8)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.color_lens, size: 16, color: Color(0xFF0369A1)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '🎨 มีรายการสั่งผสมสี Beger Cool 2in1 (โปรดโทรแจ้งราคาลูกค้า: ${order.customerPhone})',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0369A1),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (order.notes.contains('เมทัลชีท') || 
                              order.notes.contains('สั่งตัด') || 
                              order.items.any((i) => i.name.contains('เมทัลชีท'))) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFDBA74)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.construction, size: 16, color: Color(0xFFC2410C)),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '🔨 มีรายการสั่งตัดเมทัลชีทตามขนาด (โปรดตรวจสอบความยาวและจำนวนแผ่นก่อนตัด)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFC2410C),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                const Divider(height: 24),

                // Items Table
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Row(
                          children: const [
                            Expanded(
                                flex: 6,
                                child: Text('รายการสินค้า',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF64748B)))),
                            Expanded(
                                flex: 2,
                                child: Text('จำนวน',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF64748B)))),
                            Expanded(
                                flex: 2,
                                child: Text('ราคา/หน่วย',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF64748B)))),
                            Expanded(
                                flex: 2,
                                child: Text('รวม',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF64748B)))),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      ...order.items.map((it) => Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                    flex: 6,
                                    child: Text(it.name,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600))),
                                Expanded(
                                    flex: 2,
                                    child: Text(it.quantity.toStringAsFixed(0),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 13))),
                                Expanded(
                                    flex: 2,
                                    child: Text(
                                        it.price <= 0 ? 'รอราคา' : '฿${_currencyFormat.format(it.price)}',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: it.price <= 0 ? const Color(0xFFD97706) : Colors.black87,
                                            fontWeight: it.price <= 0 ? FontWeight.bold : FontWeight.normal))),
                                Expanded(
                                    flex: 2,
                                    child: Text(
                                        it.subtotal <= 0 ? 'รอเช็คราคา' : '฿${_currencyFormat.format(it.subtotal)}',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: it.subtotal <= 0 ? const Color(0xFFD97706) : Colors.black87,
                                            fontWeight: FontWeight.bold))),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Price Summary Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            const Text('ยอดสินค้า: ',
                                style: TextStyle(
                                    fontSize: 13, color: Color(0xFF64748B))),
                            Text(
                                '฿${_currencyFormat.format(order.totalAmount)}',
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        if (order.isDelivery) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Text('ค่าจัดส่ง: ',
                                  style: TextStyle(
                                      fontSize: 13, color: Color(0xFF64748B))),
                              Text(
                                order.deliveryFee == 0
                                    ? '🟢 ฟรี'
                                    : '฿${_currencyFormat.format(order.deliveryFee)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: order.deliveryFee == 0
                                      ? const Color(0xFF059669)
                                      : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text('ยอดสุทธิ: ',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A))),
                            Text(
                              '฿${_currencyFormat.format(order.grandTotal)}',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF059669)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),

                const Divider(height: 24),

                // Actions Footer
                Row(
                  children: [
                    // Transfer to POS Cart Button (Hero Feature)
                    ElevatedButton.icon(
                      onPressed: () => _transferToPosCart(order),
                      icon: const Icon(Icons.shopping_cart_checkout, size: 16),
                      label: const Text('ดึงเข้าตะกร้าขาย (POS)',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                    const SizedBox(width: 8),

                    if (order.isPending) ...[
                      OutlinedButton.icon(
                        onPressed: () => _confirmOrderAction(order),
                        icon: const Icon(Icons.check_circle_outline,
                            size: 16, color: Color(0xFF2563EB)),
                        label: const Text('ยืนยันออเดอร์',
                            style: TextStyle(
                                color: Color(0xFF2563EB),
                                fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF93C5FD)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    if (order.isConfirmed && order.isDelivery) ...[
                      OutlinedButton.icon(
                        onPressed: () =>
                            _updateOrderStatus(order.id, 'DISPATCHED'),
                        icon: const Icon(Icons.local_shipping,
                            size: 16, color: Color(0xFFD97706)),
                        label: const Text('จัดของขึ้นรถ (Dispatched)',
                            style: TextStyle(
                                color: Color(0xFFD97706),
                                fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFDE68A)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    if (!order.isCompleted && !order.isCancelled) ...[
                      OutlinedButton.icon(
                        onPressed: () =>
                            _updateOrderStatus(order.id, 'COMPLETED'),
                        icon: const Icon(Icons.done_all,
                            size: 16, color: Color(0xFF059669)),
                        label: const Text('ปิดงานสำเร็จ',
                            style: TextStyle(
                                color: Color(0xFF059669),
                                fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFA7F3D0)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],

                    const Spacer(),

                    if (!order.isCancelled && !order.isCompleted)
                      TextButton.icon(
                        onPressed: () => _cancelOrderDialog(order.id),
                        icon: const Icon(Icons.cancel_outlined,
                            size: 16, color: Colors.red),
                        label: const Text('ยกเลิก',
                            style: TextStyle(color: Colors.red)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color text;
    String label;

    switch (status) {
      case 'PENDING':
        bg = const Color(0xFFFEF3C7);
        text = const Color(0xFF92400E);
        label = '⏳ รอตรวจสอบ';
        break;
      case 'CONFIRMED':
        bg = const Color(0xFFDBEAFE);
        text = const Color(0xFF1E40AF);
        label = '✅ ยืนยันแล้ว';
        break;
      case 'DISPATCHED':
        bg = const Color(0xFFFEF9C3);
        text = const Color(0xFF854D0E);
        label = '🚚 กำลังจัดส่ง';
        break;
      case 'COMPLETED':
        bg = const Color(0xFFDCFCE7);
        text = const Color(0xFF166534);
        label = '🎉 สำเร็จแล้ว';
        break;
      case 'CANCELLED':
        bg = const Color(0xFFFEE2E2);
        text = const Color(0xFF991B1B);
        label = '❌ ยกเลิก';
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        text = const Color(0xFF475569);
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: text),
      ),
    );
  }

  Future<void> _callPhone(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openMap(String location) async {
    final mapUrl = location.startsWith('http')
        ? location
        : 'https://www.google.com/maps?q=${Uri.encodeComponent(location)}';
    final uri = Uri.parse(mapUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _confirmOrderAction(OnlineOrder order) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shopping_cart_checkout,
                  color: Color(0xFF059669)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'ยืนยันออเดอร์ #${order.orderNumber}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ลูกค้า: ${order.customerName} (${order.customerPhone.isNotEmpty ? order.customerPhone : "ไม่ระบุเบอร์"})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'รูปแบบ: ${order.isDelivery ? "🚚 จัดส่งถึงที่" : "🏪 รับเองที่หน้าร้าน"} · ยอดรวม ฿${order.totalAmount.toStringAsFixed(2)}',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: Color(0xFF2563EB)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'ดึงรายการเข้าหน้าขาย (POS) เพื่อคิดเงินและตัดสต็อกสินค้า (งานส่งของจะเข้าระบบรอเลือกรถตอนปล่อยของครับ)',
                      style: TextStyle(fontSize: 12, color: Color(0xFF334155)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'CONFIRM_ONLY'),
            child: const Text('ยืนยันสถานะไว้ก่อน (ยังไม่เปิดบิล)',
                style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, 'TRANSFER_POS'),
            icon: const Icon(Icons.shopping_cart, size: 16),
            label: const Text('ดึงเข้า POS เพื่อเปิดบิลขาย',
                style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (result == 'TRANSFER_POS') {
      await _transferToPosCart(order);
    } else if (result == 'CONFIRM_ONLY') {
      final notifier = ref.read(onlineOrdersProvider.notifier);
      final success = await notifier.updateStatus(order.id, 'CONFIRMED');
      if (success && mounted) {
        AlertService.show(
          context: context,
          message: 'อัปเดตเป็นยืนยันแล้ว (รายการย้ายไปที่แท็บ "ยืนยันแล้ว")',
          type: 'info',
        );
      }
    }
  }

  Future<void> _updateOrderStatus(int orderId, String status) async {
    final notifier = ref.read(onlineOrdersProvider.notifier);
    final success = await notifier.updateStatus(orderId, status);
    if (success && mounted) {
      AlertService.show(
        context: context,
        message: 'อัปเดตสถานะเป็น $status เรียบร้อยแล้ว',
        type: 'success',
      );
    }
  }

  Future<void> _cancelOrderDialog(int orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันยกเลิกออเดอร์'),
        content: const Text('คุณต้องการยกเลิกคำสั่งซื้อนี้ใช่หรือไม่?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ไม่ยกเลิก')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('ยืนยันยกเลิก'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _updateOrderStatus(orderId, 'CANCELLED');
    }
  }

  Future<void> _transferToPosCart(OnlineOrder order) async {
    try {
      if (order.posOrderId != null) {
        throw StateError('ออเดอร์ออนไลน์นี้ถูกขายเข้า POS แล้ว');
      }
      final posNotifier = ref.read(posProvider.notifier);
      final productRepo = ProductRepository();

      // Clear existing cart
      await posNotifier.clearCart();

      // Load products and add to cart
      for (final item in order.items) {
        final product = await productRepo.getProductById(item.productId);
        if (product != null) {
          await posNotifier.addProductToCart(product, quantity: item.quantity);
        }
      }

      // Attach the canonical customer before applying any member benefit.
      Customer? matchedCustomer;
      final customerRepo = CustomerRepository();
      if (order.customerId != null && order.customerId! > 0) {
        matchedCustomer = await customerRepo.getCustomerById(order.customerId!);
      }
      if (matchedCustomer == null && order.customerPhone.isNotEmpty) {
        matchedCustomer =
            await customerRepo.getCustomerByPhone(order.customerPhone);
      }
      // If customer is not in database, create guest representation with order details
      matchedCustomer ??= Customer(
        id: 0,
        memberCode: 'ONLINE',
        firstName: order.customerName.isNotEmpty
            ? order.customerName
            : 'ลูกค้าออนไลน์',
        phone: order.customerPhone,
        address: order.deliveryAddress,
        shippingAddress: order.deliveryAddress,
        currentPoints: 0,
        lineUserId: order.lineUserId.isNotEmpty ? order.lineUserId : null,
        lineDisplayName:
            order.lineDisplayName.isNotEmpty ? order.lineDisplayName : null,
      );

      posNotifier.selectCustomer(matchedCustomer);

      String? couponWarning;
      final couponCode = order.couponCode?.trim().toUpperCase();
      if (couponCode != null && couponCode.isNotEmpty) {
        final customer = posNotifier.currentCustomer;
        if (customer == null || customer.id != order.customerId) {
          couponWarning =
              'ไม่ได้ใช้คูปองที่จองไว้ เพราะไม่พบสมาชิกเจ้าของคูปอง กรุณาตรวจสอบก่อนชำระเงิน';
          await posNotifier.attachOnlineOrderSource(order.id);
        } else {
          final validation = await RewardRepository().validateCoupon(
            couponCode,
            customerId: customer.id,
            sourceOnlineOrderId: order.id,
          );
          final discount = validation.discountValue ?? 0;
          final reservationMatches = validation.isValid &&
              validation.status == 'RESERVED' &&
              validation.reservedOnlineOrderId == order.id &&
              CouponEligibilityRules.discountMatches(
                  order.couponDiscount, discount);
          if (reservationMatches) {
            await posNotifier.attachOnlineOrderSource(
              order.id,
              reservedCouponCode: couponCode,
              reservedCouponDiscount: discount,
            );
          } else {
            couponWarning =
                'โหลดสินค้าแล้ว แต่ไม่ได้ใช้ส่วนลดคูปอง: ${validation.error ?? "ข้อมูลการจองไม่ตรงกับออเดอร์"}';
            await posNotifier.attachOnlineOrderSource(order.id);
          }
        }
      } else {
        await posNotifier.attachOnlineOrderSource(order.id);
      }

      // Navigate to POS Cashier Screen (Index 0)
      ref.read(mainNavigationProvider.notifier).state = 0;
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        AlertService.show(
          context: context,
          message: couponWarning ??
              'ดึงรายการออเดอร์ ${order.orderNumber} เข้าตะกร้า POS เรียบร้อยแล้ว',
          type: couponWarning == null ? 'success' : 'warning',
        );
      }
    } catch (e) {
      if (mounted) {
        AlertService.show(
          context: context,
          message: 'เกิดข้อผิดพลาดในการดึงรายการ: $e',
          type: 'error',
        );
      }
    }
  }

  void _showShopQrDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.qr_code_2, color: Color(0xFF059669)),
            SizedBox(width: 8),
            Text('QR Code หน้าร้านออนไลน์ (Web Shop)'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'ให้ลูกค้าสแกนเพื่อเปิดแค็ตตาล็อกสินค้าและสั่งซื้อบนมือถือได้ทันที',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Image.network(
                'https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=https://api.namecheap.work/shop/',
                width: 200,
                height: 200,
                loadingBuilder: (ctx, child, progress) => progress == null
                    ? child
                    : const SizedBox(
                        width: 200,
                        height: 200,
                        child: Center(child: CircularProgressIndicator())),
              ),
            ),
            const SizedBox(height: 12),
            const SelectableText(
              'https://api.namecheap.work/shop/',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF059669)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ปิด'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final uri = Uri.parse('https://api.namecheap.work/shop/');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('เปิดดูหน้าเว็บ'),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }
}
