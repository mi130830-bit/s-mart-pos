import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../state/auth_provider.dart';
import '../../../state/shortage_provider.dart';
import '../../../services/alert_service.dart';
import '../../../models/shortage_log_model.dart';

class StockAlertEntryForm extends StatefulWidget {
  const StockAlertEntryForm({super.key});

  @override
  State<StockAlertEntryForm> createState() => _StockAlertEntryFormState();
}

class _StockAlertEntryFormState extends State<StockAlertEntryForm> {
  final _itemController = TextEditingController();
  final List<String> _pendingItems = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _itemController.dispose();
    super.dispose();
  }

  void _addItemToPending() {
    final text = _itemController.text.trim();
    if (text.isNotEmpty) {
      final cleanText = text.replaceAll(RegExp(r'\s*\(คงเหลือ:.*?\)'), '').trim().toLowerCase();

      if (_pendingItems.any((item) => item.replaceAll(RegExp(r'\s*\(คงเหลือ:.*?\)'), '').trim().toLowerCase() == cleanText)) {
        AlertService.show(
          context: context,
          message: 'มีรายการนี้ในคิวที่รอเตรียมบันทึกแล้ว',
          type: 'warning',
        );
        _itemController.clear();
        return;
      }

      final provider = Provider.of<ShortageProvider>(context, listen: false);
      final isAlreadyOpen = provider.openShortages.any((alert) {
        final alertCleanName = alert.itemName.replaceAll(RegExp(r'\s*\(คงเหลือ:.*?\)'), '').trim().toLowerCase();
        return alertCleanName == cleanText;
      });

      if (isAlreadyOpen) {
        AlertService.show(
          context: context,
          message: 'สินค้านี้ถูกแจ้งเตือนไว้แล้วและกำลังรอจัดการ',
          type: 'warning',
        );
        _itemController.clear();
        return;
      }

      setState(() {
        _pendingItems.add(text);
        _itemController.clear();
      });
    }
  }

  void _removeItemFromPending(int index) {
    setState(() {
      _pendingItems.removeAt(index);
    });
  }

  Future<void> _submitAll() async {
    if (_pendingItems.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      final provider = Provider.of<ShortageProvider>(context, listen: false);
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final user = auth.currentUser;

      final futures =
          _pendingItems.map((item) => provider.createShortage(item, user));
      await Future.wait(futures);

      if (mounted) {
        AlertService.show(
          context: context,
          message: 'แจ้งเตือน ${_pendingItems.length} รายการเรียบร้อย!',
          type: 'success',
        );
        setState(() {
          _pendingItems.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        AlertService.show(
          context: context,
          message: 'Error: $e',
          type: 'error',
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ShortageProvider>(context);
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Autocomplete<ProductSearchResult>(
            optionsBuilder: (textEditingValue) async {
              if (textEditingValue.text.isEmpty) {
                return const Iterable<ProductSearchResult>.empty();
              }
              return await provider.searchProducts(textEditingValue.text);
            },
            displayStringForOption: (option) => option.toString(),
            onSelected: (selection) {
              _itemController.text = selection.toString();
              _addItemToPending();
            },
            fieldViewBuilder:
                (context, textController, focusNode, onFieldSubmitted) {
              return Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: textController,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        hintText: 'ค้นหาสินค้า / พิมพ์ชื่อสินค้าที่หมด...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                      ),
                      onSubmitted: (val) {
                        _itemController.text = val;
                        _addItemToPending();
                        textController.clear();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () {
                      _itemController.text = textController.text;
                      _addItemToPending();
                      textController.clear();
                    },
                    icon: const Icon(Icons.add),
                    style:
                        IconButton.styleFrom(backgroundColor: Colors.teal),
                  ),
                ],
              );
            },
          ),
          if (_pendingItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: _pendingItems.asMap().entries.map((entry) {
                return InputChip(
                  label: Text(entry.value),
                  onDeleted: () => _removeItemFromPending(entry.key),
                  backgroundColor: Colors.teal.shade50,
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitAll,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send),
                label: Text(_isSubmitting
                    ? 'กำลังบันทึก...'
                    : 'บันทึกแจ้งเตือน (${_pendingItems.length})'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
