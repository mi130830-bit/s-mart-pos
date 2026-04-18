import 'package:flutter/foundation.dart';
import '../models/promotion.dart';
import '../services/mysql_service.dart';

class PromotionRepository {
  final MySQLService _dbService = MySQLService();

  Future<void> initTable() async {
    // Note: Schema migration is handled in database_initializer.dart
    // This existing create table is for fresh installs.
    const sql = '''
      CREATE TABLE IF NOT EXISTS promotion (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        type VARCHAR(50) DEFAULT 'simple',
        startDate DATETIME,
        endDate DATETIME,
        start_time VARCHAR(10) NULL,
        end_time VARCHAR(10) NULL,
        days_of_week VARCHAR(20) NULL,
        member_only TINYINT(1) DEFAULT 0,
        priority INT DEFAULT 0,
        isActive BOOLEAN DEFAULT 1,
        conditions JSON NULL,
        rewards JSON NULL,
        
        -- Legacy columns (kept for migration scripts if needed, but we can make them nullable or ignore)
        conditionType VARCHAR(50) NULL,
        conditionValue DOUBLE DEFAULT 0.0,
        actionType VARCHAR(50) NULL,
        actionValue DOUBLE DEFAULT 0.0,
        eligibleProductIds TEXT
      );
    ''';
    await _dbService.execute(sql);

    // See if empty, maybe seed?
    /*
    final count = await _dbService.query('SELECT count(*) as c FROM promotion');
    if (count.isNotEmpty && int.parse(count.first['c'].toString()) == 0) {
      // Seed logic here if desired
    }
    */
  }

  Future<List<Promotion>> getAllPromotions({bool activeOnly = false}) async {
    if (!_dbService.isConnected()) await _dbService.connect();

    String sql = 'SELECT * FROM promotion';
    if (activeOnly) {
      sql += ' WHERE isActive = 1';
    }
    // Sort by priority desc
    sql += ' ORDER BY priority DESC, id DESC';

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
      final data = promo.toJson();
      // Remove 'id' if 0 so insert works
      if (promo.id == 0) data.remove('id');

      // JSON Encode map fields if using raw SQL builder or helper
      // MySQLService might need params.
      // Let's explicitly bind params.

      final Map<String, dynamic> bindings = {
        'name': promo.name,
        'type': promo.type,
        'start': promo.startDate?.toIso8601String(),
        'end': promo.endDate?.toIso8601String(),
        'startTime': promo.startTime,
        'endTime': promo.endTime,
        'days': promo.daysOfWeek.join(','),
        'member': promo.memberOnly ? 1 : 0,
        'priority': promo.priority,
        'active': promo.isActive ? 1 : 0,
        'conds': data[
            'conditions'], // already encoded? no toJson returns String for JSON cols?
        'rewards': data['rewards'],
      };
      // Note: Promotion.toJson() encodes conditions/rewards to JSON string.
      // So bindings['conds'] is a JSON String. This is correct for MySQL TEXT/JSON column.

      if (promo.id == 0) {
        // Insert
        const sql = '''
          INSERT INTO promotion 
            (name, type, startDate, endDate, start_time, end_time, days_of_week, member_only, priority, isActive, conditions, rewards)
          VALUES 
            (:name, :type, :start, :end, :startTime, :endTime, :days, :member, :priority, :active, :conds, :rewards)
        ''';
        await _dbService.execute(sql, bindings);
      } else {
        // Update
        bindings['id'] = promo.id;
        const sql = '''
          UPDATE promotion SET 
            name=:name, type=:type, startDate=:start, endDate=:end, 
            start_time=:startTime, end_time=:endTime, days_of_week=:days, 
            member_only=:member, priority=:priority, isActive=:active, 
            conditions=:conds, rewards=:rewards
          WHERE id=:id
        ''';
        await _dbService.execute(sql, bindings);
      }
      return true;
    } catch (e) {
      debugPrint('Error saving promotion: $e');
      return false;
    }
  }
}
