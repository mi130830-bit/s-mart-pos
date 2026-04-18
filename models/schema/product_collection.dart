import 'package:isar/isar.dart';

part 'product_collection.g.dart';

@collection
class ProductCollection {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  int? remoteId; // ID from MySQL/Server

  @Index(type: IndexType.value)
  late String barcode;

  @Index(type: IndexType.value, caseSensitive: false)
  late String name;

  late double price;
  double? costPrice;
  late int stock;
  String? imagePath;
  String? color;
  String? categoryId;

  late DateTime lastUpdated;
}
