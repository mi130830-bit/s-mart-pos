import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../db_config.dart';
import 'dart:io';
import 'package:decimal/decimal.dart';

class DebtController {
  Router get router {
    final router = Router();
    router.post('/cod-payment', _handleCodPayment);
    return router;
  }

  Future<Response> _handleCodPayment(Request request) async {
    try {
      final payload = await request.readAsString();
      final body = jsonDecode(payload);

      final String jobId = body['jobId']?.toString() ?? '';
      final String customerIdStr = body['customerId']?.toString() ?? '';
      final String driverId = body['driverId']?.toString() ?? '';
      final double amount = double.tryParse(body['amount'].toString()) ?? 0.0;
      final int orderId = int.tryParse(body['orderId']?.toString() ?? '0') ?? 0;

      int customerId = int.tryParse(customerIdStr) ?? 0;

      final conn = await DbConfig().connection;

      // ถ้าแปลงเป็นตัวเลขไม่ได้ (เช่นได้เป็น Firebase UID "5VVbmm1u...")
      // ให้ไปดึง customerId ที่ถูกต้องจากตาราง order แทน
      if (customerId <= 0 && orderId > 0) {
        final orderRes = await conn.execute(
          'SELECT customerId FROM `order` WHERE id = :id',
          {'id': orderId},
        );
        if (orderRes.rows.isNotEmpty) {
          customerId =
              int.tryParse(
                orderRes.rows.first.assoc()['customerId']?.toString() ?? '0',
              ) ??
              0;
        }
      }

      if (customerId <= 0) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Invalid customerId'}),
        );
      }
      if (amount <= 0.0) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Amount must be greater than 0'}),
        );
      }

      final Decimal payAmount = Decimal.parse(amount.toString());

      try {
        // START TRANSACTION
        await conn.execute('START TRANSACTION;');

        String note =
            'รับชำระ COD โดยคนขับ${driverId.isNotEmpty ? " ($driverId)" : ""} (Job: $jobId)';

        try {
          // 1. Get current debt
          final custRes = await conn.execute(
            'SELECT currentDebt FROM customer WHERE id = :id FOR UPDATE',
            {'id': customerId},
          );

          if (custRes.rows.isEmpty) {
            await conn.execute('ROLLBACK;');
            return Response.notFound(
              jsonEncode({'error': 'Customer not found'}),
              headers: {'content-type': 'application/json'},
            );
          }

          final currentRow = custRes.rows.first.assoc();
          final Decimal currentDebt = Decimal.parse(
            currentRow['currentDebt']?.toString() ?? '0',
          );

          // Paying debt means REDUCING debt
          final Decimal amountChange = -payAmount;
          final Decimal balanceAfter = currentDebt + amountChange;

          // 2. Update customer debt
          await conn.execute(
            'UPDATE customer SET currentDebt = :bal WHERE id = :id',
            {'bal': balanceAfter.toDouble(), 'id': customerId},
          );

          if (orderId > 0) {
            final orderRes = await conn.execute(
              'SELECT grandTotal, received FROM `order` WHERE id = :id FOR UPDATE',
              {'id': orderId},
            );

            if (orderRes.rows.isNotEmpty) {
              final oRow = orderRes.rows.first.assoc();
              final Decimal grandTotal = Decimal.parse(
                oRow['grandTotal']?.toString() ?? '0',
              );
              final Decimal currentReceived = Decimal.parse(
                oRow['received']?.toString() ?? '0',
              );
              final Decimal newReceived = currentReceived + payAmount;

              await conn.execute(
                'UPDATE `order` SET received = :recv WHERE id = :id',
                {'recv': newReceived.toDouble(), 'id': orderId},
              );

              bool isFullyPaid =
                  (grandTotal - newReceived).abs() <= Decimal.parse('0.01');

              if (isFullyPaid) {
                await conn.execute(
                  "UPDATE `order` SET status = 'COMPLETED', paymentMethod = 'credit' WHERE id = :id",
                  {'id': orderId},
                );
                note =
                    'รับชำระปิดบิล #$orderId ปลายทาง${driverId.isNotEmpty ? " (คนขับ: $driverId)" : ""} (Job: $jobId)';
              } else {
                note =
                    'ชำระบางส่วน #$orderId ปลายทาง (เหลือ ${(grandTotal - newReceived).toStringAsFixed(2)})${driverId.isNotEmpty ? " (คนขับ: $driverId)" : ""} (Job: $jobId)';
              }
            }
          }

          // 4. Record transaction log
          final String sql = '''
            INSERT INTO debtor_transaction 
            (customerId, orderId, transactionType, amount, balanceBefore, balanceAfter, note, createdAt)
            VALUES (:cid, :oid, :type, :amt, :bBefore, :bAfter, :note, NOW());
          ''';

          await conn.execute(sql, {
            'cid': customerId,
            'oid': orderId > 0 ? orderId : null,
            'type': 'DEBT_PAYMENT',
            'amt': amountChange.toDouble(),
            'bBefore': currentDebt.toDouble(),
            'bAfter': balanceAfter.toDouble(),
            'note': note,
          });

          await conn.execute('COMMIT;');
          stdout.writeln(
            '✅ API: Processed COD Payment $amount for Job $jobId (Customer: $customerId, Order: $orderId)',
          );

          return Response.ok(
            jsonEncode({'success': true, 'message': 'ชำระหนี้ปลายทางสำเร็จ'}),
            headers: {'content-type': 'application/json'},
          );
        } catch (txError) {
          await conn.execute('ROLLBACK;');
          rethrow;
        }
      } catch (e, stack) {
        stdout.writeln('❌ API Error (COD Payment Process): $e');
        stdout.writeln(stack);
        rethrow;
      }
    } catch (e, stack) {
      stdout.writeln('❌ API Error (COD Payment Endpoint): $e');
      stdout.writeln(stack);
      return Response.internalServerError(
        body: jsonEncode({'error': 'Server Error: $e'}),
      );
    }
  }
}
