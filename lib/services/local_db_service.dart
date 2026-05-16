import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../models/schema/product_collection.dart';
import '../models/schema/order_collection.dart';

class LocalDbService {
  static final LocalDbService _instance = LocalDbService._internal();
  factory LocalDbService() => _instance;
  LocalDbService._internal();

  late Isar _isar;
  bool _isInit = false;

  Isar get db {
    if (!_isInit) throw Exception('LocalDbService not initialized!');
    return _isar;
  }

  Future<void> init() async {
    if (_isInit) return;

    final dir = await getApplicationDocumentsDirectory();

    _isar = await Isar.open(
      [ProductCollectionSchema, OrderCollectionSchema],
      directory: dir.path,
      inspector: kDebugMode, // Enable inspector in debug mode
    );

    _isInit = true;
    debugPrint('✅ Isar DB Initialized at ${dir.path}');
  }
}
