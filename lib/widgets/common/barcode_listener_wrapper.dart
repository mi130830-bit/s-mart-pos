import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A wrapper widget that listens for barcode input (Hardware Keyboard events).
/// It buffers potential barcode characters and triggers [onBarcodeScanned]
/// when the Enter key is pressed.
class BarcodeListenerWrapper extends StatefulWidget {
  final Widget child;
  final Function(String) onBarcodeScanned;
  final bool autoFocus;

  const BarcodeListenerWrapper({
    super.key,
    required this.child,
    required this.onBarcodeScanned,
    this.autoFocus = true,
  });

  @override
  State<BarcodeListenerWrapper> createState() => _BarcodeListenerWrapperState();
}

class _BarcodeListenerWrapperState extends State<BarcodeListenerWrapper> {
  final FocusNode _focusNode = FocusNode();
  final StringBuffer _buffer = StringBuffer();
  Timer? _bufferClearTimer;

  @override
  void initState() {
    super.initState();
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Request focus to ensure we catch events
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _bufferClearTimer?.cancel();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final logicalKey = event.logicalKey;

      // Check for Enter Key (Scanner usually ends with Enter)
      if (logicalKey == LogicalKeyboardKey.enter ||
          logicalKey == LogicalKeyboardKey.numpadEnter) {
        if (_buffer.isNotEmpty) {
          final barcode = _buffer.toString();
          _buffer.clear();
          widget.onBarcodeScanned(barcode);
        }
        return;
      }

      // Filter for printable characters (letters, numbers, symbols)
      // We rely on 'character' if available
      if (event.character != null && event.character!.isNotEmpty) {
        // Ignore control characters
        if (!RegExp(r'[\x00-\x1F\x7F]').hasMatch(event.character!)) {
          _buffer.write(event.character);

          // Reset clear timer
          _bufferClearTimer?.cancel();
          _bufferClearTimer = Timer(const Duration(seconds: 2), () {
            _buffer.clear();
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: widget.child,
    );
  }
}
