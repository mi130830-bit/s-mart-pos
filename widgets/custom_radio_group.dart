import 'package:flutter/material.dart';

class CustomRadioGroup<T> extends InheritedWidget {
  final T? groupValue;
  final ValueChanged<T?> onChanged;

  const CustomRadioGroup({
    super.key,
    required this.groupValue,
    required this.onChanged,
    required super.child,
  });

  static CustomRadioGroup<T>? of<T>(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CustomRadioGroup<T>>();
  }

  @override
  bool updateShouldNotify(CustomRadioGroup oldWidget) {
    return oldWidget.groupValue != groupValue;
  }
}
