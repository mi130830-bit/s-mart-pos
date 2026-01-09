import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/mysql_service.dart';
import '../models/expense.dart';

class ExpenseRepository {
  final MySQLService _dbService = MySQLService();

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
          createdAt DATETIME DEFAULT CURRENT_TIMESTAMP
        ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
      ''';
      await _dbService.execute(sql);
      debugPrint('✅ Expenses table initialized successfully.');
    } catch (e) {
      debugPrint('❌ Error initializing expenses table: $e');
      // If it fails, maybe try a simpler version without character set
      try {
        debugPrint('Retrying with simpler SQL...');
        const sqlSimple = '''
          CREATE TABLE IF NOT EXISTS expense (
            id INT AUTO_INCREMENT PRIMARY KEY,
            title VARCHAR(255) NOT NULL,
            amount DOUBLE NOT NULL,
            category VARCHAR(100) NOT NULL,
            expenseDate DATETIME NOT NULL,
            note TEXT,
            createdAt DATETIME DEFAULT CURRENT_TIMESTAMP
          );
        ''';
        await _dbService.execute(sqlSimple);
        debugPrint('✅ Expenses table initialized with simpler SQL.');
      } catch (e2) {
        debugPrint('❌ Fatal Error initializing expenses table: $e2');
      }
    }
  }

  Future<int> saveExpense(Expense expense) async {
    if (expense.id == 0) {
      final res = await _dbService.execute(
        'INSERT INTO expense (title, amount, category, expenseDate, note) VALUES (:title, :amount, :category, :expenseDate, :note)',
        {
          'title': expense.title,
          'amount': expense.amount,
          'category': expense.category,
          'expenseDate': expense.date.toIso8601String(),
          'note': expense.note,
        },
      );
      return res.lastInsertID.toInt();
    } else {
      await _dbService.execute(
        'UPDATE expense SET title = :title, amount = :amount, category = :category, expenseDate = :expenseDate, note = :note WHERE id = :id',
        {
          'id': expense.id,
          'title': expense.title,
          'amount': expense.amount,
          'category': expense.category,
          'expenseDate': expense.date.toIso8601String(),
          'note': expense.note,
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
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
      },
    );
    return results.map((r) => Expense.fromMap(r)).toList();
  }

  Future<bool> deleteExpense(int id) async {
    final res = await _dbService
        .execute('DELETE FROM expense WHERE id = :id', {'id': id});
    return res.affectedRows.toInt() > 0;
  }

  Future<double> getTotalExpensesByDateRange(
      DateTime start, DateTime end) async {
    final results = await _dbService.query(
      'SELECT SUM(amount) as total FROM expense WHERE expenseDate BETWEEN :start AND :end',
      {
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
      },
    );
    if (results.isEmpty || results.first['total'] == null) return 0.0;
    return double.tryParse(results.first['total'].toString()) ?? 0.0;
  }
}
