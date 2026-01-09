import 'package:shared_preferences/shared_preferences.dart';
import '../../models/barcode_template.dart';
import 'package:uuid/uuid.dart';

class BarcodePrintService {
  static const String _keyTemplates = 'barcode_print_templates';
  static const String _keySelectedTemplateId = 'barcode_selected_template_id';

  static final BarcodePrintService _instance = BarcodePrintService._internal();
  factory BarcodePrintService() => _instance;
  BarcodePrintService._internal();

  Future<List<BarcodeTemplate>> getAllTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_keyTemplates) ?? [];
    List<BarcodeTemplate> templates =
        jsonList.map((j) => BarcodeTemplate.fromJson(j)).toList();

    // ✅ Seed default templates only if the list is empty (First run or all deleted)
    if (jsonList.isEmpty) {
      final default406 = createBarcode406x108();
      final default32x25 = createDefault32x25();
      templates = [default406, default32x25];
      await prefs.setStringList(
          _keyTemplates, templates.map((t) => t.toJson()).toList());
    } else {
      // ✅ Surgical update: Apply fixes once to existing standard templates
      bool sharedNeedsUpdate = false;
      bool has32x25 = false;

      for (var t in templates) {
        if (t.name == 'barcode (4.06 x 1.08 in)') {
          if (t.marginLeft == 0) {
            t.marginLeft = 1.5;
            sharedNeedsUpdate = true;
          }
        }
        if (t.name.contains('32x25') || t.name.contains('3 แถว')) {
          has32x25 = true;
        }
      }

      // ✅ ถ้ายังไม่มีตัว 32x25 หรือมีการเพิ่มใหม่ ให้บันทึก
      if (!has32x25) {
        templates.add(createDefault32x25());
        sharedNeedsUpdate = true;
      }

      if (sharedNeedsUpdate) {
        await prefs.setStringList(
            _keyTemplates, templates.map((t) => t.toJson()).toList());
      }
    }

    return templates;
  }

  Future<void> saveTemplate(BarcodeTemplate template) async {
    final prefs = await SharedPreferences.getInstance();
    final templates = await getAllTemplates();
    final index = templates.indexWhere((t) => t.id == template.id);
    if (index >= 0) {
      templates[index] = template;
    } else {
      templates.add(template);
    }
    await prefs.setStringList(
        _keyTemplates, templates.map((t) => t.toJson()).toList());
  }

  Future<void> deleteTemplate(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final templates = await getAllTemplates();
    templates.removeWhere((t) => t.id == id);
    await prefs.setStringList(
        _keyTemplates, templates.map((t) => t.toJson()).toList());
  }

  Future<BarcodeTemplate?> getSelectedTemplate() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_keySelectedTemplateId);
    final templates = await getAllTemplates();

    if (id == null && templates.isNotEmpty) {
      // Auto-select 3-row template if none selected - Priority for what user asked
      try {
        final t3 = templates.firstWhere(
            (t) => t.name.contains('32x25') || t.name.contains('3 แถว'));
        return t3;
      } catch (_) {
        return templates.first;
      }
    }

    try {
      return templates.firstWhere((t) => t.id == id);
    } catch (_) {
      return templates.isNotEmpty ? templates.first : null;
    }
  }

  Future<void> setSelectedTemplateId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedTemplateId, id);
  }

  BarcodeTemplate createDefault32x25() {
    final id = const Uuid().v4();
    return BarcodeTemplate(
      id: id,
      name: '32x25มม (Standard 3 Columns)',
      paperWidth: 105,
      paperHeight: 25,
      columns: 3,
      labelWidth: 32,
      labelHeight: 25,
      horizontalGap: 2.0,
      marginLeft: 1.5,
      shape: 'rounded',
      elements: [
        BarcodeElement(
          id: 'name',
          type: BarcodeElementType.text,
          x: 2,
          y: 1,
          width: 28,
          height: 6,
          fontSize: 7.5,
          dataSource: BarcodeDataSource.productName,
        ),
        BarcodeElement(
          id: 'barcode',
          type: BarcodeElementType.barcode,
          x: 2,
          y: 7.5,
          width: 28,
          height: 10,
          dataSource: BarcodeDataSource.barcode,
        ),
        BarcodeElement(
          id: 'price',
          type: BarcodeElementType.text,
          x: 2,
          y: 18.5,
          width: 28,
          height: 6,
          fontSize: 11,
          dataSource: BarcodeDataSource.retailPrice,
        ),
      ],
    );
  }

  BarcodeTemplate createBarcode406x108() {
    final id = const Uuid().v4();
    // 4.06 in = 103.1 mm
    // 1.08 in = 27.4 mm
    return BarcodeTemplate(
      id: id,
      name: 'barcode (4.06 x 1.08 in)',
      paperWidth: 103.1,
      paperHeight: 27.4,
      columns: 3, // Assuming 3 columns based on width
      labelWidth: 32, // Standard 32mm
      labelHeight: 25,
      horizontalGap: 2.5, // Reduced from 3.5 to make space for marginLeft
      marginLeft: 1.5, // ✅ Shift entire page 1.5mm right as requested
      shape: 'rounded',
      elements: [
        BarcodeElement(
          id: 'name',
          type: BarcodeElementType.text,
          x: 3, // Increased from 1
          y: 1,
          width: 28, // Reduced width to compensate
          height: 6,
          fontSize: 7.5,
          dataSource: BarcodeDataSource.productName,
        ),
        BarcodeElement(
          id: 'barcode',
          type: BarcodeElementType.barcode,
          x: 4, // Increased from 2
          y: 7,
          width: 26, // Reduced width to compensate
          height: 11,
          dataSource: BarcodeDataSource.barcode,
        ),
        BarcodeElement(
          id: 'price',
          type: BarcodeElementType.text,
          x: 3, // Increased from 1
          y: 19,
          width: 28, // Reduced width to compensate
          height: 6,
          fontSize: 11,
          dataSource: BarcodeDataSource.retailPrice,
        ),
      ],
    );
  }
}
