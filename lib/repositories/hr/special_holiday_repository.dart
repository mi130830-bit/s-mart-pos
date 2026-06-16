import '../../services/mysql_service.dart';
import '../../models/hr/special_holiday.dart';

class SpecialHolidayRepository {
  final MySQLService _db = MySQLService();

  Future<void> initTable() async {
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS special_holiday (
        id INT PRIMARY KEY AUTO_INCREMENT,
        date DATE UNIQUE NOT NULL,
        name VARCHAR(255) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  Future<void> addHoliday(DateTime date, String name) async {
    await _db.execute('''
      INSERT INTO special_holiday (date, name)
      VALUES (:date, :name)
      ON DUPLICATE KEY UPDATE name = :name
    ''', {
      'date': date.toIso8601String().split('T')[0],
      'name': name,
    });
  }

  Future<void> removeHoliday(DateTime date) async {
    await _db.execute('''
      DELETE FROM special_holiday WHERE date = :date
    ''', {
      'date': date.toIso8601String().split('T')[0],
    });
  }

  Future<bool> isSpecialHoliday(DateTime date) async {
    final results = await _db.query('''
      SELECT 1 FROM special_holiday WHERE date = :date LIMIT 1
    ''', {
      'date': date.toIso8601String().split('T')[0],
    });
    return results.isNotEmpty;
  }

  Future<List<SpecialHoliday>> getAllHolidays() async {
    final results = await _db.query('''
      SELECT * FROM special_holiday ORDER BY date DESC
    ''');
    return results.map((row) => SpecialHoliday.fromJson(row)).toList();
  }

  Future<List<SpecialHoliday>> getHolidaysInRange(DateTime start, DateTime end) async {
    final results = await _db.query('''
      SELECT * FROM special_holiday
      WHERE date >= :start AND date <= :end
      ORDER BY date ASC
    ''', {
      'start': start.toIso8601String().split('T')[0],
      'end': end.toIso8601String().split('T')[0],
    });
    return results.map((row) => SpecialHoliday.fromJson(row)).toList();
  }
}
