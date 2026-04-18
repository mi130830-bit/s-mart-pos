import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/mysql_service.dart';
import '../models/expense.dart';

class ExpenseRepository {
  final MySQLService _dbService = MySQLService();

  /// แปลง DateTime เป็น MySQL DATETIME format: 'YYYY-MM-DD HH:mm:ss'
  String _toMysql(DateTime dt) =>
      '${dt.year}-${_p2(dt.month)}-${_p2(dt.day)} '
      '${_p2(dt.hour)}:${_p2(dt.minute)}:${_p2(dt.second)}';
  String _p2(int n) => n.toString().padLeft(2, '0');

  Future<void> initTable() async {
    try {
      debugPrint('Initializing Expenses table...');
      const sql = '''
        CREATE TABLE IF NOT EXISTS expense (
          id INT AUTO_INCREMENT PRIMARY KEY,
          title VARCHAR(255) NOT NULL,
          amount DOUBLE NOT NULL,
          category VARCHAR(100) NOT NULL,
          expenseDate DATETIME NOT NULL,
          note TEXT,
          type VARCHAR(20) DEFAULT 'EXPENSE', -- ✅ Added Type
          createdAt DATETIME DEFAULT CURRENT_TIMESTAMP
        ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
      ''';
      await _dbService.execute(sql);

      // ✅ Schema Migration: Check if 'type' column exists, if not add it
      try {
        await _dbService.execute(
            "ALTER TABLE expense ADD COLUMN type VARCHAR(20) DEFAULT 'EXPENSE'");
        debugPrint('✅ Migrated expense table: Added type column');
      } catch (e) {
        // Column likely exists, ignore
      }

      debugPrint('✅ Expenses table initialized successfully.');
    } catch (e) {
      debugPrint('❌ Error initializing expenses table: $e');
    }
  }

  Future<int> saveExpense(Expense expense) async {
    if (expense.id == 0) {
      final res = await _dbService.execute(
        'INSERT INTO expense (title, amount, category, expenseDate, note, type) VALUES (:title, :amount, :category, :expenseDate, :note, :type)',
        {
          'title': expense.title,
          'amount': expense.amount,
          'category': expense.category,
          'expenseDate': _toMysql(expense.date), // ✅ MySQL format
          'note': expense.note,
          'type': expense.type,
        },
      );
      return res.lastInsertID.toInt();
    } else {
      await _dbService.execute(
        'UPDATE expense SET title = :title, amount = :amount, category = :category, expenseDate = :expenseDate, note = :note, type = :type WHERE id = :id',
        {
          'id': expense.id,
          'title': expense.title,
          'amount': expense.amount,
          'category': expense.category,
          'expenseDate': _toMysql(expense.date), // ✅ MySQL format
          'note': expense.note,
          'type': expense.type,
        },
      );
      return expense.id;
    }
  }

  Future<List<Expense>> getExpensesByDateRange(
      DateTime start, DateTime end) async {
    final results = await _dbService.query(
      'SELECT * FROM expense WHERE expenseDate BETWEEN :start AND :end ORDER BY expenseDate DESC',
      {
        'start': _toMysql(start), // ✅ MySQL format
        'end': _toMysql(end),
      },
    );
    return results.map((r) => Expense.fromMap(r)).toList();
  }

  Future<bool> deleteExpense(int id) async {
    final res = await _dbService
        .execute('DELETE FROM expense WHERE id = :id', {'id': id});
    return res.affectedRows.toInt() > 0;
  }

  /// Get Total Expenses (Type = EXPENSE)
  Future<double> getTotalExpensesByDateRange(
      DateTime start, DateTime end) async {
    final results = await _dbService.query(
      "SELECT SUM(amount) as total FROM expense WHERE type = 'EXPENSE' AND expenseDate BETWEEN :start AND :end",
      {
        'start': _toMysql(start),
        'end': _toMysql(end),
      },
    );
    if (results.isEmpty || results.first['total'] == null) return 0.0;
    return double.tryParse(results.first['total'].toString()) ?? 0.0;
  }

  /// Get Total Income (Type = INCOME)
  Future<double> getTotalIncomeByDateRange(DateTime start, DateTime end) async {
    final results = await _dbService.query(
      "SELECT SUM(amount) as total FROM expense WHERE type = 'INCOME' AND expenseDate BETWEEN :start AND :end",
      {
        'start': _toMysql(start),
        'end': _toMysql(end),
      },
    );
    if (results.isEmpty || results.first['total'] == null) return 0.0;
    return double.tryParse(results.first['total'].toString()) ?? 0.0;
  }
}
