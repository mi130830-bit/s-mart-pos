import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_desktop/repositories/sales_repository.dart';
import 'package:flutter/foundation.dart';

void main() {
  test('Analyze Sales Data', () async {
    // Mock SharedPreferences with default credentials
    SharedPreferences.setMockInitialValues({
      'db_host': '192.168.1.139',
      'db_port': 3306,
      'db_user': 'admin',
      'db_pass': '1234',
      'db_name': 'sorborikan',
    });

    final repo = SalesRepository();

    // Helper to print section
    void printSection(String title) {
      debugPrint('\n${'=' * 50}');
      debugPrint('  $title');
      debugPrint('=' * 50);
    }

    // 1. Analyze 2026-01-10 (Hero Day)
    printSection('ANALYSIS: 2026-01-10 (Hero Day)');
    final start10 = DateTime(2026, 1, 10, 0, 0, 0);
    final end10 = DateTime(2026, 1, 10, 23, 59, 59);

    // Test Limit 5
    final top5 = await repo.getTopProductsByDateRange(start10, end10, limit: 5);
    debugPrint('--- Top 5 Products (Limit Test) ---');
    for (var p in top5) {
      debugPrint('${p['name']}: Qty ${p['qty']}, Total ${p['totalSales']}');
    }

    final topProducts10 = await repo.getTopProductsByDateRange(start10, end10);
    debugPrint('--- Top 10 Products ---');
    for (var p in topProducts10) {
      debugPrint('${p['name']}: Qty ${p['qty']}, Total ${p['totalSales']}');
    }

    // Get detailed items for more breakdown if needed
    final details10 = await repo.getDetailedOrdersForExport(start10, end10);
    // Group by hour to see peak time
    Map<int, double> hourlySales10 = {};
    for (var row in details10) {
      final createdAtRaw = row['createdAt'];
      final dt = createdAtRaw is DateTime
          ? createdAtRaw
          : DateTime.parse(createdAtRaw.toString());
      final total = double.tryParse(row['amount'].toString()) ?? 0.0;
      hourlySales10[dt.hour] = (hourlySales10[dt.hour] ?? 0) + total;
    }
    debugPrint('\n--- Hourly Sales (Hour: Amount) ---');
    var sortedKeys10 = hourlySales10.keys.toList()..sort();
    for (var h in sortedKeys10) {
      debugPrint(
          '$h:00 - ${h + 1}:00 : ${hourlySales10[h]?.toStringAsFixed(2)}');
    }

    // Check payment methods for Jan 10
    final payments10 = await repo.getPaymentMethodStats(start10, end10);
    debugPrint('\n--- Payment Methods (Jan 10) ---');
    for (var p in payments10) {
      debugPrint('${p['method']}: ${p['total']}');
    }

    // 2. Analyze 2026-01-09 (Quiet Day)
    printSection('ANALYSIS: 2026-01-09 (Quiet Day)');
    final start9 = DateTime(2026, 1, 9, 0, 0, 0);
    final end9 = DateTime(2026, 1, 9, 23, 59, 59);

    final topProducts9 = await repo.getTopProductsByDateRange(start9, end9);
    debugPrint('--- Top Products ---');
    if (topProducts9.isEmpty) debugPrint('No sales found.');
    for (var p in topProducts9) {
      debugPrint('${p['name']}: Qty ${p['qty']}, Total ${p['totalSales']}');
    }

    final payments9 = await repo.getPaymentMethodStats(start9, end9);
    debugPrint('\n--- Payment Methods (Jan 9) ---');
    for (var p in payments9) {
      debugPrint('${p['method']}: ${p['total']}');
    }
  });
}
