import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../models/barcode_template.dart';

enum Direction { up, down, left, right }

class BarcodeDesignerState {
  final BarcodeTemplate? template;
  final BarcodeElement? selectedElement;
  final int elementCounter;
  final int updateTick;

  BarcodeDesignerState({
    this.template,
    this.selectedElement,
    this.elementCounter = 1,
    this.updateTick = 0,
  });

  BarcodeDesignerState copyWith({
    BarcodeTemplate? template,
    BarcodeElement? selectedElement,
    bool clearSelection = false,
    int? elementCounter,
  }) {
    return BarcodeDesignerState(
      template: template ?? this.template,
      selectedElement: clearSelection ? null : (selectedElement ?? this.selectedElement),
      elementCounter: elementCounter ?? this.elementCounter,
      updateTick: updateTick + 1,
    );
  }
}

class BarcodeDesignerController extends AutoDisposeNotifier<BarcodeDesignerState> {
  @override
  BarcodeDesignerState build() {
    return BarcodeDesignerState();
  }

  void init(BarcodeTemplate initialTemplate) {
    if (state.template != null) return; // Already initialized
    
    // Ensure all elements have IDs
    for (var e in initialTemplate.elements) {
      if (e.id.isEmpty) e.id = const Uuid().v4();
    }
    
    state = state.copyWith(template: initialTemplate);
  }

  void selectElement(BarcodeElement? element) {
    if (element == null) {
      state = state.copyWith(clearSelection: true);
    } else {
      state = state.copyWith(selectedElement: element);
    }
  }

  void moveSelectedElement(Direction dir, double step) {
    if (state.selectedElement == null) return;
    
    switch (dir) {
      case Direction.left:
        state.selectedElement!.x -= step;
        break;
      case Direction.right:
        state.selectedElement!.x += step;
        break;
      case Direction.up:
        state.selectedElement!.y -= step;
        break;
      case Direction.down:
        state.selectedElement!.y += step;
        break;
    }
    state = state.copyWith(); // trigger rebuild
  }

  void removeSelectedElement() {
    if (state.selectedElement != null && state.template != null) {
      state.template!.elements.remove(state.selectedElement);
      state = state.copyWith(clearSelection: true);
    }
  }

  void addElement(BarcodeElementType type) {
    if (state.template == null) return;

    final newEl = BarcodeElement(
      id: const Uuid().v4(),
      type: type,
      content: type == BarcodeElementType.text
          ? 'ข้อความ ${state.elementCounter}'
          : '12345678',
      x: 5,
      y: 5,
      width: type == BarcodeElementType.barcode ? 25 : 20,
      height: type == BarcodeElementType.barcode ? 10 : 10,
    );
    state.template!.elements.add(newEl);
    
    state = state.copyWith(
      selectedElement: newEl,
      elementCounter: state.elementCounter + 1,
    );
  }

  void updateElementPosition(BarcodeElement e, double dx, double dy) {
    e.x += dx;
    e.y += dy;
    state = state.copyWith();
  }

  void updateElementSizeVertical(BarcodeElement e, double dy, Alignment alignment) {
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
    state = state.copyWith();
  }

  void updateElementSizeHorizontal(BarcodeElement e, double dx, Alignment alignment) {
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
    state = state.copyWith();
  }

  void updateElementContent(String content) {
    if (state.selectedElement != null) {
      state.selectedElement!.content = content;
      state = state.copyWith();
    }
  }

  void updateElementFontSize(double fontSize) {
    if (state.selectedElement != null) {
      state.selectedElement!.fontSize = fontSize;
      state = state.copyWith();
    }
  }

  void updateElementDataSource(BarcodeDataSource dataSource) {
    if (state.selectedElement != null) {
      state.selectedElement!.dataSource = dataSource;
      state = state.copyWith();
    }
  }

  void updateElementProperty(void Function() updateAction) {
    updateAction();
    state = state.copyWith();
  }
}

final barcodeDesignerProvider = NotifierProvider.autoDispose<BarcodeDesignerController, BarcodeDesignerState>(
  () => BarcodeDesignerController(),
);
