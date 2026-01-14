import 'package:flutter/material.dart';

import '../../models/customer.dart';
import '../../repositories/customer_repository.dart';
import 'customer_history_screen.dart'; // ✅ Import หน้าประวัติการซื้อ
import 'customer_debtor_screen.dart'; // ✅ Import หน้าบัญชีลูกหนี้
import 'customer_form_dialog.dart'; // ✅ Import Dialog ที่แยกออกมา
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/confirm_dialog.dart';

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
      );
      final total = await _repo.getCustomerCount(
        searchTerm: _searchQuery.isEmpty ? null : _searchQuery,
        onlyDebtors: _onlyDebtors,
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

  void _toggleFilter(bool? val) {
    if (val != null) {
      setState(() {
        _onlyDebtors = val;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('บันทึกข้อมูลสำเร็จ'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _deleteCustomer(Customer customer) async {
    // 1. Check if can delete
    final reason = await _repo.canDeleteCustomer(customer.id);
    if (!mounted) return;

    if (reason != null) {
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

    final confirm = await ConfirmDialog.show(
      context,
      title: 'ยืนยันการลบ',
      content: 'คุณต้องการลบลูกค้า "${customer.firstName}" หรือไม่?',
      confirmText: 'ลบ',
      cancelText: 'ยกเลิก',
      isDestructive: true,
    );

    if (confirm == true) {
      final success = await _repo.deleteCustomer(customer.id);
      if (!mounted) return;

      if (success) {
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ลบลูกค้าเรียบร้อย'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ลบไม่สำเร็จ (อาจมีข้อมูลเชื่อมโยง)'),
            backgroundColor: Colors.red,
          ),
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
                  onSelected: _toggleFilter,
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
                            title: Text('${c.firstName} ${c.lastName ?? ""}'),
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
