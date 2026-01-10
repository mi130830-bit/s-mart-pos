import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'common/custom_text_field.dart';
import 'common/custom_buttons.dart';

class GenericSearchDialog<T> extends StatefulWidget {
  final String title;
  final String hintText;
  final Future<List<T>> Function(String query) onSearch;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final String emptyMessage;
  final VoidCallback? onScan; // Optional: for scanner button
  final bool autofocus;
  final TextEditingController? controller; // External controller

  const GenericSearchDialog({
    super.key,
    required this.title,
    required this.hintText,
    required this.onSearch,
    required this.itemBuilder,
    this.emptyMessage = 'ไม่พบข้อมูล',
    this.onScan,
    this.autofocus = true,
    this.controller,
  });

  @override
  State<GenericSearchDialog<T>> createState() => GenericSearchDialogState<T>();
}

class GenericSearchDialogState<T> extends State<GenericSearchDialog<T>> {
  late TextEditingController _searchCtrl;
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  List<T> _items = [];
  bool _isLoading = true;
  Timer? _debounce;
  String _lastQuery = '';
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _searchCtrl = widget.controller ?? TextEditingController();
    // Load initial data (empty query)
    _performSearch(_searchCtrl.text);

    // Explicitly request focus
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    // Only dispose if we created it
    if (widget.controller == null) {
      _searchCtrl.dispose();
    }
    _searchFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query != _lastQuery) {
        _performSearch(query);
      }
    });
  }

  Future<void> _performSearch(String query) async {
    _lastQuery = query;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _selectedIndex = 0; // Reset selection
    });

    try {
      final results = await widget.onSearch(query);
      if (mounted) {
        setState(() {
          _items = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('GenericSearchDialog Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() {
          if (_selectedIndex < _items.length - 1) {
            _selectedIndex++;
            _scrollToSelected();
          }
        });
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          if (_selectedIndex > 0) {
            _selectedIndex--;
            _scrollToSelected();
          }
        });
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (_items.isNotEmpty && _selectedIndex < _items.length) {
          Navigator.pop(context, _items[_selectedIndex]);
        }
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _scrollToSelected() {
    if (_scrollController.hasClients) {
      // Estimate item height or use a fixed one.
      // Since it's generic, we assume standard ListTiles ~72px or similar.
      // This is an approximation.
      const itemHeight = 72.0;
      _scrollController.animateTo(
        _selectedIndex * itemHeight,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  // Public method to accept external text updates (e.g. from scanner)
  void updateSearchText(String text) {
    _searchCtrl.text = text;
    _performSearch(text);
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.pop(context),
      },
      child: Focus(
        autofocus: false,
        // intercept keys here if focus is on the dialog but not text field?
        // Actually, we pass _handleKeyEvent to the CustomTextField's focus or specific Focus widget wrapping it.
        // But since CustomTextField usually takes focus, we should attach listener there.
        // However, CustomTextField (in this codebase) doesn't seemingly expose `onKeyEvent` directly
        // unless we wrap it.
        // So let's wrap CustomTextField with Focus widget that handles key events.
        // Wait, CustomTextField inside might consume keys?
        // Let's wrap the input row or the specific field with Focus.

        // Actually, wrapping the whole Content with a FocusScope or just using the FocusNode on CustomTextField?
        // FocusNode doesn't handle keys directly, Focus widget does.

        // Better approach: Wrap CustomTextField with Focus widget causing it to listen to keys.
        child: AlertDialog(
          title: Text(widget.title),
          content: SizedBox(
            width: 600,
            height: 600,
            child: Column(
              children: [
                // Search Bar
                Row(
                  children: [
                    Expanded(
                      child: Focus(
                        onKeyEvent: _handleKeyEvent,
                        child: CustomTextField(
                          controller: _searchCtrl,
                          focusNode: _searchFocus,
                          autofocus: widget.autofocus,
                          label: widget.hintText,
                          prefixIcon: Icons.search,
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    _onSearchChanged('');
                                    _searchFocus.requestFocus();
                                  },
                                )
                              : null,
                          onChanged: _onSearchChanged,
                          onSubmitted: (val) {
                            // Handled by key event or fallback if single item?
                            // User might expect ENTER to pick selected.
                          },
                        ),
                      ),
                    ),
                    if (widget.onScan != null) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 48,
                        child: CustomButton(
                          onPressed: () async {
                            widget.onScan!();
                          },
                          icon: Icons.qr_code_scanner,
                          label: 'Scan',
                          type: ButtonType.primary,
                          backgroundColor: Colors.indigo,
                        ),
                      ),
                    ]
                  ],
                ),
                const SizedBox(height: 10),

                // List
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _items.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off,
                                      size: 48, color: Colors.grey[300]),
                                  const SizedBox(height: 10),
                                  Text(widget.emptyMessage,
                                      style:
                                          const TextStyle(color: Colors.grey)),
                                ],
                              ),
                            )
                          : ListView.separated(
                              controller: _scrollController,
                              itemCount: _items.length,
                              separatorBuilder: (ctx, i) =>
                                  const Divider(height: 1),
                              itemBuilder: (ctx, i) {
                                final itemWidget =
                                    widget.itemBuilder(context, _items[i]);
                                final isSelected = i == _selectedIndex;
                                return Container(
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.grey[300] : null,
                                    borderRadius: BorderRadius.circular(
                                        8), // Optional rounded corners
                                  ),
                                  child: itemWidget,
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
          actions: [
            CustomButton(
              onPressed: () => Navigator.pop(context),
              label: 'ยกเลิก',
              type: ButtonType.secondary,
            ),
          ],
        ),
      ),
    );
  }
}
