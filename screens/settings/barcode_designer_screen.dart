import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/barcode_template.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_buttons.dart';
import 'package:uuid/uuid.dart';

class BarcodeDesignerScreen extends StatefulWidget {
  final BarcodeTemplate template;

  const BarcodeDesignerScreen({super.key, required this.template});

  @override
  State<BarcodeDesignerScreen> createState() => _BarcodeDesignerScreenState();
}

class _BarcodeDesignerScreenState extends State<BarcodeDesignerScreen> {
  late BarcodeTemplate _template;
  BarcodeElement? _selectedElement;
  int _elementCounter = 1;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _template = widget.template;
    // Ensure all elements have IDs
    for (var e in _template.elements) {
      if (e.id.isEmpty) e.id = const Uuid().v4();
    }
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (_selectedElement == null) return;

    // Don't move if we are typing in a text field
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus != _focusNode) return;

    final double step = HardwareKeyboard.instance.isShiftPressed ? 1.0 : 0.1;

    setState(() {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _selectedElement!.x -= step;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _selectedElement!.x += step;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _selectedElement!.y -= step;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _selectedElement!.y += step;
      } else if (event.logicalKey == LogicalKeyboardKey.delete ||
          event.logicalKey == LogicalKeyboardKey.backspace) {
        _template.elements.remove(_selectedElement);
        _selectedElement = null;
      }
    });
  }

  void _addElement(BarcodeElementType type) {
    setState(() {
      final newEl = BarcodeElement(
        id: const Uuid().v4(),
        type: type,
        content: type == BarcodeElementType.text
            ? 'ข้อความ $_elementCounter'
            : '12345678',
        x: 5,
        y: 5,
        width: type == BarcodeElementType.barcode ? 25 : 20,
        height: type == BarcodeElementType.barcode ? 10 : 10,
      );
      _template.elements.add(newEl);
      _selectedElement = newEl;
      _elementCounter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: Container(
          width: 1200,
          height: 800,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('การออกแบบบาร์โค้ด',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              const Divider(height: 1),
              Expanded(
                child: Row(
                  children: [
                    // Toolbar (Left)
                    _buildToolbar(),
                    // Canvas (Center)
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          // Allow clicking background to deselect and focus
                          setState(() => _selectedElement = null);
                          _focusNode.requestFocus();
                        },
                        child: Center(
                          child: _buildCanvas(),
                        ),
                      ),
                    ),
                    // Properties (Right)
                    _buildPropertiesPanel(),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Footer
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CustomButton(
                      onPressed: () => Navigator.pop(context, _template),
                      icon: Icons.save,
                      label: 'บันทึกแบบ',
                      type: ButtonType.primary,
                      backgroundColor: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    CustomButton(
                      onPressed: () => Navigator.pop(context),
                      label: 'ยกเลิก',
                      type: ButtonType.secondary,
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      width: 100,
      color: Colors.white,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('เครื่องมือ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          _toolbarItem(Icons.text_fields, 'ข้อความ',
              () => _addElement(BarcodeElementType.text)),
          _toolbarItem(Icons.crop_square, 'สี่เหลี่ยม',
              () => _addElement(BarcodeElementType.rectangle)),
          _toolbarItem(Icons.barcode_reader, 'บาร์โค้ด',
              () => _addElement(BarcodeElementType.barcode)),
          _toolbarItem(Icons.qr_code, 'QR Code',
              () => _addElement(BarcodeElementType.qrCode)),
          _toolbarItem(
              Icons.image, 'โลโก้', () => _addElement(BarcodeElementType.logo)),
        ],
      ),
    );
  }

  Widget _toolbarItem(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvas() {
    double scale = 12.0; // Scale mm to pixels
    double w = _template.labelWidth * scale;
    double h = _template.labelHeight * scale;

    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 0.5),
        borderRadius:
            _template.shape == 'rounded' ? BorderRadius.circular(16) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 5,
          )
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: _template.elements.map((e) {
          bool isSelected = _selectedElement?.id == e.id;
          return Positioned(
            left: e.x * scale,
            top: e.y * scale,
            child: SizedBox(
              width: e.width * scale,
              height: e.height * scale,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Actual Content & Move Handle
                  GestureDetector(
                    onTap: () => setState(() => _selectedElement = e),
                    onPanUpdate: isSelected
                        ? (details) {
                            setState(() {
                              e.x += details.delta.dx / scale;
                              e.y += details.delta.dy / scale;
                            });
                          }
                        : null,
                    child: Container(
                      decoration: BoxDecoration(
                        border: isSelected
                            ? Border.all(color: Colors.blue, width: 1.5)
                            : Border.all(color: Colors.transparent),
                      ),
                      child: Center(child: _buildElementContent(e, isSelected)),
                    ),
                  ),
                  // Resize Handles
                  if (isSelected) ...[
                    _buildResizeHandle(e, Alignment.topLeft, scale),
                    _buildResizeHandle(e, Alignment.topCenter, scale),
                    _buildResizeHandle(e, Alignment.topRight, scale),
                    _buildResizeHandle(e, Alignment.centerLeft, scale),
                    _buildResizeHandle(e, Alignment.centerRight, scale),
                    _buildResizeHandle(e, Alignment.bottomLeft, scale),
                    _buildResizeHandle(e, Alignment.bottomCenter, scale),
                    _buildResizeHandle(e, Alignment.bottomRight, scale),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildResizeHandle(
      BarcodeElement e, Alignment alignment, double scale) {
    const double handleSize = 12.0;
    return Positioned(
      left: alignment == Alignment.topLeft ||
              alignment == Alignment.bottomLeft ||
              alignment == Alignment.centerLeft
          ? -handleSize / 2
          : (alignment == Alignment.topCenter ||
                  alignment == Alignment.bottomCenter
              ? (e.width * scale / 2) - handleSize / 2
              : null),
      right: alignment == Alignment.topRight ||
              alignment == Alignment.bottomRight ||
              alignment == Alignment.centerRight
          ? -handleSize / 2
          : null,
      top: alignment == Alignment.topLeft ||
              alignment == Alignment.topRight ||
              alignment == Alignment.topCenter
          ? -handleSize / 2
          : (alignment == Alignment.centerLeft ||
                  alignment == Alignment.centerRight
              ? (e.height * scale / 2) - handleSize / 2
              : null),
      bottom: alignment == Alignment.bottomLeft ||
              alignment == Alignment.bottomRight ||
              alignment == Alignment.bottomCenter
          ? -handleSize / 2
          : null,
      child: MouseRegion(
        cursor: _getCursorForAlignment(alignment),
        child: GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              double dx = details.delta.dx / scale;
              double dy = details.delta.dy / scale;

              // Vertical resizing
              if (alignment == Alignment.bottomRight ||
                  alignment == Alignment.bottomCenter ||
                  alignment == Alignment.bottomLeft) {
                e.height += dy;
                if (e.height < 1) e.height = 1;
              }
              if (alignment == Alignment.topLeft ||
                  alignment == Alignment.topCenter ||
                  alignment == Alignment.topRight) {
                double oldH = e.height;
                e.height -= dy;
                if (e.height < 1) e.height = 1;
                e.y += (oldH - e.height);
              }

              // Horizontal resizing
              if (alignment == Alignment.bottomRight ||
                  alignment == Alignment.centerRight ||
                  alignment == Alignment.topRight) {
                e.width += dx;
                if (e.width < 1) e.width = 1;
              }
              if (alignment == Alignment.bottomLeft ||
                  alignment == Alignment.centerLeft ||
                  alignment == Alignment.topLeft) {
                double oldW = e.width;
                e.width -= dx;
                if (e.width < 1) e.width = 1;
                e.x += (oldW - e.width);
              }
            });
          },
          child: Container(
            width: handleSize,
            height: handleSize,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.blue, width: 2),
              shape: BoxShape.rectangle,
              boxShadow: const [
                BoxShadow(
                    color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))
              ],
            ),
          ),
        ),
      ),
    );
  }

  MouseCursor _getCursorForAlignment(Alignment alignment) {
    if (alignment == Alignment.topLeft || alignment == Alignment.bottomRight) {
      return SystemMouseCursors.resizeUpLeftDownRight;
    }
    if (alignment == Alignment.topRight || alignment == Alignment.bottomLeft) {
      return SystemMouseCursors.resizeUpRightDownLeft;
    }
    if (alignment == Alignment.topCenter ||
        alignment == Alignment.bottomCenter) {
      return SystemMouseCursors.resizeUpDown;
    }
    if (alignment == Alignment.centerLeft ||
        alignment == Alignment.centerRight) {
      return SystemMouseCursors.resizeLeftRight;
    }
    return SystemMouseCursors.move;
  }

  Widget _buildElementContent(BarcodeElement e, bool isSelected) {
    switch (e.type) {
      case BarcodeElementType.text:
        return Center(
          child: Text(
            e.content,
            style: TextStyle(fontSize: e.fontSize, fontWeight: FontWeight.bold),
          ),
        );
      case BarcodeElementType.barcode:
        return Container(
          color: Colors.grey[200],
          child: const Center(
            child: Icon(Icons.barcode_reader, size: 40),
          ),
        );
      case BarcodeElementType.qrCode:
        return Container(
          color: Colors.grey[200],
          child: const Center(
            child: Icon(Icons.qr_code, size: 40),
          ),
        );
      case BarcodeElementType.rectangle:
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black),
          ),
        );
      case BarcodeElementType.logo:
        return Container(
          color: Colors.grey[200],
          child: const Center(
            child: Icon(Icons.image, size: 40),
          ),
        );
    }
  }

  Widget _buildPropertiesPanel() {
    return Container(
      width: 300,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: _selectedElement == null
          ? const Center(child: Text('กรุณาเลือกองค์ประกอบ'))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('คุณสมบัติ',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Divider(),
                  _propDropdown<String>(
                      'สี', 'สีดำ', ['สีดำ', 'สีน้ำเงิน', 'สีแดง']),
                  if (_selectedElement!.type == BarcodeElementType.text) ...[
                    _propTextField('ข้อความ', _selectedElement!.content, (v) {
                      setState(() => _selectedElement!.content = v);
                    }),
                    _propNumberField('ขนาด Font', _selectedElement!.fontSize,
                        (v) {
                      setState(() => _selectedElement!.fontSize = v);
                    }),
                    _propDropdown<BarcodeDataSource>(
                      'เชื่อมข้อมูล',
                      _selectedElement!.dataSource,
                      BarcodeDataSource.values,
                      labelMapper: (v) {
                        switch (v) {
                          case BarcodeDataSource.none:
                            return 'ไม่ลิ้งข้อมูล';
                          case BarcodeDataSource.barcode:
                            return 'บาร์โค้ด';
                          case BarcodeDataSource.productName:
                            return 'ชื่อสินค้า';
                          case BarcodeDataSource.retailPrice:
                            return 'ราคาสินค้า';
                          case BarcodeDataSource.wholesalePrice:
                            return 'แค็ตตาล็อก';
                        }
                      },
                      onChanged: (v) =>
                          setState(() => _selectedElement!.dataSource = v!),
                    ),
                  ],
                  if (_selectedElement!.type == BarcodeElementType.barcode ||
                      _selectedElement!.type == BarcodeElementType.qrCode) ...[
                    _propDropdown<BarcodeDataSource>(
                      'เชื่อมข้อมูล',
                      _selectedElement!.dataSource,
                      [BarcodeDataSource.none, BarcodeDataSource.barcode],
                      labelMapper: (v) => v == BarcodeDataSource.none
                          ? 'ไม่ลิ้งข้อมูล'
                          : 'บาร์โค้ด',
                      onChanged: (v) =>
                          setState(() => _selectedElement!.dataSource = v!),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text('ตำแหน่งและขนาด (มม.)',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  _propNumberField('X', _selectedElement!.x,
                      (v) => setState(() => _selectedElement!.x = v)),
                  _propNumberField('Y', _selectedElement!.y,
                      (v) => setState(() => _selectedElement!.y = v)),
                  _propNumberField('กว้าง', _selectedElement!.width,
                      (v) => setState(() => _selectedElement!.width = v)),
                  _propNumberField('สูง', _selectedElement!.height,
                      (v) => setState(() => _selectedElement!.height = v)),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      onPressed: () {
                        setState(() {
                          _template.elements.remove(_selectedElement);
                          _selectedElement = null;
                        });
                      },
                      icon: Icons.delete,
                      label: 'ลบองค์ประกอบ',
                      type: ButtonType.danger,
                    ),
                  )
                ],
              ),
            ),
    );
  }

  Widget _propTextField(
      String label, String value, Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label)),
          Expanded(
            child: CustomTextField(
              controller: TextEditingController(text: value)
                ..selection = TextSelection.fromPosition(
                    TextPosition(offset: value.length)),
              label: label,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _propNumberField(
      String label, double value, Function(double) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label)),
          Expanded(
            child: CustomTextField(
              controller: TextEditingController(text: value.toStringAsFixed(1)),
              keyboardType: TextInputType.number,
              label: label,
              onChanged: (v) {
                final d = double.tryParse(v);
                if (d != null) onChanged(d);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _propDropdown<T>(String label, T value, List<T> items,
      {String Function(T)? labelMapper, Function(T?)? onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label)),
          Expanded(
            child: DropdownButtonFormField<T>(
              initialValue: value,
              decoration: const InputDecoration(
                  isDense: true, border: OutlineInputBorder()),
              items: items
                  .map((i) => DropdownMenuItem<T>(
                        value: i,
                        child: Text(labelMapper != null
                            ? labelMapper(i)
                            : i.toString()),
                      ))
                  .toList(),
              onChanged: onChanged ?? (v) {},
            ),
          ),
        ],
      ),
    );
  }
}
