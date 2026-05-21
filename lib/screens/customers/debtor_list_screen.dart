import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../../models/customer.dart';
import 'customer_debtor_screen.dart';
import '../pos/pos_state_manager.dart'; // For delivery
import '../../services/alert_service.dart';

// Refactored Sub-widgets and Dialogs
import 'widgets/debtor/debtor_summary_card.dart';
import 'widgets/debtor/debtor_filter_panel.dart';
import 'widgets/debtor/debtor_table_header.dart';
import 'widgets/debtor/debtor_table_row.dart';
import 'dialogs/debtor/debtor_dialogs.dart';
import 'controllers/debtor_list_controller.dart';

class DebtorListScreen extends StatelessWidget {
  const DebtorListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _DebtorListScreenContent();
  }
}

class _DebtorListScreenContent extends ConsumerStatefulWidget {
  const _DebtorListScreenContent();

  @override
  ConsumerState<_DebtorListScreenContent> createState() => _DebtorListScreenContentState();
}

class _DebtorListScreenContentState extends ConsumerState<_DebtorListScreenContent> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _showPrintOptions(BuildContext context, DebtorListController controller, int orderId) async {
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('เลือกประเภทเอกสาร'),
          children: [
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                controller.executePrint(context, orderId, 'RECEIPT');
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long, color: Colors.blue),
                    SizedBox(width: 12),
                    Text('ใบเสร็จรับเงิน (Receipt)', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
            const Divider(),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                controller.executePrint(context, orderId, 'DELIVERY');
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Icon(Icons.local_shipping, color: Colors.orange),
                    SizedBox(width: 12),
                    Text('ใบส่งของ (Delivery Note)', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
            const Divider(),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                controller.executePrint(context, orderId, 'SAVE_RECEIPT_PDF');
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, color: Colors.red),
                    SizedBox(width: 12),
                    Text('ดาวน์โหลดใบเสร็จ (PDF)', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                controller.executePrint(context, orderId, 'SAVE_DELIVERY_PDF');
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, color: Colors.red),
                    SizedBox(width: 12),
                    Text('ดาวน์โหลดใบส่งของ (PDF)', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmBulkAlerts(BuildContext context, DebtorListController controller) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันส่งทวงหนี้'),
        content: const Text(
            'ระบบจะส่งข้อความแจ้งเตือนยอดหนี้ทาง LINE ให้กับลูกหนี้ทุกคนที่มี Line ID (ไม่มีค่าใช้จ่ายเพิ่ม)\nคุณต้องการดำเนินการต่อหรือไม่?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('ส่งทันที (Send)')),
        ],
      ),
    );

    if (confirm == true) {
      if (!context.mounted) return;
      controller.sendBulkDebtAlerts(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(debtorListProvider);
    final controller = ref.read(debtorListProvider.notifier);

    return Column(
      children: [
        DebtorSummaryCard(
          totalDebt: state.summaryTotalDebt,
          debtorCount: state.summaryDebtorCount,
          billCount: state.allTransactions.length,
          isSendingAlerts: state.isSendingAlerts,
          onSendBulkAlerts: () => _confirmBulkAlerts(context, controller),
        ),
        DebtorFilterPanel(
          searchCtrl: _searchCtrl,
          onSearch: controller.onSearch,
          sortOption: state.sortOption,
          onSortOptionChanged: (val) {
            if (val != null) {
              controller.setSortOption(val);
            }
          },
        ),
        const SizedBox(height: 16),
        const DebtorTableHeader(),
        Expanded(
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : state.filteredTransactions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.check_circle_outline,
                              size: 64, color: Colors.green),
                          SizedBox(height: 10),
                          Text('ไม่พบรายการค้างชำระ',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: state.filteredTransactions.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1),
                      itemBuilder: (ctx, index) {
                        final t = state.filteredTransactions[index];
                        return DebtorTableRow(
                          index: index,
                          bill: t,
                          onPayPressed: () => DebtorDialogs.showPaymentDialog(
                            context: context,
                            orderId: t.orderId,
                            remainingAmount: t.remaining,
                            debtorRepo: controller.debtorRepo,
                            onSuccess: controller.loadData,
                          ),
                          onViewLedgerPressed: () async {
                            final customer = Customer(
                              id: t.customerId,
                              firstName: t.customerName,
                              lastName: '',
                              phone: t.phone,
                              currentDebt: t.currentDebt,
                              memberCode: 'TEMP',
                              currentPoints: 0,
                            );

                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    CustomerDebtorScreen(customer: customer),
                              ),
                            );
                            controller.loadData(); // Refresh on return
                          },
                          onViewDetailsPressed: () => DebtorDialogs.showBillDetails(
                            context: context,
                            orderId: t.orderId,
                            salesRepo: controller.salesRepo,
                          ),
                          onPrintPressed: () => _showPrintOptions(context, controller, t.orderId),
                          onDeliveryPressed: () async {
                            try {
                              final posState = ref.read(posProvider.notifier);
                              await posState.sendToDeliveryFromHistory(t.orderId);
                              if (!context.mounted) return;
                              AlertService.show(
                                context: context,
                                message: 'ส่งข้อมูลจัดส่งสำเร็จ!',
                                type: 'success',
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              AlertService.show(
                                context: context,
                                message: 'Error: $e',
                                type: 'error',
                              );
                            }
                          },
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
