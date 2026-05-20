part of '../customer_repository.dart';

extension CustomerRepositoryQueries on CustomerRepository {
  Future<List<MemberTier>> getAllTiers() async {
    if (!_dbService.isConnected()) await _dbService.connect();
    final results = await _dbService
        .query('SELECT * FROM member_tier ORDER BY minTotalSpending ASC');
    return results.map((r) => MemberTier.fromJson(r)).toList();
  }

  Future<List<Customer>> getAllCustomers() async {
    return getCustomersPaginated(1, 10000); // Redirect to paginated
  }

  Future<List<Customer>> getCustomersPaginated(int page, int pageSize,
      {String? searchTerm,
      bool onlyDebtors = false,
      bool onlyLineConnected = false}) async {
    if (!_dbService.isConnected()) {
      try {
        await _dbService.connect();
      } catch (e) {
        debugPrint('⚠️ Auto-connect failed in getCustomers: $e');
        return [];
      }
    }
    try {
      final offset = (page - 1) * pageSize;
      List<String> conditions = [];
      Map<String, dynamic> params = {};

      if (searchTerm != null && searchTerm.isNotEmpty) {
        conditions.add(
            '(firstName LIKE :term OR lastName LIKE :term OR phone LIKE :term OR memberCode LIKE :term)');
        params['term'] = '%$searchTerm%';
      }

      if (onlyDebtors) {
        conditions.add('currentDebt > 0.01');
      }

      if (onlyLineConnected) {
        conditions.add('(line_user_id IS NOT NULL AND line_user_id != "")');
      }

      String whereClause = conditions.isNotEmpty
          ? 'WHERE ${conditions.join(" AND ")} AND (isDeleted = 0 OR isDeleted IS NULL)'
          : 'WHERE (isDeleted = 0 OR isDeleted IS NULL)';

      params['limit'] = pageSize;
      params['offset'] = offset;

      final sql = '''
        SELECT c.*, t.name as tierName 
        FROM customer c
        LEFT JOIN member_tier t ON c.tierId = t.id
        $whereClause 
        ORDER BY c.currentDebt DESC, c.id DESC LIMIT :limit OFFSET :offset
      ''';

      final results = await _dbService.query(sql, params);

      if (results.length > 100) {
        return await compute(_parseCustomerList, results);
      } else {
        return _parseCustomerList(results);
      }
    } catch (e) {
      debugPrint('Error fetching customers paginated: $e');
      return [];
    }
  }

  Future<int> getCustomerCount(
      {String? searchTerm,
      bool onlyDebtors = false,
      bool onlyLineConnected = false}) async {
    if (!_dbService.isConnected()) {
      try {
        await _dbService.connect();
      } catch (e) {
        return 0;
      }
    }
    try {
      List<String> conditions = [];
      Map<String, dynamic> params = {};

      if (searchTerm != null && searchTerm.isNotEmpty) {
        conditions.add(
            '(firstName LIKE :term OR lastName LIKE :term OR phone LIKE :term OR memberCode LIKE :term)');
        params['term'] = '%$searchTerm%';
      }

      if (onlyDebtors) {
        conditions.add('currentDebt > 0.01');
      }

      if (onlyLineConnected) {
        conditions.add('(line_user_id IS NOT NULL AND line_user_id != "")');
      }

      String whereClause = conditions.isNotEmpty
          ? 'WHERE ${conditions.join(" AND ")} AND (isDeleted = 0 OR isDeleted IS NULL)'
          : 'WHERE (isDeleted = 0 OR isDeleted IS NULL)';

      final sql = 'SELECT COUNT(*) as c FROM customer $whereClause';
      final res = await _dbService.query(sql, params);
      if (res.isNotEmpty) {
        return int.tryParse(res.first['c'].toString()) ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint('Error counting customers: $e');
      return 0;
    }
  }

  Future<Customer?> getCustomerById(int id) async {
    if (!_dbService.isConnected()) {
      try {
        await _dbService.connect();
      } catch (e) {
        debugPrint('⚠️ Auto-connect failed in getCustomerById: $e');
        return null;
      }
    }
    try {
      final results = await _dbService.query('''
        SELECT c.*, t.name as tierName 
        FROM customer c
        LEFT JOIN member_tier t ON c.tierId = t.id
        WHERE c.id = :id
      ''', {'id': id});
      if (results.isEmpty) return null;
      return Customer.fromJson(results.first);
    } catch (e) {
      debugPrint('Error fetching customer by id: $e');
      return null;
    }
  }

  Future<double> getCurrentDebt(int customerId) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      final res = await _dbService.query(
        'SELECT currentDebt FROM customer WHERE id = :id',
        {'id': customerId},
      );
      if (res.isNotEmpty) {
        return double.tryParse(res.first['currentDebt'].toString()) ?? 0.0;
      }
      return 0.0;
    } catch (e) {
      debugPrint('Error fetching current debt: $e');
      return 0.0;
    }
  }
}

// Top-level function for compute
List<Customer> _parseCustomerList(List<Map<String, dynamic>> rows) {
  return rows.map((row) => Customer.fromJson(row)).toList();
}
