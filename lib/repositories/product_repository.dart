import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import '../services/local_db_service.dart';
import '../models/schema/product_collection.dart';
import '../services/mysql_service.dart';
import '../services/api_service.dart';
import '../models/product_barcode.dart';
import '../models/product.dart';
import './activity_repository.dart';
import '../services/telegram_service.dart';
import './stock_repository.dart';

part 'product/product_repository_queries.dart';
part 'product/product_repository_mutations.dart';
part 'product/product_repository_stock.dart';
part 'product/product_repository_barcodes.dart';
part 'product/product_repository_trash.dart';

enum ProductSortOption { recent, nameAsc, stockAsc, stockDesc }

class ProductRepository {
  final MySQLService _dbService = MySQLService();
  final ActivityRepository _activityRepo = ActivityRepository();

  Isar get _isar => LocalDbService().db;

  Future<void> initTable() async {
    await ensureImageUrlColumn();
  }

  Future<void> ensureImageUrlColumn() async {
    // Migration logic usually handled by Isar schema automatically
  }
}

extension StringExt on String {
  String limit(int length) => this.length > length ? substring(0, length) : this;
}
