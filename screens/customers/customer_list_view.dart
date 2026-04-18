import 'package:flutter/material.dart';

import '../../models/customer.dart';
import '../../repositories/customer_repository.dart';
import 'customer_history_screen.dart'; // ✅ Import หน้าประวัติการซื้อ
import 'customer_debtor_screen.dart'; // ✅ Import หน้าบัญชีลูกหนี้
import 'customer_form_dialog.dart'; // ✅ Import Dialog ที่แยกออกมา
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../services/alert_service.dart';

class CustomerListView extends StatefulWidget {
  const CustomerListView({super.key});

  @override
  State<CustomerListView> createState() => _CustomerListViewState();
}

class _CustomerListViewState extends State<CustomerListView> {
  final CustomerRepository _repo = CustomerRepository();
  bool _isLoading = true;
  List<Customer> _customers = [];

  // Pagination
  int _currentPage = 1;
  final int _pageSize = 15;
  int _totalItems = 0;

  // Search
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  // Filter
  bool _onlyDebtors = false;
  bool _onlyLineConnected = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final customers = await _repo.getCustomersPaginated(
        _currentPage,
        _pageSize,
        searchTerm: _searchQuery.isEmpty ? null : _searchQuery,
        onlyDebtors: _onlyDebtors,
        onlyLineConnected: _onlyLineConnected,
      );
      final total = await _repo.getCustomerCount(
        searchTerm: _searchQuery.isEmpty ? null : _searchQuery,
        onlyDebtors: _onlyDebtors,
        onlyLineConnected: _onlyLineConnected,
      );

      if (mounted) {
        setState(() {
          _customers = customers;
          _totalItems = total;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      _currentPage = 1; // Reset to page 1
      _loadData();
    }
  }

  void _toggleDebtorFilter(bool? val) {
    if (val != null) {
      setState(() {
        _onlyDebtors = val;
        _currentPage = 1;
      });
      _loadData();
    }
  }

  void _toggleLineFilter(bool? val) {
    if (val != null) {
      setState(() {
        _onlyLineConnected = val;
        _currentPage = 1;
      });
      _loadData();
    }
  }

  void _goToPage(int page) {
    setState(() {
      _currentPage = page;
    });
    _loadData();
  }

  Future<void> _showCustomerDialog([Customer? customer]) async {
    final result = await showDialog(
      context: context,
      builder: (context) => CustomerFormDialog(repo: _repo, customer: customer),
    );

    if (result != null) {
      _loadData();
      if (!mounted) return;
      AlertService.show(
          context: context, message: 'บันทึกข้อมูลสำเร็จ', type: 'success');
    }
  }

  Future<void> _deleteCustomer(Customer customer) async {
    // 1. Check if can delete
    final reason = await _repo.canDeleteCustomer(customer.id);
    if (!mounted) return;

    if (reason != null) {
      // ✅ Special Offer: If blocked but has Line ID, offer to Unlink
      if (customer.lineUserId != null) {
        final wantUnlink = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('ลบไม่ได้ (มีประวัติการซื้อ)'),
            content: Text(
                'ไม่สามารถลบ "${customer.firstName}" ได้เนื่องจากมีประวัติการซื้อขาย\n\nแต่ถ้าต้องการให้ลูกค้า **"สมัคร Line ใหม่"**\nคุณสามารถกดปุ่ม **"ปลดล็อค Line"** แทนได้ครับ'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('ยกเลิก')),
              ElevatedButton.icon(
                icon: const Icon(Icons.link_off),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                label: const Text('ปลดล็อค Line (Unlink)'),
              ),
            ],
          ),
        );

        if (wantUnlink == true) {
          final success = await _repo.unlinkLine(customer.id);
          if (!mounted) return;
          if (success) {
            _loadData();
            AlertService.show(
                context: context,
                message: 'ปลดล็อค Line เรียบร้อย! ลูกค้าสมัครใหม่ได้ทันที',
                type: 'success');
          } else {
            AlertService.show(
                context: context,
                message: 'เกิดข้อผิดพลาดในการปลดล็อค',
                type: 'error');
          }
        }
        return;
      }

      // Normal block
      ConfirmDialog.show(
        context,
        title: 'ไม่สามารถลบได้',
        content:
            'ไม่สามารถลบข้อมูล "${customer.firstName}" ได้เนื่องจาก:\n- $reason\n\nคำแนะนำ: คุณสามารถแก้ไขชื่อหรือข้อมูลแทนได้',
        confirmText: 'เข้าใจแล้ว',
        isDestructive: false,
      );
      return;
    }

    final reasonCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('คุณต้องการลบลูกค้า "${customer.firstName}" หรือไม่?'),
              const SizedBox(height: 16),
              TextFormField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'ระบุเหตุผลการลบ (บังคับ)',
                  border: OutlineInputBorder(),
                  hintText: 'เช่น เลิกกิจการ, ข้อมูลซ้ำ',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'กรุณาระบุเหตุผล';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'ข้อมูลจะถูกย้ายไปถังขยะ และลบถาวรใน 15 วัน',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('ลบลูกค้า'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _repo.deleteCustomer(customer.id,
          reason: reasonCtrl.text.trim());
      if (!mounted) return;

      if (success) {
        _loadData();
        AlertService.show(
          context: context,
          message: 'ลบลูกค้าเรียบร้อย (ย้ายไปถังขยะ)',
          type: 'success',
        );
      } else {
        AlertService.show(
          context: context,
          message: 'ลบไม่สำเร็จ (อาจมีข้อมูลเชื่อมโยง)',
          type: 'error',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Tools Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _searchCtrl,
                    label: 'ค้นหาชื่อ หรือ เบอร์โทร',
                    prefixIcon: Icons.search,
                    onChanged: _onSearchChanged,
                  ),
                ),
                const SizedBox(width: 10),
                FilterChip(
                  selected: _onlyDebtors,
                  showCheckmark: true,
                  label: const Text('เฉพาะที่มีหนี้'),
                  avatar: const Icon(Icons.money_off, size: 16),
                  selectedColor: Colors.red.shade100,
                  checkmarkColor: Colors.red,
                  onSelected: _toggleDebtorFilter,
                ),
                const SizedBox(width: 8),
                FilterChip(
                  selected: _onlyLineConnected,
                  showCheckmark: true,
                  label: const Text('เชื่อม Line แล้ว'),
                  avatar: const Icon(Icons.chat, size: 16, color: Colors.green),
                  selectedColor: Colors.green.shade100,
                  checkmarkColor: Colors.green,
                  onSelected: _toggleLineFilter,
                ),
              ],
            ),
          ),

          // Customer List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _customers.isEmpty
                    ? const Center(child: Text('ไม่พบข้อมูลลูกค้า'))
                    : ListView.separated(
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemCount: _customers.length,
                        itemBuilder: (context, index) {
                          final c = _customers[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.indigo.shade100,
                              child: Text(c.firstName.isNotEmpty
                                  ? c.firstName[0]
                                  : '?'),
                            ),
                            title: Row(
                              children: [
                                Text('${c.firstName} ${c.lastName ?? ""}'),
                                if (c.lineUserId != null) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.check_circle,
                                      color: Colors.green, size: 16),
                                  const SizedBox(width: 4),
                                  const Text('Line',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green)),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              'Tel: ${c.phone ?? "-"} | แต้ม: ${c.currentPoints}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (c.currentDebt > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: Text(
                                      'ค้างชำระ: ${c.currentDebt.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),

                                // 1. ดูประวัติ
                                IconButton(
                                  icon: const Icon(Icons.history,
                                      color: Colors.orange),
                                  tooltip: 'ดูประวัติการซื้อ',
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            CustomerHistoryScreen(customer: c),
                                      ),
                                    );
                                  },
                                ),

                                // 2. แก้ไข
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.blue),
                                  onPressed: () => _showCustomerDialog(c),
                                ),

                                // 3. ลบ
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () => _deleteCustomer(c),
                                ),
                              ],
                            ),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      CustomerDebtorScreen(customer: c),
                                ),
                              );
                              _loadData();
                            },
                          );
                        },
                      ),
          ),

          // Pagination Controls
          if (!_isLoading && _totalItems > 0)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: const Border(top: BorderSide(color: Colors.grey)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('ทั้งหมด $_totalItems รายการ'),
                  const SizedBox(width: 20),
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _currentPage > 1
                        ? () => _goToPage(_currentPage - 1)
                        : null,
                  ),
                  Text(
                      'หน้า $_currentPage / ${(_totalItems / _pageSize).ceil() == 0 ? 1 : (_totalItems / _pageSize).ceil()}'),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _currentPage < (_totalItems / _pageSize).ceil()
                        ? () => _goToPage(_currentPage + 1)
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCustomerDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
