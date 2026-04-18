class LabelData {
  final String barcode;
  final String title;
  final String? subTitle;
  final double price;
  final int quantity;

  LabelData({
    required this.barcode,
    required this.title,
    this.subTitle,
    this.price = 0,
    this.quantity = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'barcode': barcode,
      'title': title,
      'subTitle': subTitle,
      'price': price,
      'quantity': quantity,
    };
  }
}
