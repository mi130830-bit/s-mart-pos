part of '../customer_repository.dart';

extension CustomerRepositoryPoints on CustomerRepository {
  Future<void> addPoints(int customerId, int amount, {int? orderId}) async {
    if (amount <= 0) return;
    if (!_dbService.isConnected()) await _dbService.connect();

    try {
      // คำนวณวันหมดอายุแบบครึ่งปี (Semi-annual)
      // ซื้อ ม.ค.-มิ.ย. -> หมดอายุ 30 มิ.ย. ปีหน้า
      // ซื้อ ก.ค.-ธ.ค. -> หมดอายุ 31 ธ.ค. ปีหน้า
      final now = DateTime.now();
      String expStr;
      if (now.month <= 6) {
        expStr = '${now.year + 1}-06-30 23:59:59';
      } else {
        expStr = '${now.year + 1}-12-31 23:59:59';
      }

      // Insert to ledger with calculated expiration
      await _dbService.execute('''
        INSERT INTO point_ledger (customer_id, points_earned, order_id, expires_at)
        VALUES (:cid, :pts, :oid, :exp)
      ''', {
        'cid': customerId,
        'pts': amount,
        'oid': orderId,
        'exp': expStr,
      });
      // Recalculate and update currentPoints in customer table
      await recalculateCustomerPoints(customerId);
    } catch (e) {
      debugPrint('Error adding points: $e');
    }
  }

  Future<void> redeemPoints(int customerId, int amountToUse) async {
    if (amountToUse <= 0) return;
    if (!_dbService.isConnected()) await _dbService.connect();

    await _dbService.execute('START TRANSACTION;');
    try {
      // 1. Get available ledgers ordered by expires_at ASC (FIFO)
      final res = await _dbService.query('''
        SELECT id, (points_earned - points_used) as available
        FROM point_ledger
        WHERE customer_id = :cid
          AND (points_earned > points_used)
          AND (expires_at IS NULL OR expires_at > NOW())
        ORDER BY expires_at ASC
      ''', {'cid': customerId});

      int remainingToRedeem = amountToUse;

      for (var row in res) {
        if (remainingToRedeem <= 0) break;

        final ledgerId = int.tryParse(row['id']?.toString() ?? '0') ?? 0;
        final available =
            double.tryParse(row['available']?.toString() ?? '0')?.toInt() ?? 0;

        if (available <= 0) continue;

        int usedNow = 0;
        if (available >= remainingToRedeem) {
          usedNow = remainingToRedeem;
          remainingToRedeem = 0;
        } else {
          usedNow = available;
          remainingToRedeem -= available;
        }

        await _dbService.execute('''
          UPDATE point_ledger
          SET points_used = points_used + :used
          WHERE id = :lid
        ''', {'used': usedNow, 'lid': ledgerId});
      }

      await _dbService.execute('COMMIT;');
      
      // Even if not enough points in ledger (e.g. legacy mismatch or over-deducted), just recalculate
      await recalculateCustomerPoints(customerId);
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      debugPrint('Error redeeming points: $e');
    }
  }

  Future<void> recalculateCustomerPoints(int customerId) async {
    try {
      // Sum valid points
      final res = await _dbService.query('''
        SELECT SUM(points_earned - points_used) as total
        FROM point_ledger
        WHERE customer_id = :cid
          AND (points_earned > points_used)
          AND (expires_at IS NULL OR expires_at > NOW())
      ''', {'cid': customerId});

      int newTotal = 0;
      if (res.isNotEmpty) {
        newTotal =
            double.tryParse(res.first['total']?.toString() ?? '0')?.toInt() ??
                0;
      }

      // Update main customer table to keep it in sync for fast read
      await _dbService.execute('''
        UPDATE customer SET currentPoints = :pts WHERE id = :cid
      ''', {'pts': newTotal, 'cid': customerId});
    } catch (e) {
      debugPrint('Error recalculating points: $e');
    }
  }

  Future<void> updatePoints(int customerId, int pointsToAdd) async {
    if (pointsToAdd > 0) {
      await addPoints(customerId, pointsToAdd);
    } else if (pointsToAdd < 0) {
      await redeemPoints(customerId, pointsToAdd.abs());
    } else {
      await recalculateCustomerPoints(customerId); // Just refresh if 0
    }
  }

  Future<int> clearAllPoints() async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      // Set points_used = points_earned for all non-expired records
      await _dbService.execute('''
        UPDATE point_ledger 
        SET points_used = points_earned 
        WHERE points_earned > points_used 
          AND (expires_at IS NULL OR expires_at > NOW())
      ''');

      final res = await _dbService.execute(
          'UPDATE customer SET currentPoints = 0 WHERE currentPoints > 0');

      if (res.affectedRows.toInt() > 0) {
        await _activityRepo.log(
            action: 'CLEAR_POINTS',
            details: 'ล้างคะแนนสะสมทั้งหมด (${res.affectedRows} รายการ)');
      }
      return res.affectedRows.toInt();
    } catch (e) {
      debugPrint('Error clearing points: $e');
      return 0;
    }
  }
}
