import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_buttons.dart';
import '../../state/online_orders_provider.dart';
import '../online_orders/online_orders_screen.dart';

class PosControlBar extends ConsumerWidget {
  final TextEditingController barcodeCtrl;
  final TextEditingController qtyCtrl;
  final FocusNode barcodeFocusNode;
  final Function(String) onScan;
  final VoidCallback onSearch;
  final VoidCallback? onQtyTap;

  const PosControlBar({
    super.key,
    required this.barcodeCtrl,
    required this.qtyCtrl,
    required this.barcodeFocusNode,
    required this.onScan,
    required this.onSearch,
    this.onQtyTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingCount = ref.watch(onlineOrdersPendingCountProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          // 1. ช่องสแกนบาร์โค้ด
          Expanded(
            child: SizedBox(
              height: 47,
              child: CustomTextField(
                controller: barcodeCtrl,
                focusNode: barcodeFocusNode,
                hint: 'สแกนบาร์โค้ด หรือพิมพ์ชื่อสินค้า (Enter เพื่อค้นหา)',
                prefixIcon: Icons.qr_code_scanner,
                onSubmitted: onScan,
                filled: true,
                fillColor: Theme.of(context).inputDecorationTheme.fillColor,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 2. ปุ่มค้นหาสินค้า
          SizedBox(
            height: 47,
            child: CustomButton(
              label: 'ค้นหา (F3)',
              icon: Icons.search,
              onPressed: onSearch,
            ),
          ),
          const SizedBox(width: 8),

          // 3. ช่องจำนวน (Quantity)
          SizedBox(
            width: 100,
            height: 47,
            child: InkWell(
              onTap: onQtyTap,
              borderRadius: BorderRadius.circular(8),
              child: CustomTextField(
                controller: qtyCtrl,
                hint: 'จำนวน',
                prefixIcon: Icons.numbers,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                filled: true,
                fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 4. ปุ่มลัด [ 💬 ออเดอร์ออนไลน์ ]
          SizedBox(
            height: 47,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const OnlineOrdersScreen(),
                  ),
                );
              },
              icon: pendingCount > 0
                  ? Badge(
                      label: Text(pendingCount.toString()),
                      backgroundColor: Colors.red,
                      child: const Icon(Icons.shopping_bag, size: 18),
                    )
                  : const Icon(Icons.shopping_bag_outlined, size: 18),
              label: Text(
                pendingCount > 0 ? 'ออเดอร์ใหม่ ($pendingCount)' : 'ออเดอร์ออนไลน์',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: pendingCount > 0 ? Colors.white : const Color(0xFF059669),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: pendingCount > 0 ? Colors.red.shade600 : const Color(0xFFECFDF5),
                foregroundColor: pendingCount > 0 ? Colors.white : const Color(0xFF059669),
                side: BorderSide(color: pendingCount > 0 ? Colors.red.shade700 : const Color(0xFFA7F3D0)),
                elevation: pendingCount > 0 ? 3 : 0,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // 5. ปุ่ม QR Web Shop
          SizedBox(
            height: 47,
            width: 47,
            child: IconButton(
              icon: const Icon(Icons.qr_code_2, color: Color(0xFF059669)),
              tooltip: 'QR Code หน้าร้านออนไลน์',
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF0FDF4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xFFA7F3D0)),
                ),
              ),
              onPressed: () => _showShopQr(context),
            ),
          ),
        ],
      ),
    );
  }

  void _showShopQr(BuildContext context) {
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
                    : const SizedBox(width: 200, height: 200, child: Center(child: CircularProgressIndicator())),
              ),
            ),
            const SizedBox(height: 12),
            const SelectableText(
              'https://api.namecheap.work/shop/',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }
}
