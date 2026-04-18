import 'package:isar/isar.dart';

part 'order_collection.g.dart';

@collection
class OrderCollection {
  Id id = Isar.autoIncrement;

  late String payload; // JSON body for POST /api/v1/orders

  @Index()
  bool isSynced = false;

  late DateTime createdAt;

  String? error; // Last sync error message
}
