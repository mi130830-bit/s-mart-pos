import 'package:flutter/foundation.dart';
import '../models/promotion.dart';
import '../services/mysql_service.dart';

class PromotionRepository {
  final MySQLService _dbService = MySQLService();

  Future<void> initTable() async {
    const sql = '''
      CREATE TABLE IF NOT EXISTS promotion (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        startDate DATETIME,
        endDate DATETIME,
        isActive BOOLEAN DEFAULT 1,
        conditionType VARCHAR(50) NOT NULL,
        conditionValue DOUBLE NOT NULL DEFAULT 0.0,
        actionType VARCHAR(50) NOT NULL,
        actionValue DOUBLE NOT NULL DEFAULT 0.0,
        eligibleProductIds TEXT -- Comma separated IDs
      );
    ''';
    await _dbService.execute(sql);

    // Seed Start Data if empty
    final count = await _dbService.query('SELECT count(*) as c FROM promotion');
    if (count.isNotEmpty && int.parse(count.first['c'].toString()) == 0) {
      // Seed Sample: Spend 1000 get 100 off
      await savePromotion(Promotion(
          id: 0,
          name: 'ซื้อครบ 1,000 ลด 100',
          conditionType: ConditionType.totalSpend,
          conditionValue: 1000.0,
          actionType: ActionType.discountAmount,
          actionValue: 100.0,
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 365)),
          isActive: true));

      // Seed Sample: Buy 2 Get 1 Free (Generic - manual applied for now or logic needs catch)
      // This logic is complex ("MatchProduct"), we seed it but logic needs implementation
      /*
       await savePromotion(Promotion(
         id: 0,
         name: 'ซื้อ 2 แถม 1 (ตย.)',
         conditionType: ConditionType.itemQty,
         conditionValue: 2.0,
         actionType: ActionType.freeItem,
         actionValue: 1.0,
         isActive: false // Disable by default as logic is tricky
       ));
       */
    }
  }

  Future<List<Promotion>> getAllPromotions({bool activeOnly = false}) async {
    if (!_dbService.isConnected()) await _dbService.connect();

    String sql = 'SELECT * FROM promotion';
    if (activeOnly) {
      sql += ' WHERE isActive = 1';
      // Checks for date are usually done in App Logic or Complex Query
    }

    try {
      final results = await _dbService.query(sql);
      return results.map((r) => Promotion.fromJson(r)).toList();
    } catch (e) {
      debugPrint('Error loading promotions: $e');
      return [];
    }
  }

  Future<bool> savePromotion(Promotion promo) async {
    if (!_dbService.isConnected()) await _dbService.connect();

    try {
      if (promo.id == 0) {
        // Insert
        const sql = '''
          INSERT INTO promotion (name, startDate, endDate, isActive, conditionType, conditionValue, actionType, actionValue, eligibleProductIds)
          VALUES (:name, :start, :end, :active, :condType, :condVal, :actType, :actVal, :elig)
        ''';
        await _dbService.execute(sql, {
          'name': promo.name,
          'start': promo.startDate?.toIso8601String(),
          'end': promo.endDate?.toIso8601String(),
          'active': promo.isActive ? 1 : 0,
          'condType': promo.conditionType.name,
          'condVal': promo.conditionValue,
          'actType': promo.actionType.name,
          'actVal': promo.actionValue,
          'elig': promo.eligibleProductIds.join(',')
        });
      } else {
        // Update
        const sql = '''
          UPDATE promotion SET 
            name=:name, startDate=:start, endDate=:end, isActive=:active,
            conditionType=:condType, conditionValue=:condVal,
            actionType=:actType, actionValue=:actVal,
            eligibleProductIds=:elig
          WHERE id=:id
        ''';
        await _dbService.execute(sql, {
          'id': promo.id,
          'name': promo.name,
          'start': promo.startDate?.toIso8601String(),
          'end': promo.endDate?.toIso8601String(),
          'active': promo.isActive ? 1 : 0,
          'condType': promo.conditionType.name,
          'condVal': promo.conditionValue,
          'actType': promo.actionType.name,
          'actVal': promo.actionValue,
          'elig': promo.eligibleProductIds.join(',')
        });
      }
      return true;
    } catch (e) {
      debugPrint('Error saving promotion: $e');
      return false;
    }
  }
}
