// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api, use_build_context_synchronously
part of '../product_form_dialog.dart';

extension ProductFormLeftColumnExtension on _ProductFormDialogState {
  Widget _buildSectionTitle(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildLeftColumnContent() {
    return Column(
      children: [
        // Image Placeholder & Basic Info Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Picker Box
            InkWell(
              onTap: _pickImage,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  border: Border.all(color: Colors.grey[400]!),
                  borderRadius: BorderRadius.circular(8),
                  image: _pickedImage != null
                      ? DecorationImage(
                          image: FileImage(File(_pickedImage!.path)),
                          fit: BoxFit.cover,
                        )
                      : (widget.product?.imageUrl != null &&
                              widget.product!.imageUrl!.isNotEmpty)
                          ? DecorationImage(
                              image: FileImage(File(widget.product!.imageUrl!)),
                              fit: BoxFit.cover,
                            ) // Assuming local path for Desktop
                          : null,
                ),
                child: (_pickedImage == null &&
                        (widget.product?.imageUrl == null ||
                            widget.product!.imageUrl!.isEmpty))
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.add_a_photo, size: 32, color: Colors.grey),
                          SizedBox(height: 4),
                          Text('เลือกรูป',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  CustomTextField(
                    controller: _barcodeCtrl,
                    readOnly: widget.product?.barcode != null &&
                        widget.product!.barcode!.isNotEmpty,
                    label: 'รหัสบาร์โค้ด (Barcode)',
                    filled: widget.product?.barcode != null &&
                        widget.product!.barcode!.isNotEmpty,
                    fillColor: (widget.product?.barcode != null &&
                            widget.product!.barcode!.isNotEmpty)
                        ? Colors.grey[200]
                        : null,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _nameCtrl,
                    label: 'ชื่อสินค้า *',
                    validator: (v) =>
                        v == null || v.isEmpty ? 'กรุณากรอกชื่อ' : null,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _aliasCtrl,
                    label: 'ชื่อย่อ (Alias)',
                  ),
                  const SizedBox(height: 12),
                  // Product Type Searchable Dropdown
                  Row(
                    children: [
                      Expanded(
                        child: LayoutBuilder(builder: (context, constraints) {
                          return Autocomplete<ProductType>(
                            key: _typeFieldKey, // ✅ Secure Key
                            initialValue:
                                TextEditingValue(text: _typeNameCtrl.text),
                            optionsBuilder:
                                (TextEditingValue textEditingValue) {
                              if (textEditingValue.text.isEmpty) {
                                return _productTypes;
                              }
                              return _productTypes.where((ProductType option) {
                                return option.name.toLowerCase().contains(
                                    textEditingValue.text.toLowerCase());
                              });
                            },
                            displayStringForOption: (ProductType option) => option
                                .name,
                            onSelected: (ProductType selection) {
                              setState(() {
                                _selectedTypeId = selection.id;
                                _typeNameCtrl.text = selection.name;
                              });
                            },
                            fieldViewBuilder: (context, textEditingController,
                                focusNode, onFieldSubmitted) {
                              return CustomTextField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                label: 'ประเภทสินค้า *',
                                selectAllOnFocus: true, // Auto-select text
                                suffixIcon: const Icon(Icons.arrow_drop_down),
                                onChanged: (val) {
                                  // ✅ Auto-match Type ID
                                  final match = _productTypes
                                      .where((t) =>
                                          t.name.toLowerCase() ==
                                          val.toLowerCase())
                                      .toList();
                                  if (match.isNotEmpty) {
                                    setState(() {
                                      _selectedTypeId = match.first.id;
                                    });
                                  } else {
                                    if (_selectedTypeId != 0) {
                                      // setState(() => _selectedTypeId = null); // Optional: Force null if invalid
                                    }
                                  }
                                },
                                validator: (val) => _selectedTypeId == null
                                    ? 'กรุณาเลือกประเภท'
                                    : null,
                              );
                            },
                            optionsViewBuilder: (context, onSelected, options) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 4.0,
                                  child: SizedBox(
                                    width: constraints.maxWidth,
                                    height: 300,
                                    child: Builder(builder: (listContext) {
                                      final highlightedIndex =
                                          AutocompleteHighlightedOption.of(
                                              listContext);
                                      return ListView.builder(
                                        padding: EdgeInsets.zero,
                                        itemCount: options.length,
                                        itemBuilder:
                                            (BuildContext context, int index) {
                                          final ProductType option =
                                              options.elementAt(index);
                                          final bool isHighlighted =
                                              index == highlightedIndex;
                                          return ListTile(
                                            tileColor: isHighlighted
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                    .withValues(alpha: 0.12)
                                                : null,
                                            title: Text(
                                              option.name,
                                              style: TextStyle(
                                                fontWeight: isHighlighted
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                            onTap: () => onSelected(option),
                                          );
                                        },
                                      );
                                    }),
                                  ),
                                ),
                              );
                            },
                          );
                        }),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _addNewProductType,
                        icon: const Icon(Icons.add_circle, color: Colors.green),
                        tooltip: 'เพิ่มประเภทสินค้าใหม่',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Unit Search Field with Add Button
                  Row(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Autocomplete<Unit>(
                              key: _unitFieldKey, // ✅ Secure Key
                              initialValue:
                                  TextEditingValue(text: _unitNameCtrl.text),
                              optionsBuilder:
                                  (TextEditingValue textEditingValue) {
                                if (textEditingValue.text.isEmpty) {
                                  return _units;
                                }
                                return _units.where((Unit option) {
                                  return option.name.toLowerCase().contains(
                                      textEditingValue.text.toLowerCase());
                                });
                              },
                              displayStringForOption: (Unit option) =>
                                  option.name,
                              onSelected: (Unit selection) {
                                setState(() {
                                  _selectedUnitId = selection.id;
                                  _unitNameCtrl.text = selection.name;
                                });
                              },
                              fieldViewBuilder: (context, textEditingController,
                                  focusNode, onFieldSubmitted) {
                                return CustomTextField(
                                  controller: textEditingController,
                                  focusNode: focusNode,
                                  label: 'หน่วยสินค้า *',
                                  selectAllOnFocus: true, // Auto-select text
                                  suffixIcon: const Icon(Icons.arrow_drop_down),
                                  onChanged: (val) {
                                    // ✅ Auto-match Unit ID
                                    final match = _units
                                        .where((u) =>
                                            u.name.toLowerCase() ==
                                            val.toLowerCase())
                                        .toList();
                                    if (match.isNotEmpty) {
                                      setState(() {
                                        _selectedUnitId = match.first.id;
                                      });
                                    } else {
                                      if (_selectedUnitId != null) {
                                        setState(() => _selectedUnitId = null);
                                      }
                                    }
                                  },
                                  validator: (val) => _selectedUnitId == null
                                      ? 'กรุณาเลือกหน่วย'
                                      : null,
                                );
                              },
                              optionsViewBuilder:
                                  (context, onSelected, options) {
                                return Align(
                                  alignment: Alignment.topLeft,
                                  child: Material(
                                    elevation: 4.0,
                                    child: SizedBox(
                                      width: constraints.maxWidth,
                                      height: 200,
                                      child: Builder(builder: (listContext) {
                                        final highlightedIndex =
                                            AutocompleteHighlightedOption.of(
                                                listContext);
                                        return ListView.builder(
                                          padding: EdgeInsets.zero,
                                          itemCount: options.length,
                                          itemBuilder: (BuildContext context,
                                              int index) {
                                            final Unit option =
                                                options.elementAt(index);
                                            final bool isHighlighted =
                                                index == highlightedIndex;
                                            return ListTile(
                                              tileColor: isHighlighted
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                      .withValues(alpha: 0.12)
                                                  : null,
                                              title: Text(
                                                option.name,
                                                style: TextStyle(
                                                  fontWeight: isHighlighted
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                              onTap: () => onSelected(option),
                                            );
                                          },
                                        );
                                      }),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _addNewUnit,
                        icon: const Icon(Icons.add_circle, color: Colors.green),
                        tooltip: 'เพิ่มหน่วยนับใหม่',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),

        // Prices Section
        _buildSectionTitle('ราคาต้นทุน & ขาย'),
        if (Provider.of<AuthProvider>(context).canViewCost) ...[
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  controller: _costCtrl,
                  keyboardType: TextInputType.number,
                  label: '* ต้นทุนสินค้า',
                  prefixText: '฿ ',
                  selectAllOnFocus: true, // ✅ Auto-select
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                ),
              ),
              const SizedBox(width: 24), // Spacer
            ],
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: _retailPriceCtrl,
                keyboardType: TextInputType.number,
                label: '* ราคาปลีก',
                prefixText: '฿ ',
                selectAllOnFocus: true, // ✅ Auto-select
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CustomTextField(
                controller: _wholesalePriceCtrl,
                keyboardType: TextInputType.number,
                label: '* ราคาส่ง',
                prefixText: '฿ ',
                selectAllOnFocus: true, // ✅ Auto-select
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: _memberRetailPriceCtrl,
                keyboardType: TextInputType.number,
                label: 'ราคาปลีกสมาชิก',
                prefixText: '฿ ',
                selectAllOnFocus: true, // ✅ Auto-select
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CustomTextField(
                controller: _memberWholesalePriceCtrl,
                keyboardType: TextInputType.number,
                label: 'ราคาส่งสมาชิก',
                prefixText: '฿ ',
                selectAllOnFocus: true, // ✅ Auto-select
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(),

        // Options
        CheckboxListTile(
          title: const Text('ไม่ตัดสต็อก'),
          value: !_trackStock, // Inverted logic for UI wording
          onChanged: (val) => setState(() => _trackStock = !val!),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),

        // ✅ Active Status Checkbox
        CheckboxListTile(
          title: const Text('ใช้งาน (Active)'),
          subtitle: const Text('หากปิด สินค้าจะไม่แสดงในหน้าจอขาย'),
          value: _isActiveProduct,
          onChanged: (val) => setState(() => _isActiveProduct = val ?? true),
          activeColor: Colors.green,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),

        // ✅ Warehouse Item Checkbox
        CheckboxListTile(
          title: const Text('สินค้าส่ง (Warehouse Item)'),
          subtitle: const Text('สินค้าชิ้นใหญ่ต้องเบิกจากโกดัง/หลังร้าน'),
          value: _isWarehouseItem,
          onChanged: (val) => setState(() => _isWarehouseItem = val ?? false),
          activeColor: Colors.deepOrange,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),

        const SizedBox(height: 16),
        // Stock Quantity Field (Restored/Added)
        CustomTextField(
          controller: _stockCtrl,
          readOnly: _components.isNotEmpty, // Lock if linked to components
          label: _components.isNotEmpty
              ? 'จำนวนสต๊อก (อ้างอิงจากส่วนประกอบ)'
              : 'จำนวนสต๊อก',
          filled: _components.isNotEmpty,
          fillColor: _components.isNotEmpty ? Colors.grey[200] : null,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          selectAllOnFocus: true, // ✅ Auto-select
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: _reorderPointCtrl,
                label: 'จุดสั่งซื้อ (ต่ำกว่าแจ้งเตือน)',
                keyboardType: TextInputType.number,
                selectAllOnFocus: true, // ✅ Auto-select
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: LayoutBuilder(builder: (context, constraints) {
                      return Autocomplete<String>(
                        initialValue: TextEditingValue(text: _shelfCtrl.text),
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          // ✅ MAP to Database Shelves
                          final options = _shelves.map((e) => e.name).toList();
                          if (textEditingValue.text.isEmpty) return options;
                          return options.where((String option) {
                            return option.contains(textEditingValue.text);
                          });
                        },
                        onSelected: (String selection) {
                          _shelfCtrl.text = selection;
                        },
                        fieldViewBuilder: (context, textEditingController,
                            focusNode, onFieldSubmitted) {
                          return CustomTextField(
                            key: _shelfFieldKey, // Keep focus stable
                            controller: textEditingController,
                            focusNode: focusNode,
                            label: 'ที่เก็บ / ชั้นวาง (Shelf)',
                            selectAllOnFocus: true, // ✅ Auto-select
                            suffixIcon: const Icon(Icons.arrow_drop_down),
                            onChanged: (val) {
                              _shelfCtrl.text = val;
                            },
                          );
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4.0,
                              child: SizedBox(
                                width: constraints.maxWidth,
                                height: 200,
                                child: Builder(builder: (listContext) {
                                  final highlightedIndex =
                                      AutocompleteHighlightedOption.of(
                                          listContext);
                                  return ListView.builder(
                                    padding: EdgeInsets.zero,
                                    itemCount: options.length,
                                    itemBuilder:
                                        (BuildContext context, int index) {
                                      final String option =
                                          options.elementAt(index);
                                      final bool isHighlighted =
                                          index == highlightedIndex;
                                      return ListTile(
                                        tileColor: isHighlighted
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withValues(alpha: 0.12)
                                            : null,
                                        title: Text(
                                          option,
                                          style: TextStyle(
                                            fontWeight: isHighlighted
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                        onTap: () => onSelected(option),
                                      );
                                    },
                                  );
                                }),
                              ),
                            ),
                          );
                        },
                      );
                    }),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.blue),
                    onPressed: _addNewShelf,
                    tooltip: 'เพิ่มชั้นวางใหม่',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CustomTextField(
                controller: _pointsCtrl,
                label: 'แต้มสะสม',
                keyboardType: TextInputType.number,
                selectAllOnFocus: true, // ✅ Auto-select
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<VatType>(
                initialValue: _selectedVat, // Use initialValue instead of value
                decoration: const InputDecoration(
                  labelText: 'VAT',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                ),
                isExpanded: true,
                items: VatType.values
                    .map((v) => DropdownMenuItem(
                          value: v,
                          child: Text(v.label, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedVat = val);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CustomTextField(
                controller: _supplierNameCtrl,
                readOnly: true,
                label: 'ผู้ขาย',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _openSupplierSearch,
                ),
                onTap: _openSupplierSearch,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
