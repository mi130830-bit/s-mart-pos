import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../customer_display_provider.dart';

class ItemListSection extends StatelessWidget {
  final CustomerDisplayState state;
  final String? shopName;
  final double fontSize;

  const ItemListSection({
    super.key,
    required this.state,
    required this.shopName,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    if (state.items.isEmpty) {
      return _buildIdleScreen();
    }

    return Column(
      children: [
        _buildTopBanner(),
        _buildTableHeader(),
        Expanded(child: _buildTableBody()),
      ],
    );
  }

  // ─────────────────────────────────────────────────────
  // Idle Screen (ยังไม่มีรายการ)
  // ─────────────────────────────────────────────────────
  Widget _buildIdleScreen() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shopping_basket_outlined,
                size: 60,
                color: const Color(0xFF1565C0).withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              shopName ?? 'ยินดีต้อนรับ',
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1565C0),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'ขอบคุณที่ใช้บริการ',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF90A4AE),
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // Top Banner (10% Space)
  // ─────────────────────────────────────────────────────
  Widget _buildTopBanner() {
    final bool isSuccess = state.mode == CustomerDisplayMode.success;

    return Container(
      height: 85, // About 10-12% of screen height
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isSuccess 
              ? [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)] // Green for success
              : [const Color(0xFFE3F2FD), const Color(0xFFBBDEFB)], // Blue for normal
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))
              ]
            ),
            child: Icon(
              isSuccess ? Icons.check_circle : Icons.store_mall_directory, 
              color: isSuccess ? Colors.green : const Color(0xFF1565C0), 
              size: 36
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isSuccess ? 'ขอบคุณที่ใช้บริการ' : (shopName ?? 'ยินดีต้อนรับ'),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: isSuccess ? Colors.green.shade800 : const Color(0xFF0D47A1),
                  ),
                ),
                Text(
                  isSuccess ? 'โอกาสหน้าเชิญใหม่ครับ/ค่ะ' : 'ยินดีให้บริการ',
                  style: TextStyle(
                    fontSize: 16,
                    color: isSuccess ? Colors.green.shade700 : const Color(0xFF1565C0),
                  ),
                ),
              ],
            ),
          ),
          // Decorative Promo Badge
          if (!isSuccess)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: const Row(
                children: [
                  Icon(Icons.stars, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Text('สินค้าคุณภาพ บริการด้วยใจ', style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // Table Header
  // ─────────────────────────────────────────────────────
  Widget _buildTableHeader() {
    final double headerFontSize = (fontSize * 0.85).clamp(11.0, 16.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
        ),
      ),
      child: Row(
        children: [
          // # ลำดับ
          SizedBox(
            width: 36,
            child: Text('#',
                style: _headerStyle(headerFontSize),
                textAlign: TextAlign.center),
          ),
          const SizedBox(width: 12),
          // ชื่อสินค้า
          Expanded(
            flex: 5,
            child: Text('รายการสินค้า',
                style: _headerStyle(headerFontSize)),
          ),
          // จำนวน
          SizedBox(
            width: 60,
            child: Text('จำนวน',
                style: _headerStyle(headerFontSize),
                textAlign: TextAlign.center),
          ),
          const SizedBox(width: 8),
          // ราคา/หน่วย
          SizedBox(
            width: 90,
            child: Text('ราคา/หน่วย',
                style: _headerStyle(headerFontSize),
                textAlign: TextAlign.right),
          ),
          const SizedBox(width: 8),
          // รวม
          SizedBox(
            width: 96,
            child: Text('รวม',
                style: _headerStyle(headerFontSize),
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  TextStyle _headerStyle(double size) => TextStyle(
        color: Colors.white,
        fontSize: size,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.3,
      );

  // ─────────────────────────────────────────────────────
  // Table Body
  // ─────────────────────────────────────────────────────
  Widget _buildTableBody() {
    final fmt = NumberFormat('#,##0.00');
    final double bodyFontSize = fontSize.clamp(12.0, 22.0);
    final double subFontSize = (fontSize * 0.78).clamp(10.0, 16.0);

    return ListView.builder(
      itemCount: state.items.length,
      itemBuilder: (context, index) {
        final item = state.items[index];
        final isEven = index % 2 == 0;
        final bool isLast = index == state.items.length - 1;

        final double qty = (item['qty'] as num?)?.toDouble() ?? 0;
        final double price = (item['price'] as num?)?.toDouble() ?? 0;
        final double total = (item['total'] as num?)?.toDouble() ?? 0;
        final String name = item['name'] as String? ?? '';
        final String? sku = item['sku'] as String?;

        return Container(
          decoration: BoxDecoration(
            color: isEven ? Colors.white : const Color(0xFFF5F8FF),
            border: Border(
              bottom: BorderSide(
                color: isLast ? Colors.transparent : const Color(0xFFE3EAF5),
                width: 1,
              ),
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: (bodyFontSize * 0.55).clamp(8.0, 16.0),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── # ลำดับ ──
              SizedBox(
                width: 36,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: subFontSize,
                    color: const Color(0xFF546E7A),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 12),

              // ── ชื่อสินค้า ──
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: bodyFontSize,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A237E),
                      ),
                    ),
                    if (sku != null && sku.isNotEmpty)
                      Text(
                        'รหัส: $sku',
                        style: TextStyle(
                          fontSize: subFontSize * 0.9,
                          color: const Color(0xFF90A4AE),
                        ),
                      ),
                  ],
                ),
              ),

              // ── จำนวน ──
              SizedBox(
                width: 60,
                child: Text(
                  _formatQty(qty),
                  style: TextStyle(
                    fontSize: bodyFontSize,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A237E),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 8),

              // ── ราคา/หน่วย ──
              SizedBox(
                width: 90,
                child: Text(
                  fmt.format(price),
                  style: TextStyle(
                    fontSize: subFontSize,
                    color: const Color(0xFF546E7A),
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 8),

              // ── รวม ──
              SizedBox(
                width: 96,
                child: Text(
                  fmt.format(total),
                  style: TextStyle(
                    fontSize: bodyFontSize,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1565C0),
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatQty(double qty) {
    if (qty == qty.truncateToDouble()) {
      return qty.toInt().toString();
    }
    return qty.toStringAsFixed(2);
  }
}
