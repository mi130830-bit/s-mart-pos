// [CRITICAL FIX] File: billing_repository.dart
import 'package:flutter/foundation.dart';
import '../services/mysql_service.dart';
import '../models/billing_note.dart';
import '../models/billing_note_item.dart';
// import '../repositories/debtor_repository.dart'; // ไม่ต้องเรียกข้าม Repo แล้ว เพื่อความชัวร์ของ Transaction

class BillingRepository {
  final MySQLService _dbService = MySQLService();

  Future<void> initTable() async {
    const sqlMain = '''
      CREATE TABLE IF NOT EXISTS billing_notes (
        id INT AUTO_INCREMENT PRIMARY KEY,
        customerId INT NOT NULL,
        documentNo VARCHAR(50) NOT NULL UNIQUE,
        issueDate DATETIME NOT NULL,
        dueDate DATETIME NOT NULL,
        totalAmount DECIMAL(15, 2) NOT NULL,
        note TEXT,
        status VARCHAR(20) DEFAULT 'PENDING',
        createdAt DATETIME DEFAULT CURRENT_TIMESTAMP
      );
    ''';
    await _dbService.execute(sqlMain);

    const sqlItems = '''
      CREATE TABLE IF NOT EXISTS billing_note_items (
        id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        billingNoteId INT NOT NULL,
        orderId INT,
        amount DECIMAL(15, 2) NOT NULL,
        CONSTRAINT fk_item_billing FOREIGN KEY (billingNoteId) REFERENCES billing_notes (id) ON DELETE CASCADE
      );
    ''';
    await _dbService.execute(sqlItems);

    try {
      final hasPaymentDate = await _dbService
          .query("SHOW COLUMNS FROM billing_notes LIKE 'paymentDate'");
      if (hasPaymentDate.isEmpty) {
        await _dbService.execute(
            "ALTER TABLE billing_notes ADD COLUMN paymentDate DATETIME DEFAULT NULL");
      }
    } catch (e) {
      debugPrint('Error ensure paymentDate: $e');
    }
  }

  Future<bool> createBillingNote(
      BillingNote note, List<BillingNoteItem> items) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    await _dbService.execute('START TRANSACTION;');

    try {
      const sqlNote = '''
        INSERT INTO billing_notes 
        (customerId, documentNo, issueDate, dueDate, totalAmount, note, status, createdAt)
        VALUES (:cid, :docNo, :issue, :due, :amt, :note, :status, NOW());
      ''';

      final res = await _dbService.execute(sqlNote, {
        'cid': note.customerId,
        'docNo': note.documentNo,
        'issue': note.issueDate.toIso8601String(),
        'due': note.dueDate.toIso8601String(),
        'amt': note.totalAmount,
        'note': note.note,
        'status': note.status,
      });

      final billingId = res.lastInsertID.toInt();

      if (items.isNotEmpty && billingId > 0) {
        const sqlItem = '''
          INSERT INTO billing_note_items (billingNoteId, orderId, amount)
          VALUES (:bid, :oid, :amt);
        ''';

        for (final item in items) {
          await _dbService.execute(sqlItem, {
            'bid': billingId,
            'oid': item.orderId,
            'amt': item.amount,
          });
        }
      }

      await _dbService.execute('COMMIT;');
      return true;
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      debugPrint('Error creating billing note: $e');
      return false;
    }
  }

  Future<List<BillingNote>> getBillingNotes({int? customerId}) async {
    try {
      String sql = '''
        SELECT b.*, c.firstName, c.lastName, COUNT(bni.id) as itemCount
        FROM billing_notes b
        LEFT JOIN customer c ON b.customerId = c.id
        LEFT JOIN billing_note_items bni ON b.id = bni.billingNoteId
      ''';

      if (customerId != null) {
        sql += ' WHERE b.customerId = :cid';
      }

      sql += ' GROUP BY b.id ORDER BY b.issueDate DESC;';

      final results = await _dbService.query(
          sql, customerId != null ? {'cid': customerId} : null);

      return await compute(_parseBillingNoteList, results);
    } catch (e) {
      debugPrint('Error fetching billing notes: $e');
      return [];
    }
  }

  Future<bool> updateStatus(
      int id, String newStatus, double totalAmount, int customerId) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    // ✅ Start Transaction
    await _dbService.execute('START TRANSACTION;');

    try {
      // 1. Update Status & Payment Date
      String sql = 'UPDATE billing_notes SET status = :st WHERE id = :id';
      if (newStatus == 'PAID') {
        sql =
            'UPDATE billing_notes SET status = :st, paymentDate = NOW() WHERE id = :id';
      } else if (newStatus == 'PENDING') {
        sql =
            'UPDATE billing_notes SET status = :st, paymentDate = NULL WHERE id = :id';
      }
      await _dbService.execute(sql, {'st': newStatus, 'id': id});

      // 2. ✅ If PAID -> Trigger Debt Payment (IN SAME TRANSACTION)
      if (newStatus == 'PAID' && totalAmount > 0) {
        // --- Atomic Debt Deduction Logic ---

        // A. Get current debt (for logging balanceBefore)
        double currentDebt = 0.0;
        final cRes = await _dbService.query(
            'SELECT currentDebt FROM customer WHERE id = :id FOR UPDATE',
            {'id': customerId});
        if (cRes.isNotEmpty) {
          currentDebt =
              double.tryParse(cRes.first['currentDebt'].toString()) ?? 0.0;
        }

        double balanceAfter = currentDebt - totalAmount;

        // B. Insert Transaction
        await _dbService.execute('''
          INSERT INTO debtor_transaction 
          (customerId, transactionType, amount, balanceBefore, balanceAfter, note, createdAt)
          VALUES (:cid, 'DEBT_PAYMENT', :amt, :bef, :aft, :note, NOW())
        ''', {
          'cid': customerId,
          'amt': -totalAmount, // Negative for payment
          'bef': currentDebt,
          'aft': balanceAfter,
          'note': 'ชำระตามใบวางบิล #$id',
        });

        // C. Update Customer Master
        await _dbService.execute(
            'UPDATE customer SET currentDebt = currentDebt - :amt WHERE id = :id',
            {'amt': totalAmount, 'id': customerId});
      }

      // ✅ Commit Everything Together
      await _dbService.execute('COMMIT;');
      return true;
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      debugPrint('Error updating billing note status: $e');
      return false;
    }
  }

  Future<bool> deleteBillingNote(int id) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      // ON DELETE CASCADE is set for items, so just deleting header is enough.
      // But let's check if we need to do anything else.
      // If status is PAID, we might want to restrict, but UI should handle that.
      // For safety, let's allow it in repo and handle permission in UI.

      await _dbService
          .execute('DELETE FROM billing_notes WHERE id = :id', {'id': id});
      return true;
    } catch (e) {
      debugPrint('Error deleting billing note: $e');
      return false;
    }
  }

  Future<bool> updateBillingNote(
      BillingNote note, List<BillingNoteItem> items) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    await _dbService.execute('START TRANSACTION;');

    try {
      // 1. Update Header
      const sqlNote = '''
        UPDATE billing_notes 
        SET documentNo = :docNo, 
            issueDate = :issue, 
            dueDate = :due, 
            totalAmount = :amt, 
            note = :note,
            customerId = :cid -- Just in case customer changed? (Unlikely but valid)
        WHERE id = :id
      ''';

      await _dbService.execute(sqlNote, {
        'id': note.id,
        'cid': note.customerId,
        'docNo': note.documentNo,
        'issue': note.issueDate.toIso8601String(),
        'due': note.dueDate.toIso8601String(),
        'amt': note.totalAmount,
        'note': note.note,
      });

      // 2. Replace Items
      // Delete old items
      await _dbService.execute(
          'DELETE FROM billing_note_items WHERE billingNoteId = :bid',
          {'bid': note.id});

      // Insert new items
      if (items.isNotEmpty) {
        const sqlItem = '''
          INSERT INTO billing_note_items (billingNoteId, orderId, amount)
          VALUES (:bid, :oid, :amt);
        ''';

        for (final item in items) {
          await _dbService.execute(sqlItem, {
            'bid': note.id,
            'oid': item.orderId,
            'amt': item.amount,
          });
        }
      }

      await _dbService.execute('COMMIT;');
      return true;
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      debugPrint('Error updating billing note: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getBillingNoteItems(int billingId) async {
    try {
      const sql = '''
        SELECT bni.*, o.createdAt as orderDate, o.grandTotal as orderTotal 
        FROM billing_note_items bni
        LEFT JOIN `order` o ON bni.orderId = o.id
        WHERE bni.billingNoteId = :bid
      ''';
      return await _dbService.query(sql, {'bid': billingId});
    } catch (e) {
      debugPrint('Error fetching billing items: $e');
      return [];
    }
  }
}

List<BillingNote> _parseBillingNoteList(List<Map<String, dynamic>> rows) {
  return rows.map((r) {
    final note = BillingNote.fromJson(r);
    final fName = r['firstName']?.toString() ?? '';
    final lName = r['lastName']?.toString() ?? '';
    return BillingNote(
      id: note.id,
      customerId: note.customerId,
      customerName: '$fName $lName'.trim(),
      documentNo: note.documentNo,
      issueDate: note.issueDate,
      dueDate: note.dueDate,
      totalAmount: note.totalAmount,
      note: note.note,
      status: note.status,
      createdAt: note.createdAt,
      itemCount: int.tryParse(r['itemCount'].toString()) ?? 0,
      paymentDate: DateTime.tryParse(r['paymentDate'].toString()),
    );
  }).toList();
}
