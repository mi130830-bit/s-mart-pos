part of '../product_repository.dart';

extension ProductRepositoryTrash on ProductRepository {
  Future<bool> deleteProduct(int id, {String reason = ''}) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      String productName = 'Unknown';
      try {
        final p = await getProductById(id);
        if (p != null) productName = p.name;
      } catch (_) {}

      await _dbService.execute(
        'UPDATE product SET isActive = 0, deleteReason = :reason, deletedAt = NOW() WHERE id = :id',
        {'id': id, 'reason': reason},
      );

      await _isar.writeTxn(() async {
        await _isar.productCollections.filter().remoteIdEqualTo(id).deleteAll();
      });

      await _activityRepo.log(
          action: 'DELETE_PRODUCT',
          details: 'ลบสินค้า ID: $id (Soft Delete) สาเหตุ: $reason');

      if (await TelegramService()
          .shouldNotify(TelegramService.keyNotifyDeleteProduct)) {
        TelegramService().sendMessage('🗑️ *ลบสินค้า* (Delete Product)\n'
            '━━━━━━━━━━━━━━━━━━\n'
            '📦 สินค้า: $productName\n'
            '🆔 รหัส: $id\n'
            '📝 สาเหตุ: $reason\n'
            '━━━━━━━━━━━━━━━━━━');
      }

      return true;
    } catch (e) {
      debugPrint('Error deleting product: $e');
      return false;
    }
  }

  Future<bool> restoreProduct(int id) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      await _dbService.execute(
        'UPDATE product SET isActive = 1, deletedAt = NULL, deleteReason = NULL WHERE id = :id',
        {'id': id},
      );

      await _activityRepo.log(
          action: 'RESTORE_PRODUCT', details: 'กู้คืนสินค้า ID: $id');

      final p = await getProductById(id);
      if (p != null) await _saveToIsar(p);

      return true;
    } catch (e) {
      debugPrint('Error restoring product: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getDeletedProducts() async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      final sql = '''
         SELECT * FROM product 
         WHERE isActive = 0 
           AND deletedAt IS NOT NULL 
           AND deletedAt >= DATE_SUB(NOW(), INTERVAL 15 DAY)
         ORDER BY deletedAt DESC
       ''';
      return await _dbService.query(sql);
    } catch (e) {
      debugPrint('Error fetching deleted products: $e');
      return [];
    }
  }

  Future<void> cleanOldDeletedProducts() async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      final sql = '''
        DELETE FROM product 
        WHERE isActive = 0 
          AND deletedAt < DATE_SUB(NOW(), INTERVAL 15 DAY)
          AND id NOT IN (SELECT DISTINCT productId FROM stockledger)
          AND id NOT IN (SELECT DISTINCT productId FROM orderitem)
      ''';
      final res = await _dbService.execute(sql);
      if (res.affectedRows.toInt() > 0) {
        debugPrint(
            '🧹 Auto-Cleaned ${res.affectedRows} old products (Unused ones only).');
        await _activityRepo.log(
            action: 'AUTO_CLEAN',
            details:
                'ลบสินค้าถาวร ${res.affectedRows} รายการ (เฉพาะที่ไม่ถูกใช้งาน)');
      }
    } catch (e) {
      debugPrint('Error auto-cleaning products: $e');
    }
  }
}
