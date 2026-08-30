import 'package:backend/controllers/tier_settings_controller.dart';
import 'package:backend/services/member_tier_service.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  group('Bangkok month boundary', () {
    test('changes month at 17:00 UTC on the final UTC day', () {
      final august = MemberTierRules.bangkokMonthRange(
        DateTime.utc(2026, 8, 31, 16, 59, 59),
      );
      final september = MemberTierRules.bangkokMonthRange(
        DateTime.utc(2026, 8, 31, 17),
      );

      expect(august.startUtc, DateTime.utc(2026, 7, 31, 17));
      expect(august.endUtc, DateTime.utc(2026, 8, 31, 17));
      expect(august.startDatabase, '2026-08-01 00:00:00');
      expect(august.endDatabase, '2026-09-01 00:00:00');
      expect(september.startUtc, DateTime.utc(2026, 8, 31, 17));
      expect(september.startDatabase, '2026-09-01 00:00:00');
    });

    test('program cutoff replaces month start only when it is later', () {
      expect(
        MemberTierRules.effectiveDatabaseSpendStart(
          monthStart: '2026-08-01 00:00:00',
        ),
        '2026-08-01 00:00:00',
      );
      expect(
        MemberTierRules.effectiveDatabaseSpendStart(
          monthStart: '2026-08-01 00:00:00',
          programStartedAt: '2026-08-25 14:30:00',
        ),
        '2026-08-25 14:30:00',
      );
      expect(
        MemberTierRules.effectiveDatabaseSpendStart(
          monthStart: '2026-09-01 00:00:00',
          programStartedAt: '2026-08-25 14:30:00',
        ),
        '2026-09-01 00:00:00',
      );
    });
  });

  group('monthly Regular entitlement', () {
    test('never lowers a permanent tier multiplier', () {
      final result = MemberTierRules.deriveEntitlement(
        monthlySpend: 10000,
        threshold: 10000,
        enabled: true,
        permanentMultiplier: 3,
        monthlyMultiplier: 2,
      );

      expect(result.isRegularCustomer, isTrue);
      expect(result.pointsMultiplier, 3);
      expect(result.progress, 1);
    });

    test('uses monthly multiplier only after reaching the threshold', () {
      final below = MemberTierRules.deriveEntitlement(
        monthlySpend: 9999.99,
        threshold: 10000,
        enabled: true,
        permanentMultiplier: 1.5,
        monthlyMultiplier: 2,
      );
      final reached = MemberTierRules.deriveEntitlement(
        monthlySpend: 10000,
        threshold: 10000,
        enabled: true,
        permanentMultiplier: 1.5,
        monthlyMultiplier: 2,
      );

      expect(below.isRegularCustomer, isFalse);
      expect(below.pointsMultiplier, 1.5);
      expect(below.progress, closeTo(0.999999, 0.000001));
      expect(reached.isRegularCustomer, isTrue);
      expect(reached.pointsMultiplier, 2);
    });

    test('disabled monthly benefit never changes the permanent tier', () {
      final result = MemberTierRules.deriveEntitlement(
        monthlySpend: 50000,
        threshold: 10000,
        enabled: false,
        permanentMultiplier: 1.5,
        monthlyMultiplier: 2,
      );

      expect(result.isRegularCustomer, isFalse);
      expect(result.pointsMultiplier, 1.5);
    });
  });

  group('contractor monthly entitlement', () {
    test('uses x2 base, x2.5 above 20000 and x3 above 50000', () {
      final base = MemberTierRules.deriveEntitlement(
        monthlySpend: 20000,
        threshold: 10000,
        enabled: true,
        permanentMultiplier: 1,
        monthlyMultiplier: 2,
        isContractor: true,
      );
      final pro = MemberTierRules.deriveEntitlement(
        monthlySpend: 20000.01,
        threshold: 10000,
        enabled: true,
        permanentMultiplier: 1,
        monthlyMultiplier: 2,
        isContractor: true,
      );
      final proPlus = MemberTierRules.deriveEntitlement(
        monthlySpend: 50000.01,
        threshold: 10000,
        enabled: true,
        permanentMultiplier: 2.5,
        monthlyMultiplier: 2,
        isContractor: true,
      );

      expect(base.pointsMultiplier, 2);
      expect(base.loyaltyLevel, 'CONTRACTOR');
      expect(pro.pointsMultiplier, 2.5);
      expect(pro.loyaltyLevel, 'CONTRACTOR_PRO');
      expect(pro.nextThreshold, 50000);
      expect(proPlus.pointsMultiplier, 3);
      expect(proPlus.loyaltyLevel, 'CONTRACTOR_PLUS');
      expect(proPlus.nextThreshold, isNull);
    });

    test('does not grant contractor rates to ordinary customers', () {
      final customer = MemberTierRules.deriveEntitlement(
        monthlySpend: 40000,
        threshold: 10000,
        enabled: true,
        permanentMultiplier: 1,
        monthlyMultiplier: 2,
      );
      expect(customer.pointsMultiplier, 2);
      expect(customer.loyaltyLevel, 'CUSTOMER_REGULAR');
    });
  });

  group('tier settings validation', () {
    test('accepts inclusive numeric boundaries and trims text', () {
      final minimum = MemberTierRules.validateSettingsUpdate({
        'enabled': true,
        'monthlyThreshold': 0,
        'pointsMultiplier': 1,
        'benefitTextTh': ' สิทธิ์สมาชิก ',
        'benefitTextEn': ' Member benefit ',
        'settingsVersion': 1,
        'updatedBy': 'spoofed-client-actor',
      });
      final maximum = MemberTierRules.validateSettingsUpdate({
        'enabled': false,
        'monthlyThreshold': 1000000000,
        'pointsMultiplier': 10,
        'benefitTextTh': 'สิทธิ์สมาชิก',
        'benefitTextEn': 'Member benefit',
        'settingsVersion': 99,
      });

      expect(minimum.monthlyThreshold, 0);
      expect(minimum.pointsMultiplier, 1);
      expect(minimum.benefitTextTh, 'สิทธิ์สมาชิก');
      expect(maximum.monthlyThreshold, 1000000000);
      expect(maximum.pointsMultiplier, 10);
    });

    test('rejects invalid ranges, types, text length, and version', () {
      Map<String, dynamic> valid() => {
        'enabled': true,
        'monthlyThreshold': 10000,
        'pointsMultiplier': 2,
        'benefitTextTh': 'สิทธิ์สมาชิก',
        'benefitTextEn': 'Member benefit',
        'settingsVersion': 1,
      };

      for (final invalid in [
        {...valid(), 'enabled': 1},
        {...valid(), 'monthlyThreshold': -1},
        {...valid(), 'monthlyThreshold': 1000000001},
        {...valid(), 'pointsMultiplier': 0.99},
        {...valid(), 'pointsMultiplier': 10.01},
        {...valid(), 'benefitTextTh': ''},
        {...valid(), 'benefitTextEn': List.filled(256, 'x').join()},
        {...valid(), 'settingsVersion': 0},
        {...valid(), 'settingsVersion': 1.5},
      ]) {
        expect(
          () => MemberTierRules.validateSettingsUpdate(invalid),
          throwsA(isA<MemberTierValidationException>()),
        );
      }
    });
  });

  test('member order filters are allowlisted and bounded', () {
    expect(MemberTierRules.memberOrderLimit(null), 20);
    expect(MemberTierRules.memberOrderLimit('500'), 100);
    expect(MemberTierRules.memberOrderStatus('completed'), 'COMPLETED');
    expect(MemberTierRules.memberOrderStatus('dispatched'), 'DISPATCHED');
    expect(
      () => MemberTierRules.memberOrderStatus('DROP TABLE'),
      throwsA(isA<MemberTierValidationException>()),
    );
  });

  test('cashier cannot write tier settings', () async {
    final response = await TierSettingsController().router.call(
      Request(
        'PUT',
        Uri.parse('http://local/'),
        context: {
          'user': {'id': '7', 'role': 'cashier'},
        },
      ),
    );

    expect(response.statusCode, 403);
  });
}
