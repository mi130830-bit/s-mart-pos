part of '../customer_repository.dart';

extension CustomerRepositoryMutations on CustomerRepository {
  Future<int> saveCustomer(Customer customer) async {
    if (!_dbService.isConnected()) {
      await _dbService.connect();
    }

    // Helper: แปลง empty string เป็น null เพื่อหลีกเลี่ยง UNIQUE constraint conflict
    String? emptyToNull(String? value) {
      if (value == null || value.trim().isEmpty) return null;
      return value;
    }

    try {
      if (customer.id == 0) {
        // Insert
        const sql = '''
          INSERT INTO customer (
            memberCode, firstName, lastName, phone, currentPoints, 
            address, shippingAddress, dateOfBirth, membershipExpiryDate,
            nationalId, email, taxId, creditLimit, currentDebt, remarks, totalSpending, tierId,
            line_user_id, line_display_name, line_picture_url, distanceKm
          ) VALUES (
            :code, :fname, :lname, :phone, :points,
            :addr, :shipAddr, :dob, :exp,
            :nid, :email, :tax, :limit, :debt, :remarks, :spending, :tierId,
            :lineId, :lineName, :linePic, :distanceKm
          )
        ''';
        final params = {
          'code': customer.memberCode,
          'fname': customer.firstName,
          'lname': emptyToNull(customer.lastName),
          'phone': customer.phone,
          'points': customer.currentPoints,
          'addr': emptyToNull(customer.address),
          'shipAddr': emptyToNull(customer.shippingAddress),
          'dob': customer.dateOfBirth?.toIso8601String(),
          'exp': customer.membershipExpiryDate?.toIso8601String(),
          'nid': emptyToNull(customer.nationalId), // ✅ Fix duplicate key error
          'email': emptyToNull(customer.email),
          'tax': emptyToNull(customer.taxId),
          'limit': customer.creditLimit,
          'debt': customer.currentDebt,
          'remarks': emptyToNull(customer.remarks),
          'spending': customer.totalSpending,
          'tierId': customer.tierId,
          'distanceKm': customer.distanceKm,
          'lineId': emptyToNull(customer.lineUserId),
          'lineName': emptyToNull(customer.lineDisplayName),
          'linePic': emptyToNull(customer.linePictureUrl),
        };

        // Debug logging
        debugPrint('🔍 [CustomerRepo]: Executing INSERT...');
        debugPrint('  SQL: ${sql.replaceAll(RegExp(r'\s+'), ' ').trim()}');
        debugPrint('  Parameters:');
        params.forEach((key, value) {
          debugPrint('    $key: $value (${value.runtimeType})');
        });

        final result = await _dbService.execute(sql, params);
        debugPrint(
            '✅ [CustomerRepo]: INSERT successful, ID: ${result.lastInsertID}');
        return result.lastInsertID.toInt();
      } else {
        // Update
        const sql = '''
          UPDATE customer SET 
            memberCode = :code, firstName = :fname, lastName = :lname, phone = :phone,
            currentPoints = :points, address = :addr, shippingAddress = :shipAddr,
            dateOfBirth = :dob, membershipExpiryDate = :exp,
            nationalId = :nid, email = :email, taxId = :tax, creditLimit = :limit,
            remarks = :remarks, totalSpending = :spending,
            tierId = :tierId, distanceKm = :distanceKm,
            line_user_id = :lineId, line_display_name = :lineName, line_picture_url = :linePic
          WHERE id = :id
        ''';
        final params = {
          'id': customer.id,
          'code': customer.memberCode,
          'fname': customer.firstName,
          'lname': emptyToNull(customer.lastName),
          'phone': customer.phone,
          'points': customer.currentPoints,
          'addr': emptyToNull(customer.address),
          'shipAddr': emptyToNull(customer.shippingAddress),
          'dob': customer.dateOfBirth?.toIso8601String(),
          'exp': customer.membershipExpiryDate?.toIso8601String(),
          'nid': emptyToNull(customer.nationalId), // ✅ Fix duplicate key error
          'email': emptyToNull(customer.email),
          'tax': emptyToNull(customer.taxId),
          'limit': customer.creditLimit,
          // 'debt': customer.currentDebt, // ❌ Removed to prevent race condition
          'remarks': emptyToNull(customer.remarks),
          'spending': customer.totalSpending,
          'tierId': customer.tierId,
          'distanceKm': customer.distanceKm,
          'lineId': emptyToNull(customer.lineUserId),
          'lineName': emptyToNull(customer.lineDisplayName),
          'linePic': emptyToNull(customer.linePictureUrl),
        };

        debugPrint(
            '🔍 [CustomerRepo]: Executing UPDATE for ID: ${customer.id}');
        await _dbService.execute(sql, params);
        debugPrint('✅ [CustomerRepo]: UPDATE successful');
        return customer.id;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [CustomerRepo]: Error saving customer:');
      debugPrint('Error: $e');
      debugPrint('Stack trace:\n$stackTrace');
      return -1;
    }
  }

  Future<bool> unlinkLine(int id) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      await _dbService.execute(
        '''
        UPDATE customer SET 
          line_user_id = NULL,
          line_display_name = NULL, 
          line_picture_url = NULL
        WHERE id = :id
        ''',
        {'id': id},
      );
      await _activityRepo.log(
          action: 'UNLINK_LINE',
          details: 'ยกเลิกการเชื่อมต่อ Line ลูกค้า ID: $id');
      return true;
    } catch (e) {
      debugPrint('Error unlinking Line: $e');
      return false;
    }
  }

  Future<String?> canDeleteCustomer(int id) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      // Check Orders
      final orderRes = await _dbService.query(
          'SELECT COUNT(*) as c FROM `order` WHERE customerId = :id',
          {'id': id});
      final orderCount = int.tryParse(orderRes.first['c'].toString()) ?? 0;
      if (orderCount > 0) {
        return 'ลูกค้ามีประวัติการซื้อ $orderCount รายการ';
      }

      // Check Ledger
      final ledgerRes = await _dbService.query(
          'SELECT COUNT(*) as c FROM customer_ledger WHERE customerId = :id',
          {'id': id});
      final ledgerCount = int.tryParse(ledgerRes.first['c'].toString()) ?? 0;
      if (ledgerCount > 0) {
        return 'ลูกค้ามีประวัติธุรกรรม/หนี้ $ledgerCount รายการ';
      }

      return null; // Deletable
    } catch (e) {
      debugPrint('Error checking delete status: $e');
      return 'เกิดข้อผิดพลาดในการตรวจสอบข้อมูล';
    }
  }
}
