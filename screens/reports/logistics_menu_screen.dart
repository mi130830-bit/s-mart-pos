import 'package:flutter/material.dart';
import '../../services/integration/delivery_integration_service.dart';
import 'delivery_dashboard_screen.dart';
import 'delivery_report_screen.dart';

class LogisticsMenuScreen extends StatelessWidget {
  final DeliveryIntegrationService? deliveryService;

  const LogisticsMenuScreen({super.key, this.deliveryService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ระบบขนส่ง (Logistics)'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'เลือกเมนูที่ต้องการ',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  children: [
                    SizedBox(
                      width: 260,
                      height: 250,
                      child: _buildMenuCard(
                        context,
                        title: 'ติดตามงานส่ง',
                        subtitle: 'ดูภาพรวมงานขนส่งรายวัน, ค่าน้ำมัน, และสถานะรถ',
                        icon: Icons.dashboard_outlined,
                        color: Colors.blue,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DeliveryDashboardScreen(
                                deliveryService: deliveryService,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      width: 260,
                      height: 250,
                      child: _buildMenuCard(
                        context,
                        title: 'รายงานขนส่ง',
                        subtitle: 'ดูประวัติการขนส่งย้อนหลังพร้อมส่งออกเป็น Excel',
                        icon: Icons.local_shipping_outlined,
                        color: Colors.green,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DeliveryReportScreen(
                                deliveryService: deliveryService,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: color.withValues(alpha: 0.2),
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: color, width: 6)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 48, color: color),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
