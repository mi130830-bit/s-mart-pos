import 'package:flutter/material.dart';
import '../../../../models/product.dart';

class QuickMenuGridItem extends StatelessWidget {
  final Product? product;
  final bool isEditMode;
  final String hotkey;
  final double quantityInCart;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const QuickMenuGridItem({
    super.key,
    required this.product,
    required this.isEditMode,
    required this.hotkey,
    required this.quantityInCart,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: isEditMode ? onDelete : null,
      child: Card(
        color: product == null ? Colors.grey[200] : Colors.blue[50],
        elevation: product == null ? 0 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: product == null ? Colors.grey[300]! : Colors.blue,
            width: product == null ? 1 : 2,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (product != null) ...[
                      Text(
                        product!.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '฿${product!.retailPrice.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ] else
                      Icon(
                        isEditMode ? Icons.add : Icons.crop_free,
                        color: Colors.grey[400],
                        size: 30,
                      ),
                  ],
                ),
              ),
            ),
            if (isEditMode && product != null)
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: const Icon(Icons.close, size: 16, color: Colors.red),
                  onPressed: onDelete,
                ),
              ),
            if (!isEditMode) ...[
              // 1. Hotkey Hint (Bottom Right)
              if (hotkey.isNotEmpty)
                Positioned(
                  bottom: 2,
                  right: 5,
                  child: Text(
                    hotkey,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              // 2. Quantity Badge (Bottom Right)
              if (product != null && quantityInCart > 0)
                Positioned(
                  bottom: 5,
                  right: 5,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Center(
                      child: Text(
                        '${quantityInCart.toInt()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
