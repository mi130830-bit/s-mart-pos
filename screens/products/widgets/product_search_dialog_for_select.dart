import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async'; // Added for Timer
import '../../../models/product.dart';
import '../../../repositories/product_repository.dart';
import '../../../widgets/common/custom_text_field.dart';
import '../../../widgets/common/custom_buttons.dart';

class ProductSearchDialogForSelect extends StatefulWidget {
  final ProductRepository repo;

  const ProductSearchDialogForSelect({super.key, required this.repo});

  @override
  State<ProductSearchDialogForSelect> createState() =>
      _ProductSearchDialogForSelectState();
}

class _ProductSearchDialogForSelectState
    extends State<ProductSearchDialogForSelect> {
  List<Product> _filteredProducts = [];
  bool _isLoading = true;

  // Pagination State
  int _currentPage = 0;
  final int _itemsPerPage = 8;

  Timer? _debounce;
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialProducts();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialProducts() async {
    try {
      final list = await widget.repo.getRecentProducts(5);
      if (mounted) {
        setState(() {
          _filteredProducts = list;
          _isLoading = false;
          _selectedIndex = 0;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isLoading = true;
      _currentPage = 0;
      _selectedIndex = 0; // Reset selection
    });

    try {
      List<Product> results;
      if (query.isEmpty) {
        results = await widget.repo.getRecentProducts(5);
      } else {
        results =
            await widget.repo.getProductsPaginated(1, 20, searchTerm: query);
      }

      if (mounted) {
        setState(() {
          _filteredProducts = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      final totalPages = (_filteredProducts.length / _itemsPerPage).ceil();
      final startIndex = _currentPage * _itemsPerPage;
      final endIndex = (startIndex + _itemsPerPage < _filteredProducts.length)
          ? startIndex + _itemsPerPage
          : _filteredProducts.length;
      final currentListSize = (endIndex - startIndex);

      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() {
          if (_selectedIndex < currentListSize - 1) {
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
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        setState(() {
          if (_currentPage > 0) {
            _currentPage--;
            _selectedIndex = 0;
          }
        });
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        setState(() {
          if (_currentPage < totalPages - 1) {
            _currentPage++;
            _selectedIndex = 0;
          }
        });
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        // Handle Enter key for selection
        if (_filteredProducts.isNotEmpty) {
          final startIndex = _currentPage * _itemsPerPage;
          final actualIndex = startIndex + _selectedIndex;
          if (actualIndex < _filteredProducts.length) {
            Navigator.of(context).pop(_filteredProducts[actualIndex]);
          }
        }
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _scrollToSelected() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _selectedIndex * 72.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = (_filteredProducts.length / _itemsPerPage).ceil();
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage < _filteredProducts.length)
        ? startIndex + _itemsPerPage
        : _filteredProducts.length;
    final paginatedList = _filteredProducts.sublist(
        startIndex, endIndex < startIndex ? startIndex : endIndex);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: AlertDialog(
        title: const Text('ค้นหาและเลือกสินค้า'),
        content: SizedBox(
          width: 700,
          height: 600,
          child: Column(
            children: [
              // Search Field with Key Listener
              Focus(
                onKeyEvent: _handleKeyEvent,
                child: CustomTextField(
                  focusNode: _searchFocusNode,
                  label: 'พิมพ์ชื่อ หรือ Barcode เพื่อค้นหา',
                  prefixIcon: Icons.search,
                  autofocus: true,
                  onChanged: _onSearchChanged,
                  onSubmitted: (val) {
                    // Handled by _handleKeyEvent or default behavior
                  },
                ),
              ),
              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('พบทั้งหมด: ${_filteredProducts.length} รายการ'),
                  Text(
                      'หน้า ${_currentPage + 1} / ${totalPages == 0 ? 1 : totalPages}'),
                ],
              ),
              const Divider(),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredProducts.isEmpty
                        ? const Center(child: Text('ไม่พบสินค้าที่ค้นหา'))
                        : ListView.separated(
                            controller: _scrollController,
                            itemCount: paginatedList.length,
                            separatorBuilder: (ctx, i) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final product = paginatedList[index];
                              final isSelected = index == _selectedIndex;
                              return Container(
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.grey[300] : null,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ListTile(
                                  hoverColor:
                                      Colors.indigo.withValues(alpha: 0.05),
                                  title: Text(
                                    product.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    'บาร์โค้ด: ${product.barcode ?? '-'} | สต็อก: ${product.stockQuantity.toStringAsFixed(0)}',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '฿${product.retailPrice.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                            fontSize: 16),
                                      ),
                                      const SizedBox(width: 10),
                                      const Icon(Icons.chevron_right,
                                          color: Colors.grey),
                                    ],
                                  ),
                                  onTap: () {
                                    Navigator.of(context).pop(product);
                                  },
                                ),
                              );
                            },
                          ),
              ),

              // Pagination Controls
              if (totalPages > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_left),
                        onPressed: _currentPage > 0
                            ? () => setState(() {
                                  _currentPage--;
                                  _selectedIndex = 0; // Reset on page change
                                })
                            : null,
                      ),
                      const SizedBox(width: 10),
                      ...List.generate(totalPages, (index) {
                        if (index == 0 ||
                            index == totalPages - 1 ||
                            (index >= _currentPage - 2 &&
                                index <= _currentPage + 2)) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: InkWell(
                              onTap: () => setState(() {
                                _currentPage = index;
                                _selectedIndex = 0;
                              }),
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: _currentPage == index
                                    ? Colors.blue
                                    : Colors.grey[200],
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: _currentPage == index
                                        ? Colors.white
                                        : Colors.black,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          );
                        } else if (index == 1 || index == totalPages - 2) {
                          return const Text('..');
                        }
                        return const SizedBox.shrink();
                      }),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_right),
                        onPressed: _currentPage < totalPages - 1
                            ? () => setState(() {
                                  _currentPage++;
                                  _selectedIndex = 0;
                                })
                            : null,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          CustomButton(
            onPressed: () => Navigator.of(context).pop(),
            label: 'ยกเลิก',
            type: ButtonType.secondary,
          ),
        ],
      ),
    );
  }
}
