// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api, use_build_context_synchronously
part of '../product_form_dialog.dart';

extension ProductFormActionsExtension on _ProductFormDialogState {
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    // Pick an image.
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _pickedImage = image;
      });
    }
  }

  Future<void> _loadComponents(int parentId) async {
    final comps = await _componentRepo.getComponentsByParentId(parentId);
    if (mounted) {
      setState(() {
        _components = comps;
      });
    }
  }

  Future<void> _loadTiers(int productId) async {
    final tiers = await _tierRepo.getTiersByProductId(productId);
    if (mounted) {
      setState(() {
        _priceTiers = tiers;
      });
    }
  }

  Future<void> _loadBarcodes(int productId) async {
    final barcodes = await widget.repo.getProductBarcodesByProductId(productId);
    if (mounted) {
      setState(() {
        _extraBarcodes = barcodes;
      });
    }
  }

  Future<void> _loadInitialData() async {
    final suppliers = await _supplierRepo.getAllSuppliers();
    final units = await _unitRepo.getAllUnits();
    final types = await _typeRepo.getAllProductTypes(); // Load types
    final shelves = await _shelfRepo.getAllShelves(); // Load shelves

    if (!mounted) return;
    setState(() {
      _suppliers = suppliers;
      _units = units;
      _productTypes = types;
      _shelves = shelves;

      // Init selected Type
      if (widget.product != null) {
        // Edit Mode: Use existing type
        _selectedTypeId = widget.product!.productType;

        // Ensure selected type exists in list
        if (!_productTypes.any((t) => t.id == _selectedTypeId)) {
          // Fallback logic for Edit Mode only
          if (_productTypes.isNotEmpty) {
            _selectedTypeId = _productTypes.first.id;
          } else {
            _selectedTypeId = 0;
          }
        }
      } else {
        // Create Mode: Start with empty selection
        _selectedTypeId = null;
      }

      // Update Type Name Controller
      if (_selectedTypeId != null) {
        final existingType =
            _productTypes.where((t) => t.id == _selectedTypeId).toList();
        if (existingType.isNotEmpty) {
          _typeNameCtrl.text = existingType.first.name;
        } else {
          _typeNameCtrl.clear();
        }
      }

      // Check Supplier ID
      final productSupplierId = widget.product?.supplierId;
      if (productSupplierId != null &&
          suppliers.any((s) => s.id == productSupplierId)) {
        _selectedSupplierId = productSupplierId;
      } else {
        _selectedSupplierId = null;
      }
      // UPDATE TEXT CONTROLLER
      if (_selectedSupplierId != null) {
        final found = _suppliers.firstWhere((s) => s.id == _selectedSupplierId);
        _supplierNameCtrl.text = found.name;
      } else {
        _supplierNameCtrl.clear();
      }

      // Validate unit selection and set controller text
      final productUnitId = widget.product?.unitId;
      // If we haven't selected one yet (first load), try to use the product's unit
      if (_selectedUnitId == null && productUnitId != null) {
        if (units.any((u) => u.id == productUnitId)) {
          _selectedUnitId = productUnitId;
        }
      }

      if (_selectedUnitId != null) {
        final existing = units.where((u) => u.id == _selectedUnitId).toList();
        if (existing.isNotEmpty) {
          _unitNameCtrl.text = existing.first.name;
        } else {
          _selectedUnitId = null; // Reset if invalid
          _unitNameCtrl.text = '';
        }
      } else {
        _selectedUnitId = null;
        _unitNameCtrl.text = '';
      }
      // ✅ Update Keys when data loaded
      _typeFieldKey = UniqueKey();
      _unitFieldKey = UniqueKey();
      _shelfFieldKey = UniqueKey();
    });
  }

  // ฟังก์ชันเพิ่มหน่วยนับใหม่
  Future<void> _addNewUnit() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('เพิ่มหน่วยนับใหม่'),
        content: CustomTextField(
          controller: ctrl,
          label: 'ชื่อหน่วยนับ (เช่น ชิ้น, กล่อง)',
          autofocus: true,
        ),
        actions: [
          CustomButton(
            label: 'ยกเลิก',
            type: ButtonType.secondary,
            onPressed: () => Navigator.pop(ctx),
          ),
          CustomButton(
            label: 'บันทึก',
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final newId = await _unitRepo.saveUnit(result);
      if (newId > 0) {
        await _loadInitialData(); // Reload list
        setState(() {
          _typeFieldKey =
              UniqueKey(); // Reset Key to force rebuild with new data
          _unitFieldKey = UniqueKey();
          _selectedUnitId = newId; // Auto select new unit
        });
      }
    }
  }

  // ฟังก์ชันเพิ่มประเภทสินค้าใหม่
  Future<void> _addNewProductType() async {
    final nameCtrl = TextEditingController();
    bool isWeighing = false;

    final result = await showDialog<ProductType>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('เพิ่มประเภทสินค้าใหม่'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: nameCtrl,
                  label: 'ชื่อประเภท (เช่น ผัก, เครื่องดื่ม)',
                  autofocus: true,
                ),
                CustomTextField(
                  controller: nameCtrl,
                  label: 'ชื่อประเภท (เช่น ผัก, เครื่องดื่ม)',
                  autofocus: true,
                ),
              ],
            ),
            actions: [
              CustomButton(
                label: 'ยกเลิก',
                type: ButtonType.secondary,
                onPressed: () => Navigator.pop(ctx),
              ),
              CustomButton(
                label: 'บันทึก',
                onPressed: () {
                  if (nameCtrl.text.isNotEmpty) {
                    Navigator.pop(
                        ctx,
                        ProductType(
                            id: 0,
                            name: nameCtrl.text.trim(),
                            isWeighing: isWeighing));
                  }
                },
              ),
            ],
          );
        },
      ),
    );

    if (result != null) {
      final newId = await _typeRepo.saveProductType(result);
      if (newId > 0) {
        await _loadInitialData(); // Reload list
        setState(() {
          _typeFieldKey = UniqueKey(); // Reset Key
          _unitFieldKey = UniqueKey();
          _shelfFieldKey = UniqueKey();
          _selectedTypeId = newId; // Auto select new type
        });
      }
    }
  }

  // ฟังก์ชันเพิ่มชั้นวางใหม่
  Future<void> _addNewShelf() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('เพิ่มชั้นวางใหม่'),
        content: CustomTextField(
          controller: ctrl,
          label: 'ชื่อชั้นวาง (เช่น โซน A, ชั้น 1)',
          autofocus: true,
        ),
        actions: [
          CustomButton(
            label: 'ยกเลิก',
            type: ButtonType.secondary,
            onPressed: () => Navigator.pop(ctx),
          ),
          CustomButton(
            label: 'บันทึก',
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final newId = await _shelfRepo.saveShelf(result);
      if (newId > 0) {
        await _loadInitialData(); // Reload list
        setState(() {
          _typeFieldKey = UniqueKey();
          _unitFieldKey = UniqueKey();
          _shelfFieldKey = UniqueKey();
          _shelfCtrl.text = result; // Auto fill the new shelf
        });
      }
    }
  }

  Future<void> _openSupplierSearch() async {
    final selectedInfo = await showDialog<Supplier>(
      context: context,
      builder: (ctx) => const SupplierSearchDialog(),
    );

    if (selectedInfo != null) {
      setState(() {
        _selectedSupplierId = selectedInfo.id;
        _supplierNameCtrl.text = selectedInfo.name;
      });
    }
  }

  Future<void> _save() async {
    // 1. Collect Errors
    List<String> errors = [];

    // Check Form Fields (Name, Prices)
    if (!_formKey.currentState!.validate()) {
      // Note: We can't easily get the error text from TextFormField unless we inspect controllers
      if (_nameCtrl.text.isEmpty) errors.add('- ชื่อสินค้า');
      if (_retailPriceCtrl.text.isEmpty) errors.add('- ราคาปลีก');
      if (_wholesalePriceCtrl.text.isEmpty) errors.add('- ราคาส่ง');
    }

    // Check Dropdowns (Manual Check)
    if (_selectedTypeId == null) errors.add('- ประเภทสินค้า');
    if (_selectedUnitId == null) errors.add('- หน่วยสินค้า');

    // 2. Show Error Dialog if any
    if (errors.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('กรุณากรอกข้อมูลให้ครบ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('รายการที่ยังไม่ได้ระบุ:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...errors.map(
                  (e) => Text(e, style: const TextStyle(color: Colors.red))),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ตกลง'),
            )
          ],
        ),
      );
      return; // Stop saving
    }

    // Pass Validation
    {
      // Show Loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );

      try {
        // Auto-generate barcode if empty (Always, even if delayedSave)
        String? barcode = _barcodeCtrl.text.trim();
        if (barcode.isEmpty) {
          // Generate 8-digit barcode
          barcode = (DateTime.now().millisecondsSinceEpoch % 100000000)
              .toString()
              .padLeft(8, '0');
        }

        final newStock = double.tryParse(_stockCtrl.text) ?? 0.0;
        final oldStock = widget.product?.stockQuantity ?? 0.0;

        // ✅ Security Check: If stock changed
        if (newStock != oldStock &&
            SettingsService().requireAdminForStockAdjust) {
          debugPrint(
              'Stock changed from $oldStock to $newStock. Requesting Admin Auth.');

          // Hide Loading Temporarily for Auth Dialog
          try {
            Navigator.of(context).pop();
          } catch (e) {
            debugPrint('⚠️ Navigator pop failed: $e');
          }

          final authorized = await AdminPinDialog.show(
            context,
            title: 'ยืนยันสิทธิ์',
            message: 'กรุณากรอกรหัสแอดมินเพื่อปรับปรุงสต็อก',
          );
          if (!authorized) return;

          // Show Loading Again
          if (!mounted) return;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => const Center(child: CircularProgressIndicator()),
          );
        }

        final newProduct = Product(
          id: widget.product?.id ?? 0,
          name: _nameCtrl.text,
          barcode: barcode.isEmpty ? null : barcode, // Allow null if empty
          alias: _aliasCtrl.text.isEmpty ? null : _aliasCtrl.text,
          productType: _selectedTypeId ?? 0, // Dynamic Type
          costPrice: double.tryParse(_costCtrl.text) ?? 0.0,
          retailPrice: double.tryParse(_retailPriceCtrl.text) ?? 0.0,
          wholesalePrice: double.tryParse(_wholesalePriceCtrl.text),
          memberRetailPrice: double.tryParse(_memberRetailPriceCtrl.text),
          memberWholesalePrice: double.tryParse(_memberWholesalePriceCtrl.text),
          vatType: _selectedVat.value,
          stockQuantity: newStock,
          trackStock: _trackStock,
          allowPriceEdit: false,
          reorderPoint: double.tryParse(_reorderPointCtrl.text),
          points: int.tryParse(_pointsCtrl.text) ?? 0,
          supplierId: _selectedSupplierId,
          unitId: _selectedUnitId,
          categoryId: widget.product?.categoryId,
          imageUrl:
              _pickedImage?.path ?? widget.product?.imageUrl, // Save Image
          expiryDate: _expiryDate,
          shelfLocation: _shelfCtrl.text,
          isActive: _isActiveProduct,
          isWarehouseItem: _isWarehouseItem, // ✅ Saved
        );

        // ✅ Delayed Save Mode: Return unsaved product immediately
        if (widget.delayedSave) {
          if (!mounted) return;
          try {
            Navigator.of(context).pop(); // Pop Loading
            Navigator.of(context).pop(newProduct); // Return with ID 0
          } catch (e) {
            debugPrint('⚠️ Navigator pop failed: $e');
            // ถ้า pop ไม่ได้ ให้ timeout แล้วลองใหม่
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                try {
                  Navigator.of(context).pop(newProduct);
                } catch (_) {}
              }
            });
          }
          return;
        }

        final productId = await widget.repo.saveProduct(newProduct);

        if (productId > 0) {
          // Check if we need to save tiers
          for (var tier in _priceTiers) {
            tier.productId = productId; // Ensure linked to saved product
          }

          await Future.wait([
            _componentRepo.updateComponents(productId, _components),
            _tierRepo.updateTiers(productId, _priceTiers),
            widget.repo.updateProductBarcodes(productId, _extraBarcodes),
          ]);

          if (!mounted) return;
          try {
            Navigator.of(context).pop(); // Pop Loading
          } catch (e) {
            debugPrint('⚠️ Navigator pop (loading) failed: $e');
          }

          // Return the saved product with the new ID
          AlertService.show(
              context: context, message: 'บันทึกสำเร็จ', type: 'success');
          try {
            Navigator.of(context).pop(newProduct.copyWith(id: productId));
          } catch (e) {
            debugPrint('⚠️ Navigator pop (result) failed: $e');
          }
        } else {
          if (mounted) {
            try {
              Navigator.of(context).pop(); // Pop Loading
            } catch (e) {
              debugPrint('⚠️ Navigator pop failed: $e');
            }
            AlertService.show(
                context: context, message: 'บันทึกไม่สำเร็จ', type: 'error');
          }
        }
      } catch (e) {
        if (mounted) {
          try {
            Navigator.of(context).pop(); // Pop Loading
          } catch (navError) {
            debugPrint('⚠️ Navigator pop failed: $navError');
          }
          AlertService.show(
              context: context, message: 'เกิดข้อผิดพลาด: $e', type: 'error');
        }
      }
    }
  }
}
