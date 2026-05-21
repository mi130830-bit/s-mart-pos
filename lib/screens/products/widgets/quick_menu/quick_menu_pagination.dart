import 'package:flutter/material.dart';

class QuickMenuPagination extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final String Function(int page) getPageName;
  final ValueChanged<int> onPageChanged;

  const QuickMenuPagination({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.getPageName,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(totalPages, (index) {
          final page = index + 1;
          String label = getPageName(page);
          if (label.isEmpty || label.startsWith('Page ')) {
            label = '$page';
          }
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: ElevatedButton(
              onPressed: () => onPageChanged(page),
              style: ElevatedButton.styleFrom(
                backgroundColor: currentPage == page ? Colors.blue : Colors.white,
                foregroundColor: currentPage == page ? Colors.white : Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                  side: const BorderSide(color: Colors.grey),
                ),
              ),
              child: Text(
                label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          );
        }),
      ),
    );
  }
}
