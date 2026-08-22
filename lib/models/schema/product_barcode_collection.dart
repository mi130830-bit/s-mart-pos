import 'package:isar/isar.dart';

part 'product_barcode_collection.g.dart';

@collection
class ProductBarcodeCollection {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String barcode;

  @Index(type: IndexType.value)
  late int productId;

  late String unitName;
  late double price;
  late double quantity;
}
