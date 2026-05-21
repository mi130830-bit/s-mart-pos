import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../models/customer.dart';
import '../../../../models/debtor_transaction.dart';
import '../../../../models/member_tier.dart';

/// Tab แสดงข้อมูลโปรไฟล์ลูกค้า
class CustomerDebtorProfileTab extends StatelessWidget {
  final Customer currentCustomer;
  final List<MemberTier> tiers;
  final List<DebtorTransaction> ledger;

  const CustomerDebtorProfileTab({
    super.key,
    required this.currentCustomer,
    required this.tiers,
    required this.ledger,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic Info Card
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildHeader(),
                  const Divider(height: 32),
                  _buildProfileRow(Icons.phone, 'เบอร์โทรศัพท์',
                      currentCustomer.phone?.isNotEmpty == true
                          ? currentCustomer.phone!
                          : '-'),
                  _buildProfileRow(
                      Icons.cake,
                      'วันเกิด',
                      currentCustomer.dateOfBirth != null
                          ? DateFormat('dd/MM/yyyy')
                              .format(currentCustomer.dateOfBirth!)
                          : '-'),
                  _buildProfileRow(
                      Icons.event_busy,
                      'หมดอายุสมาชิก',
                      currentCustomer.membershipExpiryDate != null
                          ? DateFormat('dd/MM/yyyy')
                              .format(currentCustomer.membershipExpiryDate!)
                          : '-'),
                  _buildProfileRow(
                      Icons.badge_outlined,
                      'เลขบัตรประชาชน',
                      currentCustomer.nationalId?.isNotEmpty == true
                          ? currentCustomer.nationalId!
                          : '-'),
                  _buildProfileRow(
                      Icons.receipt_long_outlined,
                      'เลขผู้เสียภาษี',
                      currentCustomer.taxId?.isNotEmpty == true
                          ? currentCustomer.taxId!
                          : '-'),
                  _buildProfileRow(
                      Icons.location_on,
                      'ที่อยู่ตามบัตรประชาชน',
                      currentCustomer.address?.isNotEmpty == true
                          ? currentCustomer.address!
                          : '-'),
                  _buildProfileRow(
                      Icons.local_shipping,
                      'ที่อยู่จัดส่งสินค้า',
                      currentCustomer.shippingAddress?.isNotEmpty == true
                          ? currentCustomer.shippingAddress!
                          : '-'),
                  _buildProfileRow(
                      Icons.note,
                      'หมายเหตุ',
                      currentCustomer.remarks?.isNotEmpty == true
                          ? currentCustomer.remarks!
                          : '-'),
                  const Divider(height: 32),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('สถิติ (Statistics)',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.indigo)),
                  ),
                  const SizedBox(height: 12),
                  _buildProfileRow(
                      Icons.star,
                      'คะแนนสะสม',
                      '${NumberFormat('#,##0').format(currentCustomer.currentPoints)} แต้ม',
                      valueColor: Colors.orange,
                      isBold: true),
                  _buildProfileRow(
                      Icons.shopping_bag,
                      'ยอดซื้อรวม',
                      '${NumberFormat('#,##0.00').format(currentCustomer.totalSpending)} บาท',
                      valueColor: Colors.green,
                      isBold: true),
                  _buildProfileRow(
                      Icons.money_off,
                      'ยอดหนี้ค้างชำระ',
                      '${NumberFormat('#,##0.00').format(currentCustomer.currentDebt)} บาท',
                      valueColor: Colors.red,
                      isBold: true),
                  if (currentCustomer.lineUserId != null) ...[
                    const Divider(height: 32),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Line Official CRM',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.green)),
                    ),
                    const SizedBox(height: 12),
                    _buildLineSection(),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('ประวัติย่อ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
            'ลูกค้าเริ่มเปิดบัญชีเมื่อ: ${ledger.isNotEmpty ? DateFormat('dd/MM/yyyy').format(ledger.last.createdAt) : "-"}',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    String tierName = 'ทั่วไป (General)';
    if (currentCustomer.tierId != null) {
      final t = tiers
          .where((t) => t.id == currentCustomer.tierId)
          .firstOrNull;
      if (t != null) {
        tierName = '${t.name} (ลด ${t.discountPercentage}%)';
      }
    }

    return Row(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: Colors.blue.shade50,
          child: Text(
            currentCustomer.firstName.isNotEmpty
                ? currentCustomer.firstName[0]
                : '?',
            style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.blue),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${currentCustomer.firstName} ${currentCustomer.lastName ?? ""}',
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  if (currentCustomer.lineUserId != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.green, size: 16),
                          SizedBox(width: 4),
                          Text('LINE OA',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'รหัสสมาชิก: ${currentCustomer.memberCode.isEmpty ? "-" : currentCustomer.memberCode}',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 2),
              Text(
                'ระดับสมาชิก: $tierName',
                style: const TextStyle(
                    color: Colors.indigo,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLineSection() {
    return Row(
      children: [
        CircleAvatar(
          backgroundImage: currentCustomer.linePictureUrl != null
              ? NetworkImage(currentCustomer.linePictureUrl!)
              : null,
          backgroundColor: Colors.grey.shade200,
          child: currentCustomer.linePictureUrl == null
              ? const Icon(Icons.person, color: Colors.grey)
              : null,
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(currentCustomer.lineDisplayName ?? 'Unknown',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              'Line ID: ...${currentCustomer.lineUserId!.substring(currentCustomer.lineUserId!.length > 4 ? currentCustomer.lineUserId!.length - 4 : 0)}',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfileRow(IconData icon, String label, String value,
      {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
