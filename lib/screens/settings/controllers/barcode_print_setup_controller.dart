import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/barcode_template.dart';
import '../../../../services/printing/barcode_print_service.dart';

class BarcodePrintSetupState {
  final BarcodeTemplate? template;
  final bool isRound;
  final bool printBorder;
  final bool printDebug;
  final bool autoGap;

  BarcodePrintSetupState({
    this.template,
    this.isRound = true,
    this.printBorder = false,
    this.printDebug = false,
    this.autoGap = false,
  });

  BarcodePrintSetupState copyWith({
    BarcodeTemplate? template,
    bool? isRound,
    bool? printBorder,
    bool? printDebug,
    bool? autoGap,
  }) {
    return BarcodePrintSetupState(
      template: template ?? this.template,
      isRound: isRound ?? this.isRound,
      printBorder: printBorder ?? this.printBorder,
      printDebug: printDebug ?? this.printDebug,
      autoGap: autoGap ?? this.autoGap,
    );
  }
}

class BarcodePrintSetupController extends AutoDisposeNotifier<BarcodePrintSetupState> {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController paperWidthCtrl = TextEditingController();
  final TextEditingController paperHeightCtrl = TextEditingController();
  final TextEditingController rowsCtrl = TextEditingController();
  final TextEditingController colsCtrl = TextEditingController();
  final TextEditingController marginTopCtrl = TextEditingController();
  final TextEditingController marginBottomCtrl = TextEditingController();
  final TextEditingController marginLeftCtrl = TextEditingController();
  final TextEditingController marginRightCtrl = TextEditingController();
  final TextEditingController labelWidthCtrl = TextEditingController();
  final TextEditingController labelHeightCtrl = TextEditingController();
  final TextEditingController hGapCtrl = TextEditingController();
  final TextEditingController vGapCtrl = TextEditingController();
  final TextEditingController borderWidthCtrl = TextEditingController();

  @override
  BarcodePrintSetupState build() {
    ref.onDispose(() {
      nameCtrl.dispose();
      paperWidthCtrl.dispose();
      paperHeightCtrl.dispose();
      rowsCtrl.dispose();
      colsCtrl.dispose();
      marginTopCtrl.dispose();
      marginBottomCtrl.dispose();
      marginLeftCtrl.dispose();
      marginRightCtrl.dispose();
      labelWidthCtrl.dispose();
      labelHeightCtrl.dispose();
      hGapCtrl.dispose();
      vGapCtrl.dispose();
      borderWidthCtrl.dispose();
    });

    return BarcodePrintSetupState();
  }

  void init(BarcodeTemplate? initialTemplate, BarcodePrintService service) {
    if (state.template != null) return; // Already initialized

    BarcodeTemplate template;
    if (initialTemplate != null) {
      template = initialTemplate;
    } else {
      template = service.createBarcode406x108();
    }
    
    nameCtrl.text = template.name;
    paperWidthCtrl.text = template.paperWidth.toString();
    paperHeightCtrl.text = template.paperHeight.toString();
    rowsCtrl.text = template.rows.toString();
    colsCtrl.text = template.columns.toString();
    marginTopCtrl.text = template.marginTop.toString();
    marginBottomCtrl.text = template.marginBottom.toString();
    marginLeftCtrl.text = template.marginLeft.toString();
    marginRightCtrl.text = template.marginRight.toString();
    labelWidthCtrl.text = template.labelWidth.toString();
    labelHeightCtrl.text = template.labelHeight.toString();
    hGapCtrl.text = template.horizontalGap.toString();
    vGapCtrl.text = template.verticalGap.toString();
    borderWidthCtrl.text = template.borderWidth.toString();
    
    state = state.copyWith(
      template: template,
      isRound: template.shape == 'rounded',
      printBorder: template.printBorder,
      printDebug: template.printDebug,
    );
  }

  void updateTemplateFromUI() {
    if (state.template == null) return;

    state.template!.name = nameCtrl.text;
    state.template!.paperWidth = double.tryParse(paperWidthCtrl.text) ?? 100;
    state.template!.paperHeight = double.tryParse(paperHeightCtrl.text) ?? 30;
    state.template!.rows = int.tryParse(rowsCtrl.text) ?? 1;
    state.template!.columns = int.tryParse(colsCtrl.text) ?? 3;
    state.template!.marginTop = double.tryParse(marginTopCtrl.text) ?? 0;
    state.template!.marginBottom = double.tryParse(marginBottomCtrl.text) ?? 0;
    state.template!.marginLeft = double.tryParse(marginLeftCtrl.text) ?? 0;
    state.template!.marginRight = double.tryParse(marginRightCtrl.text) ?? 0;
    state.template!.labelWidth = double.tryParse(labelWidthCtrl.text) ?? 32;
    state.template!.labelHeight = double.tryParse(labelHeightCtrl.text) ?? 25;
    state.template!.horizontalGap = double.tryParse(hGapCtrl.text) ?? 2;
    state.template!.verticalGap = double.tryParse(vGapCtrl.text) ?? 0;
    state.template!.borderWidth = double.tryParse(borderWidthCtrl.text) ?? 1;
    state.template!.shape = state.isRound ? 'rounded' : 'rectangle';
    state.template!.printBorder = state.printBorder;
    state.template!.printDebug = state.printDebug;
  }

  void setAutoGap(bool value) {
    state = state.copyWith(autoGap: value);
    if (value) {
      autoCalculateGaps();
    }
  }

  void onFieldChanged() {
    if (state.autoGap) {
      autoCalculateGaps();
    }
  }

  void autoCalculateGaps() {
    double pw = double.tryParse(paperWidthCtrl.text) ?? 100;
    double ph = double.tryParse(paperHeightCtrl.text) ?? 30;
    int rows = int.tryParse(rowsCtrl.text) ?? 1;
    int cols = int.tryParse(colsCtrl.text) ?? 3;
    double mt = double.tryParse(marginTopCtrl.text) ?? 0;
    double mb = double.tryParse(marginBottomCtrl.text) ?? 0;
    double ml = double.tryParse(marginLeftCtrl.text) ?? 0;
    double mr = double.tryParse(marginRightCtrl.text) ?? 0;
    double lw = double.tryParse(labelWidthCtrl.text) ?? 32;
    double lh = double.tryParse(labelHeightCtrl.text) ?? 25;

    // Horizontal Gap
    if (cols > 1) {
      double availableW = pw - ml - mr;
      double totalLabelsW = lw * cols;
      double hGap = (availableW - totalLabelsW) / (cols - 1);
      if (hGap < 0) hGap = 0;
      if (hGapCtrl.text != hGap.toStringAsFixed(2)) {
         hGapCtrl.text = hGap.toStringAsFixed(2);
      }
    } else {
      if (hGapCtrl.text != '0') hGapCtrl.text = '0';
    }

    // Vertical Gap
    if (rows > 1) {
      double availableH = ph - mt - mb;
      double totalLabelsH = lh * rows;
      double vGap = (availableH - totalLabelsH) / (rows - 1);
      if (vGap < 0) vGap = 0;
      if (vGapCtrl.text != vGap.toStringAsFixed(2)) {
         vGapCtrl.text = vGap.toStringAsFixed(2);
      }
    } else {
      if (vGapCtrl.text != '0') vGapCtrl.text = '0';
    }
  }

  void setTemplateShape(bool round) {
    state = state.copyWith(isRound: round);
  }

  void setOrientation(String ori) {
    if (state.template != null) {
      state.template!.orientation = ori;
      state = state.copyWith();
    }
  }

  void setPrintBorder(bool value) {
    state = state.copyWith(printBorder: value);
  }

  void setPrintDebug(bool value) {
    state = state.copyWith(printDebug: value);
  }

  void updateTemplate(BarcodeTemplate newTemplate) {
    state = state.copyWith(template: newTemplate);
  }
}

final barcodePrintSetupProvider = NotifierProvider.autoDispose<BarcodePrintSetupController, BarcodePrintSetupState>(
  () => BarcodePrintSetupController(),
);
