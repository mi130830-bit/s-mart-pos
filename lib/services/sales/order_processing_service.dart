import 'package:flutter/foundation.dart';

// Services
// Services
import '../mysql_service.dart';
//import '../firebase_service.dart';
import '../notification_service.dart';
// Repositories
import '../../repositories/stock_repository.dart';
import '../../repositories/debtor_repository.dart'; // Added
import '../../repositories/customer_repository.dart'; // Added
import 'package:decimal/decimal.dart'; // Added
import 'package:uuid/uuid.dart';

// Models
import '../../models/order_item.dart';
import '../../models/customer.dart';
import '../../models/member_tier.dart';
import '../../models/payment_record.dart';
import '../../models/delivery_type.dart';
import '../../models/promotion.dart'; // Added
import '../settings_service.dart'; // Added
import '../idempotency_payload.dart';

class OrderProcessingService {
  final MySQLService _dbService;
  final StockRepository _stockRepo;
  final DebtorRepository _debtorRepo;
  final CustomerRepository _customerRepo;
  final NotificationService _notificationService;
  final SettingsService _settings;

  OrderProcessingService({
    MySQLService? dbService,
    StockRepository? stockRepo,
    DebtorRepository? debtorRepo,
    CustomerRepository? customerRepo,
    NotificationService? notificationService,
    SettingsService? settings,
  })  : _dbService = dbService ?? MySQLService(),
        _stockRepo = stockRepo ?? StockRepository(),
        _debtorRepo = debtorRepo ?? DebtorRepository(),
        _customerRepo =
            customerRepo ?? CustomerRepository(dbService: dbService),
        _notificationService = notificationService ?? NotificationService(),
        _settings = settings ?? SettingsService();

  Future<int> processOrder({
    String? idempotencyKey,
    required List<OrderItem> cart,
    required Customer? currentCustomer,
    required List<PaymentRecord> payments,
    required double total,
    required double discountAmount,
    required double grandTotal,
    DeliveryType deliveryType = DeliveryType.none,
    Uint8List? billPdfData,
    int? userId,
    String? note,
    int pointsUsed = 0, // ✅ แต้มที่ใช้แลก
    double pointRedemptionBase = 0.0,
    String? couponCode,
    double couponDiscountAmount = 0.0,
    List<Promotion>? activePromotions, // ✅ โปรโมชั่นที่กำลัง active
    MemberTier? currentTier, // ✅ ระดับสมาชิก สำหรับคูณแต้ม
  }) async {
    // Legacy non-POS callers may omit a key; the desktop checkout always
    // supplies its persistent dialog key. Do not use this fallback for retry.
    final operationKey = idempotencyKey ?? const Uuid().v4();
    // ✅ Filter out items with 0 or negative quantity
    final filteredCart =
        cart.where((item) => item.quantity > Decimal.zero).toList();

    if (filteredCart.isEmpty) {
      throw Exception('ตะกร้าว่างเปล่า (ไม่มีรายการที่มีจำนวนมากกว่า 0)');
    }
    if (pointsUsed > 0 && couponCode != null) {
      throw ArgumentError('ไม่สามารถใช้แต้มและคูปองในบิลเดียวกันได้');
    }
    if (pointsUsed < 0 || couponDiscountAmount < 0) {
      throw ArgumentError('ส่วนลดหรือแต้มไม่ถูกต้อง');
    }
    if (couponCode != null && couponDiscountAmount > pointRedemptionBase) {
      throw ArgumentError('มูลค่าคูปองเกินยอดสินค้าหลังส่วนลด');
    }
    final payloadHash = canonicalPayloadHash({
      'customerId': currentCustomer?.id ?? 0,
      'payments': payments
          .map((payment) => {
                'method': payment.method,
                'amount': payment.amount.toStringAsFixed(4),
              })
          .toList(),
      'total': total.toStringAsFixed(4),
      'discountAmount': discountAmount.toStringAsFixed(4),
      'grandTotal': grandTotal.toStringAsFixed(4),
      'deliveryType': deliveryType.name,
      'note': note?.trim() ?? '',
      'pointsUsed': pointsUsed,
      'pointRedemptionBase': pointRedemptionBase.toStringAsFixed(4),
      'couponCode': couponCode?.toUpperCase() ?? '',
      'couponDiscountAmount': couponDiscountAmount.toStringAsFixed(4),
      'items': filteredCart
          .map((item) => {
                'productId': item.productId,
                'productName': item.productName,
                'quantity': item.quantity.toString(),
                'price': item.price.toString(),
                'discount': item.discount.toString(),
                'total': item.total.toString(),
                'conversionFactor': item.conversionFactor.toString(),
              })
          .toList(),
    });
    Future<int?> reconcile() async {
      final rows = await _dbService.query('''
        SELECT id, idempotencyPayloadHash FROM `order`
        WHERE idempotencyKey = :key LIMIT 1
      ''', {'key': operationKey});
      if (rows.isEmpty) return null;
      if (rows.first['idempotencyPayloadHash']?.toString() != payloadHash) {
        throw StateError('รหัสการชำระเงินเดิมถูกใช้กับข้อมูลคนละชุด');
      }
      return int.parse(rows.first['id'].toString());
    }

    if (!_dbService.isConnected()) {
      await _dbService.connect();
    }

    // ---------------------------------------------------------
    // 1. คำนวณยอดรับเงินจริง (ตัด Credit ออก)
    // ---------------------------------------------------------
    double received = 0.0;
    Set<String> methods = {};

    for (var p in payments) {
      bool isCredit = p.method.toUpperCase().contains('CREDIT') ||
          p.method.contains('เงินเชื่อ');

      if (!isCredit) {
        received += p.amount;
      }
      methods.add(p.method);
    }
    String paymentMethodStr = methods.join(',');

    // คำนวณเงินทอน (ถ้าจ่ายด้วยเครดิต received จะน้อยกว่ายอดรวม เงินทอนจะเป็น 0)
    final currentChange = (received - grandTotal).clamp(0.0, double.infinity);

    try {
      return await _dbService.runExclusiveTransaction(() async {
        final previous = await reconcile();
        if (previous != null) return previous;
        await _dbService.execute('START TRANSACTION;');
        try {
          // Checkout is authoritative: do not accept an arbitrary point amount
          // from a POS/S-Link client. The cap uses the pre-VAT base after ordinary
          // discounts and promotions, as agreed for this shop.
          if (pointsUsed > 0) {
            if (currentCustomer == null || currentCustomer.id <= 0) {
              throw StateError('ต้องเลือกลูกค้าก่อนใช้แต้ม');
            }
            final redemptionRate = _settings.pointRedemptionRate;
            final maxPoints = redemptionRate > 0
                ? (pointRedemptionBase * 0.75 * redemptionRate).floor()
                : 0;
            if (pointsUsed > maxPoints) {
              throw StateError('จำนวนแต้มเกินเพดาน 75% ของยอดขาย');
            }
          }
          // Status ขึ้นกับยอดรับเงิน ไม่ขึ้นกับ deliveryType
          String status =
              (received < grandTotal - 0.01) ? 'UNPAID' : 'COMPLETED';
          double debtAmt = (grandTotal - received).clamp(0.0, double.infinity);

          // 3. Insert Order Header (✅ เพิ่ม userId, changeAmount, deliveryType, note)
          // ✅ Auto-migrate: เพิ่ม column note ถ้ายังไม่มี
          try {
            final checkSql = "SHOW COLUMNS FROM `order` LIKE 'note'";
            final res = await _dbService.query(checkSql);
            if (res.isEmpty) {
              await _dbService
                  .execute('ALTER TABLE `order` ADD COLUMN note TEXT NULL');
            }
          } catch (e) {
            debugPrint('Failed to ensure note column: $e');
          }

          final sqlOrder = '''
        INSERT INTO `order` (
          customerId, total, discount, grandTotal, 
          paymentMethod, received, changeAmount, 
          userId, branchId, status, deliveryType, note,
          idempotencyKey, idempotencyPayloadHash, createdAt
        )
        VALUES (
          :cid, :total, :disc, :grand, 
          :pm, :rcv, :chg, 
          :uid, :bid, :status, :dtype, :note, :idempotencyKey, :payloadHash, NOW()
        )
      ''';

          // ✅ Validate Customer Logic (Prevent FK Error)
          dynamic validCid =
              (currentCustomer?.id == 0) ? null : currentCustomer?.id;
          if (validCid != null) {
            final checkCid = await _dbService.query(
                'SELECT id FROM customer WHERE id = :id', {'id': validCid});
            if (checkCid.isEmpty) {
              debugPrint(
                  '⚠️ Customer ID $validCid not found in MySQL. Fallback to Walk-in (NULL).');
              validCid = null;
            }
          }

          final resOrder = await _dbService.execute(sqlOrder, {
            'cid': validCid,
            'total': total,
            'disc': discountAmount,
            'grand': grandTotal,
            'pm': paymentMethodStr,
            'rcv': received,
            'chg': currentChange,
            'uid': userId ?? 1, // ✅ ใส่ userId (ถ้าไม่มี Default เป็น 1/Admin)
            'bid': 1,
            'status': status,
            'dtype': deliveryType.name,
            'note': (note != null && note.isNotEmpty) ? note : null,
            'idempotencyKey': operationKey,
            'payloadHash': payloadHash,
          });

          final orderId = resOrder.lastInsertID.toInt();

          // Consume the coupon in this same transaction. The status, owner,
          // expiry and stored discount are all checked again at checkout time.
          if (couponCode != null) {
            if (currentCustomer == null || currentCustomer.id <= 0) {
              throw StateError('ต้องเลือกลูกค้าที่เป็นเจ้าของคูปอง');
            }
            final couponResult = await _dbService.execute('''
          UPDATE reward_coupon
          SET status = 'USED', used_at = NOW(), order_id = :orderId
          WHERE coupon_code = :code
            AND customer_id = :customerId
            AND status = 'ACTIVE'
            AND expires_at > NOW()
            AND discount_value = :discount
        ''', {
              'orderId': orderId,
              'code': couponCode.toUpperCase(),
              'customerId': currentCustomer.id,
              'discount': couponDiscountAmount,
            });
            if (couponResult.affectedRows != BigInt.one) {
              throw StateError(
                  'คูปองใช้ไม่ได้ ถูกใช้แล้ว หมดอายุ หรือส่วนลดไม่ตรงกัน');
            }
            await _dbService.execute('''
          UPDATE reward_redemption rr
          JOIN reward_coupon rc ON rc.redemption_id = rr.id
          SET rr.status = 'FULFILLED'
          WHERE rc.coupon_code = :code
        ''', {'code': couponCode.toUpperCase()});
          }

          // 4. Insert Items & Cut Stock
          final sqlItem = '''
        INSERT INTO orderitem (orderId, productId, productName, quantity, price, discount, total, conversionFactor)
        VALUES (:oid, :pid, :pname, :qty, :price, :disc, :total, :factor)
      ''';

          for (var item in filteredCart) {
            await _dbService.execute(sqlItem, {
              'oid': orderId,
              'pid': item.productId,
              'pname': item.productName,
              'qty': item.quantity.toDouble(),
              'price': item.price.toDouble(),
              'disc': item.discount.toDouble(),
              'total': item.total.toDouble(),
              'factor': item.conversionFactor,
            });

            if (item.productId != 0 && item.productId != -999) {
              await _stockRepo.adjustStock(
                productId: item.productId,
                quantityChange:
                    -(item.quantity.toDouble() * item.conversionFactor),
                note: 'Sale #$orderId',
                type: 'SALE',
                useTransaction: false, // ✅ Critical Fix: External transaction
              );
            }
          }

          // 5. Insert Payments
          final sqlPayment = '''
        INSERT INTO order_payment (orderId, paymentMethod, amount, createdAt)
        VALUES (:oid, :method, :amt, NOW())
      ''';

          for (var p in payments) {
            await _dbService.execute(sqlPayment, {
              'oid': orderId,
              'method': p.method,
              'amt': p.amount,
            });
          }

          // 6. Handle Debt
          double? updatedDebtBalance; // ✅ Capture for Notification

          if (debtAmt > 0.01 &&
              currentCustomer != null &&
              currentCustomer.id != 0) {
            // ✅ Refactored: Centralized Debt Logic
            final Decimal balanceAfterDecimal = await _debtorRepo.transactDebt(
              customerId: currentCustomer.id,
              amountChange: Decimal.parse(debtAmt.toString()),
              transactionType: 'CREDIT_SALE',
              note: 'ซื้อเชื่อ (Credit Sales)',
              orderId: orderId,
            );
            updatedDebtBalance = balanceAfterDecimal.toDouble();

            // ❌ Remove old separate notification to avoid duplicates/confusion
            // _notificationService.sendDebtNotification(
            //   customer: currentCustomer,
            //   orderId: orderId,
            //   debtAmount: debtAmt,
            //   totalDebt: balanceAfterDecimal.toDouble(),
            // );
          }

          int finalEarnedPoints = 0;
          int newTotalPoints = currentCustomer?.currentPoints ?? 0;

          // 7. Update Customer Points & Spending
          if (currentCustomer != null && currentCustomer.id > 0) {
            double rate = _settings.pointPriceRate;
            if (rate <= 0) rate = 100.0; // Prevent division by zero

            // ✅ Check if Point System is Enabled
            final bool isPointEnabled = _settings.pointEnabled;
            int pointsEarned = isPointEnabled ? (grandTotal / rate).floor() : 0;

            if (isPointEnabled) {
              int bonusPoints = 0;
              double multiplier = 1.0;

              // 1. Tier Multiplier
              if (currentTier != null && currentTier.pointsMultiplier > 1.0) {
                if (currentTier.pointsMultiplier > multiplier) {
                  multiplier = currentTier.pointsMultiplier;
                }
              }

              // 2. Birthday & Birth Month Multiplier
              if (currentCustomer.dateOfBirth != null) {
                final now = DateTime.now();
                final dob = currentCustomer.dateOfBirth!;
                if (now.month == dob.month) {
                  if (now.day == dob.day) {
                    // ตรงวันเกิดได้ x2.5
                    if (2.5 > multiplier) multiplier = 2.5;
                  } else {
                    // ตรงเดือนเกิด แต่ไม่ใช่วันเกิดได้ x1.25
                    if (1.25 > multiplier) multiplier = 1.25;
                  }
                }
              }

              // 3. Campaign (Active Promotions) Multiplier & Bonus
              if (activePromotions != null) {
                for (var promo in activePromotions) {
                  final conditions = promo.conditions;
                  final minSpend = double.tryParse(
                          conditions['min_spend']?.toString() ?? '0') ??
                      0.0;

                  if (grandTotal >= minSpend) {
                    final rewards = promo.rewards;
                    final b = int.tryParse(
                            rewards['bonus_points']?.toString() ?? '0') ??
                        0;
                    bonusPoints += b;

                    final m = double.tryParse(
                            rewards['points_multiplier']?.toString() ??
                                '1.0') ??
                        1.0;
                    if (m > multiplier) multiplier = m; // Take the highest
                  }
                }
              }

              if (pointsEarned > 0 || bonusPoints > 0) {
                pointsEarned =
                    (pointsEarned * multiplier).floor() + bonusPoints;
              }
            }

            finalEarnedPoints = pointsEarned;

            try {
              await _dbService.execute(
                '''
              UPDATE customer 
              SET 
                totalSpending = totalSpending + :spending,
                lastActivity = NOW()
              WHERE id = :cid
            ''',
                {
                  'spending': grandTotal,
                  'cid': currentCustomer.id,
                },
              );
              // Redeem the balance that existed before this sale earns new points.
              // This avoids letting a customer spend points that this same bill has
              // only just generated.
              if (pointsUsed > 0) {
                await _customerRepo.redeemPoints(currentCustomer.id, pointsUsed,
                    useTransaction: false);
                debugPrint(
                    '✅ [Points] Redeemed $pointsUsed pts for order #$orderId');
              }
              if (pointsEarned > 0) {
                await _customerRepo.addPoints(currentCustomer.id, pointsEarned,
                    orderId: orderId);
              }

              newTotalPoints =
                  (currentCustomer.currentPoints + finalEarnedPoints) -
                      pointsUsed;
            } catch (e) {
              // Self-Healing: Add missing column if not exists
              if (e.toString().contains("Unknown column 'lastActivity'")) {
                debugPrint('🔧 Migrating DB: Adding lastActivity column...');
                await _dbService.execute(
                  'ALTER TABLE customer ADD COLUMN lastActivity DATETIME',
                );
                // Retry Update
                await _dbService.execute(
                  '''
                UPDATE customer 
                SET 
                  totalSpending = totalSpending + :spending,
                  lastActivity = NOW()
                WHERE id = :cid
              ''',
                  {
                    'spending': grandTotal,
                    'cid': currentCustomer.id,
                  },
                );
                if (pointsEarned > 0) {
                  await _customerRepo.addPoints(
                      currentCustomer.id, pointsEarned,
                      orderId: orderId);
                }
              } else {
                rethrow;
              }
            }
          }

          await _dbService.execute('COMMIT;');

          // Notification & Background Tasks
          // ✅ แยก Scenario ตามวิธีชำระและประเภทการส่ง
          final bool isDelivery = deliveryType != DeliveryType.none;

          if (debtAmt > 0.01 &&
              currentCustomer != null &&
              currentCustomer.id != 0) {
            // Case 3 (เงินเชื่ออย่างเดียว) หรือ Case 4 (เงินเชื่อ+ส่งของ)
            final totalDebt = updatedDebtBalance ?? debtAmt;
            _notificationService.sendCreditSaleNotification(
              orderId: orderId,
              grandTotal: grandTotal,
              received: received,
              items: filteredCart,
              customer: currentCustomer,
              debtAmount: debtAmt,
              totalDebt: totalDebt,
              isDelivery: isDelivery, // ✅ Scenario 3 vs 4
              pointsEarned: finalEarnedPoints,
              totalPoints: newTotalPoints,
            );
          } else {
            // Case 1 (เงินสด) หรือ Case 2 (เงินสด+ส่งของ)
            _notificationService.sendSaleNotification(
              orderId: orderId,
              grandTotal: grandTotal,
              received: received,
              paymentMethodStr: paymentMethodStr,
              customer: currentCustomer,
              items: filteredCart,
              isDelivery: isDelivery, // ✅ Scenario 1 vs 2
              pointsEarned: finalEarnedPoints,
              totalPoints: newTotalPoints,
            );
          }

          // Image upload is now handled only within DeliveryIntegrationService
          // if (billPdfData != null) {
          //   _uploadBillImageInBackground(orderId, billPdfData);
          // }

          return orderId;
        } catch (e) {
          try {
            await _dbService.execute('ROLLBACK;');
          } catch (_) {
            // Reconciliation happens after the exclusive scope is released.
          }
          rethrow;
        }
      });
    } catch (e) {
      final previous = await reconcile();
      if (previous != null) return previous;
      debugPrint('Error processing order: $e');
      rethrow;
    }
  }

  /*
  void _uploadBillImageInBackground(int orderId, Uint8List pdfData) async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      try {
        await for (var page in Printing.raster(pdfData, pages: [0], dpi: 200)) {
          final pngBytes = await page.toPng();
          await _firebaseService.uploadBillImage(pngBytes, 'order_$orderId');
          break;
        }
      } catch (innerError) {
        debugPrint('⚠️ Error inside Printing.raster loop: $innerError');
      }
    } catch (e) {
      debugPrint('⚠️ Background upload crash avoided: $e');
    }
  }
  */
}
