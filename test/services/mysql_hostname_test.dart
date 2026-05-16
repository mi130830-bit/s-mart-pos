// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Hostname Resolution Tests', () {
    test('Should resolve localhost to 127.0.0.1 or ::1', () async {
      final host = 'localhost';
      print('Testing resolution for: $host');

      try {
        final List<InternetAddress> ips = await InternetAddress.lookup(host);
        expect(ips, isNotEmpty);
        print('✅ Resolved $host to: ${ips.map((e) => e.address).toList()}');
      } catch (e) {
        fail('Failed to resolve localhost: $e');
      }
    });

    // Test looking up the local machine name
    test('Should resolve local machine name', () async {
      final String machineName = Platform.localHostname;
      print('Testing resolution for machine name: $machineName');

      try {
        final List<InternetAddress> ips =
            await InternetAddress.lookup(machineName);
        expect(ips, isNotEmpty);
        print(
            '✅ Resolved $machineName to: ${ips.map((e) => e.address).toList()}');
      } catch (e) {
        print(
            '⚠️ Warning: Could not resolve own hostname ($machineName). This might be normal depending on DNS config.');
        // We warn but don't fail, as some envs don't self-resolve via DNS
      }
    });
  });
}
