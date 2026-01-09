import 'package:flutter/material.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_buttons.dart';

class PosControlBar extends StatelessWidget {
  final TextEditingController barcodeCtrl;
  final TextEditingController qtyCtrl;
  final FocusNode barcodeFocusNode;
  final Function(String) onScan;
  final VoidCallback onSearch;
  // final VoidCallback onReset; // ❌ Removed as requested

  const PosControlBar({
    super.key,
    required this.barcodeCtrl,
    required this.qtyCtrl,
    required this.barcodeFocusNode,
    required this.onScan,
    required this.onSearch,
    // required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. ช่อง Barcode
          Expanded(
            flex: 5,
            child: SizedBox(
              height: 65,
              child: CustomTextField(
                controller: barcodeCtrl,
                focusNode: barcodeFocusNode,
                autofocus: true,
                // textAlignVertical: TextAlignVertical.center, // Not supported yet but default is mostly fine
                label: 'Scan Barcode',
                hint: 'ยิงบาร์โค้ด / Enter',
                prefixIcon: Icons.qr_code_scanner,
                filled: true,
                fillColor: Colors.white,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward), // or Icons.send
                  onPressed: () => onScan(barcodeCtrl.text),
                  tooltip: 'กดเพื่อค้นหา / Enter',
                ),
                onSubmitted: onScan,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 2. ปุ่มค้นหา (Swapped here)
          Expanded(
            flex: 2,
            child: SizedBox(
              height:
                  47, // Adjusted height to align better if needed, or keep same
              child: CustomButton(
                onPressed: onSearch,
                icon: Icons.search,
                label: 'ค้นหา (F3)',
                backgroundColor: Colors.indigo.shade50,
                foregroundColor: Colors.indigo,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 3. ช่องจำนวน (Swapped here)
          SizedBox(
            width: 100,
            child: SizedBox(
              height: 60,
              child: CustomTextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                // textAlignVertical: TextAlignVertical.center,
                label: 'จำนวน',
                filled: true,
                fillColor: Colors.white,
                onSubmitted: (_) => barcodeFocusNode.requestFocus(),
                onTap: () => qtyCtrl.selection = TextSelection(
                    baseOffset: 0, extentOffset: qtyCtrl.text.length),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
