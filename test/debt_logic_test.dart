import 'package:flutter_test/flutter_test.dart';
import 'package:decimal/decimal.dart';
import 'package:pos_desktop/services/sales/order_processing_service.dart';
import 'package:pos_desktop/repositories/debtor_repository.dart';
import 'package:pos_desktop/repositories/stock_repository.dart';
import 'package:pos_desktop/repositories/sales_repository.dart';
import 'package:pos_desktop/repositories/activity_repository.dart';
import 'package:pos_desktop/services/mysql_service.dart';
import 'package:pos_desktop/services/notification_service.dart';
import 'package:pos_desktop/models/order_item.dart';
import 'package:pos_desktop/models/customer.dart';
import 'package:pos_desktop/models/payment_record.dart';
import 'package:mysql_client_plus/mysql_client_plus.dart';

// --- Mocks ---

class MockMySQLService implements MySQLService {
  final List<String> executedSqls = [];
  final Map<String, dynamic> queryParams = {};

  @override
  Future<void> connect() async {}

  @override
  bool isConnected() => true;

  @override
  Future<IResultSet> execute(String sql, [Map<String, dynamic>? params]) async {
    executedSqls.add(sql);
    if (params != null) queryParams.addAll(params);
    return _MockResultSet();
  }

  @override
  Future<List<Map<String, dynamic>>> query(String sql,
      [Map<String, dynamic>? params]) async {
    executedSqls.add(sql);
    if (params != null) queryParams.addAll(params);

    // Smart Mock Responses
    if (sql.contains('SELECT quantity FROM orderitem')) {
      // For processReturn validation: Found existing item with qty 10
      return [
        {'quantity': 10}
      ];
    }
    if (sql.contains('SELECT customerId, paymentMethod')) {
      // For processReturn: Order details
      return [
        {'customerId': 99, 'paymentMethod': 'CREDIT'}
      ];
    }
    if (sql.contains('FROM debtor_transaction WHERE orderId')) {
      // For deleteOrder: Revert transaction
      return [
        {'amount': 500.0, 'customerId': 88}
      ];
    }

    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockResultSet implements IResultSet {
  @override
  BigInt get lastInsertID => BigInt.from(1234);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockDebtorRepository implements DebtorRepository {
  bool transactCalled = false;
  Decimal? capturedAmount;
  String? capturedType;
  int? capturedCustomerId;

  @override
  Future<Decimal> transactDebt({
    required int customerId,
    required Decimal amountChange,
    required String transactionType,
    required String note,
    int? orderId,
  }) async {
    transactCalled = true;
    capturedAmount = amountChange;
    capturedType = transactionType;
    capturedCustomerId = customerId;
    return Decimal.parse('500.00');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockActivityRepository implements ActivityRepository {
  @override
  Future<void> log({
    int? userId,
    int branchId = 1,
    required String action,
    String? details,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockStockRepository implements StockRepository {
  @override
  Future<bool> adjustStock({
    required int productId,
    required double quantityChange,
    required String type,
    String? note,
    int? orderId,
    bool useTransaction = true,
  }) async {
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockNotificationService implements NotificationService {
  @override
  Future<void> sendSaleNotification({
    required int orderId,
    required double grandTotal,
    required double received,
    required String paymentMethodStr,
    required Customer? customer,
    required List<OrderItem> items,
    bool isDelivery = false,
    int pointsEarned = 0,
    int totalPoints = 0,
  }) async {}

  @override
  Future<void> sendCreditSaleNotification({
    required int orderId,
    required double grandTotal,
    required double received,
    required List<OrderItem> items,
    required Customer customer,
    required double debtAmount,
    required double totalDebt,
    bool isDelivery = false,
    int pointsEarned = 0,
    int totalPoints = 0,
  }) async {}

  @override
  Future<bool> sendDebtNotification({
    required Customer customer,
    required int orderId,
    required double debtAmount,
    required double totalDebt,
  }) async {
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// --- Tests ---

void main() {
  group('Centralized Debt Logic Verification', () {
    late OrderProcessingService orderService;
    late SalesRepository salesRepo;
    late MockDebtorRepository mockDebtorRepo;
    late MockMySQLService mockDB;

    OrderItem createItem(int id, int qty, int price) {
      return OrderItem(
        productId: id,
        productName: 'Item $id',
        quantity: Decimal.fromInt(qty),
        price: Decimal.fromInt(price),
        total: Decimal.fromInt(qty * price),
        costPrice: Decimal.zero,
      );
    }

    setUp(() {
      mockDebtorRepo = MockDebtorRepository();
      mockDB = MockMySQLService();

      orderService = OrderProcessingService(
        dbService: mockDB,
        stockRepo: MockStockRepository(),
        debtorRepo: mockDebtorRepo,
        notificationService: MockNotificationService(),
      );

      salesRepo = SalesRepository(
        dbService: mockDB,
        activityRepo: MockActivityRepository(),
        debtorRepo: mockDebtorRepo,
      );
    });

    test('processOrder (Sale) calls DebtorRepository for Credit', () async {
      final customer = Customer(
        id: 1,
        firstName: 'Test',
        memberCode: 'C1',
        currentDebt: 0.0,
        currentPoints: 0,
      );

      final items = [createItem(1, 1, 100)];
      final payments = [PaymentRecord(method: 'CREDIT', amount: 100)];

      await orderService.processOrder(
        cart: items,
        currentCustomer: customer,
        payments: payments,
        total: 100,
        discountAmount: 0,
        grandTotal: 100,
      );

      expect(mockDebtorRepo.transactCalled, isTrue,
          reason: 'transactDebt called?');
      expect(mockDebtorRepo.capturedAmount, equals(Decimal.parse('100.0')));
      expect(mockDebtorRepo.capturedType, equals('CREDIT_SALE'));
    });

    test('processReturn calls DebtorRepository with negative amount (Refund)',
        () async {
      // Call with simple scalar args
      await salesRepo.processReturn(
        orderId: 123,
        productId: 1,
        productName: 'Item',
        returnQty: 1.0,
        price: 100.0,
      );

      expect(mockDebtorRepo.transactCalled, isTrue,
          reason: 'Should call transactDebt for Refund');
      expect(mockDebtorRepo.capturedType, equals('RETURN_REFUND'));
      expect(mockDebtorRepo.capturedAmount, equals(Decimal.parse('-100.0')),
          reason: 'Should be negative amount');
      expect(mockDebtorRepo.capturedCustomerId, equals(99));
    });

    test('deleteOrder manually reverts Customer Debt', () async {
      final orderId = 555;

      await salesRepo.deleteOrder(orderId);

      bool revertCalled = mockDB.executedSqls.any((sql) =>
          sql.contains('UPDATE customer SET currentDebt = currentDebt - :amt'));

      expect(revertCalled, isTrue,
          reason: 'Should execute SQL to revert customer debt');
      expect(mockDB.queryParams['amt'], equals(500.0));
      expect(mockDB.queryParams['id'], equals(88));
    });
  });
}
