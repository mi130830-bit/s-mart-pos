// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api, use_build_context_synchronously
part of '../product_form_dialog.dart';

extension ProductFormRightColumnExtension on _ProductFormDialogState {
  Widget _buildTabHeader(String title, bool isActive, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.transparent,
        border: isActive
            ? const Border(top: BorderSide(color: Colors.blue, width: 3))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 20,
              color: isActive ? Colors.blue[800] : Colors.grey[700],
            ),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? Colors.blue[800] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightColumnContent() {
    if (_activeTab == 4) return _buildSalesHistoryTab();
    if (_activeTab == 3) return _buildStockInHistoryTab();
    if (_activeTab == 2) return _buildUnitContent();
    if (_activeTab == 1) return _buildPriceTierContent();
    return _buildLinkageContent();
  }
}
