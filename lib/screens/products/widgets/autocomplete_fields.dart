import 'package:flutter/material.dart';
import '../../../../models/product_type.dart';
import '../../../../models/unit.dart';
import '../../../../widgets/common/custom_text_field.dart';

class ProductTypeAutocomplete extends StatelessWidget {
  final List<ProductType> productTypes;
  final TextEditingController controller;
  final Key? fieldKey;
  final void Function(ProductType)? onSelected;
  final void Function(String)? onChanged;

  const ProductTypeAutocomplete({
    super.key,
    required this.productTypes,
    required this.controller,
    this.fieldKey,
    this.onSelected,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return Autocomplete<ProductType>(
        key: fieldKey,
        initialValue: TextEditingValue(text: controller.text),
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return productTypes;
          }
          return productTypes.where((ProductType option) {
            return option.name
                .toLowerCase()
                .contains(textEditingValue.text.toLowerCase());
          });
        },
        displayStringForOption: (ProductType option) => option.name,
        onSelected: onSelected,
        fieldViewBuilder:
            (context, textEditingController, focusNode, onFieldSubmitted) {
          return CustomTextField(
            controller: textEditingController,
            focusNode: focusNode,
            label: 'ประเภทสินค้า *',
            selectAllOnFocus: true,
            suffixIcon: const Icon(Icons.arrow_drop_down),
            onChanged: onChanged,
            validator: (val) {
              final match = productTypes.where((t) => t.name.toLowerCase() == val?.toLowerCase());
              return match.isEmpty ? 'กรุณาเลือกประเภท' : null;
            }
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
                      AutocompleteHighlightedOption.of(listContext);
                  return ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final ProductType option = options.elementAt(index);
                      final bool isHighlighted = index == highlightedIndex;
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
    });
  }
}

class UnitAutocomplete extends StatelessWidget {
  final List<Unit> units;
  final TextEditingController controller;
  final Key? fieldKey;
  final void Function(Unit)? onSelected;
  final void Function(String)? onChanged;

  const UnitAutocomplete({
    super.key,
    required this.units,
    required this.controller,
    this.fieldKey,
    this.onSelected,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return Autocomplete<Unit>(
        key: fieldKey,
        initialValue: TextEditingValue(text: controller.text),
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return units;
          }
          return units.where((Unit option) {
            return option.name
                .toLowerCase()
                .contains(textEditingValue.text.toLowerCase());
          });
        },
        displayStringForOption: (Unit option) => option.name,
        onSelected: onSelected,
        fieldViewBuilder:
            (context, textEditingController, focusNode, onFieldSubmitted) {
          return CustomTextField(
            controller: textEditingController,
            focusNode: focusNode,
            label: 'หน่วยสินค้า *',
            selectAllOnFocus: true,
            suffixIcon: const Icon(Icons.arrow_drop_down),
            onChanged: onChanged,
            validator: (val) {
              final match = units.where((u) => u.name.toLowerCase() == val?.toLowerCase());
              return match.isEmpty ? 'กรุณาเลือกหน่วย' : null;
            }
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
                      AutocompleteHighlightedOption.of(listContext);
                  return ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final Unit option = options.elementAt(index);
                      final bool isHighlighted = index == highlightedIndex;
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
    });
  }
}

class ShelfAutocomplete extends StatelessWidget {
  final List<String> shelves;
  final TextEditingController controller;
  final Key? fieldKey;
  final void Function(String)? onSelected;
  final void Function(String)? onChanged;

  const ShelfAutocomplete({
    super.key,
    required this.shelves,
    required this.controller,
    this.fieldKey,
    this.onSelected,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return Autocomplete<String>(
        initialValue: TextEditingValue(text: controller.text),
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) return shelves;
          return shelves.where((String option) {
            return option.contains(textEditingValue.text);
          });
        },
        onSelected: onSelected,
        fieldViewBuilder:
            (context, textEditingController, focusNode, onFieldSubmitted) {
          return CustomTextField(
            key: fieldKey,
            controller: textEditingController,
            focusNode: focusNode,
            label: 'ที่เก็บ / ชั้นวาง (Shelf)',
            selectAllOnFocus: true,
            suffixIcon: const Icon(Icons.arrow_drop_down),
            onChanged: onChanged,
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
                      AutocompleteHighlightedOption.of(listContext);
                  return ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);
                      final bool isHighlighted = index == highlightedIndex;
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
    });
  }
}
