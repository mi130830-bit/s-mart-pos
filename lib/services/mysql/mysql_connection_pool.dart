import 'dart:async';
import 'dart:io';
import 'package:mysql_client_plus/mysql_client_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../settings_service.dart';
import '../logger_service.dart';

/// Manages database connection lifecycle, secure settings persistence, and host discoveries/DNS lookups.
class MySQLConnectionManager {
  static final MySQLConnectionManager _instance = MySQLConnectionManager._internal();
  factory MySQLConnectionManager() => _instance;
  MySQLConnectionManager._internal();

  /// Exposes the active connection instance.
  MySQLConnection? connection;
  bool _isConnecting = false;
  Completer<void>? _connectionCompleter;

  /// Checks if the connection is currently open and healthy.
  bool isConnected() => connection != null && connection!.connected;

  /// ปิด connection เก่าที่อาจ stale แล้ว reconnect ใหม่สด
  /// ใช้เมื่อ query ล้มเหลวด้วย SocketException หรือ semaphore timeout
  Future<void> resetAndReconnect() async {
    if (connection != null) {
      try {
        await connection!.close();
      } catch (_) {}
      connection = null;
    }
    _isConnecting = false;
    _connectionCompleter = null;
    await connect();
  }

  /// Retrieves the current database configuration from SecureStorage.
  Future<Map<String, String?>> getConfig() async {
    const storage = FlutterSecureStorage();
    return {
      'host': await storage.read(key: 'db_host'),
      'port': await storage.read(key: 'db_port'),
      'user': await storage.read(key: 'db_user'),
      'pass': await storage.read(key: 'db_pass'),
      'db': await storage.read(key: 'db_name'),
      'machine_name': await storage.read(key: 'machine_name'),
    };
  }

  /// Checks if database configuration has been defined.
  Future<bool> hasConfig() async {
    const storage = FlutterSecureStorage();
    final host = await storage.read(key: 'db_host');
    final user = await storage.read(key: 'db_user');
    return host != null && user != null;
  }

  Future<String?> _resolveWindowsHostname(String hostname) async {
    if (!Platform.isWindows) return null;
    try {
      final result = await Process.run('ping', ['-4', '-n', '1', '-w', '1000', hostname]);
      if (result.exitCode == 0) {
        final RegExp match = RegExp(r'\[(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\]');
        final ipMatch = match.firstMatch(result.stdout.toString());
        if (ipMatch != null) return ipMatch.group(1);
        
        final RegExp match2 = RegExp(r'Reply from (\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})');
        final ipMatch2 = match2.firstMatch(result.stdout.toString());
        if (ipMatch2 != null) return ipMatch2.group(1);
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _scanSubnetForHostname(String targetHostname, int port, String user, String pass, String? db) async {
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      final List<String> myIps = [];
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (addr.address != '127.0.0.1') {
            myIps.add(addr.address);
          }
        }
      }

      if (myIps.isEmpty) return null;

      final Set<String> targetIps = {};
      for (var ip in myIps) {
        final parts = ip.split('.');
        if (parts.length == 4) {
          final base = '${parts[0]}.${parts[1]}.${parts[2]}';
          for (int i = 1; i < 255; i++) {
             final candidate = '$base.$i';
             if (candidate != ip) targetIps.add(candidate);
          }
        }
      }

      String? foundIp;
      final ipList = targetIps.toList();
      const batchSize = 50;
      
      for (int i = 0; i < ipList.length; i += batchSize) {
        if (foundIp != null) break;
        
        final batch = ipList.skip(i).take(batchSize).toList();
        final futures = batch.map((candidateIp) async {
           try {
             final socket = await Socket.connect(candidateIp, port, timeout: const Duration(milliseconds: 500));
             socket.destroy();
             return candidateIp;
           } catch (_) {
             return null;
           }
        });
        
        final results = await Future.wait(futures);
        final openIps = results.where((ip) => ip != null).cast<String>().toList();
        
        for (var openIp in openIps) {
            try {
                final conn = await MySQLConnection.createConnection(
                   host: openIp,
                   port: port,
                   userName: user,
                   password: pass,
                   databaseName: db?.isEmpty == true ? null : db,
                   secure: false,
                );
                await conn.connect().timeout(const Duration(seconds: 2));
                final rows = await conn.execute("SELECT @@hostname AS hname");
                await conn.close();
                
                if (rows.rows.isNotEmpty) {
                  final hname = rows.rows.first.assoc()['hname']?.toString() ?? '';
                  if (hname.toLowerCase() == targetHostname.toLowerCase()) {
                     foundIp = openIp;
                     break;
                  }
                }
            } catch (e) {
                LoggerService.warning('MySQLPool', 'Scanner probe failed on $openIp: $e');
            }
        }
      }
      return foundIp;
    } catch (e) {
      LoggerService.error('MySQLPool', 'Scanner Fatal Error: $e');
      return null;
    }
  }

  /// Connects to the database using configured storage values, with automatic mDNS / local host subnet scans.
  Future<void> connect() async {
    if (isConnected()) return;
    if (_isConnecting) return _connectionCompleter?.future;

    _isConnecting = true;
    _connectionCompleter = Completer<void>();

    try {
      final storage = const FlutterSecureStorage();

      final String? host = await storage.read(key: 'db_host');
      final String? portStr = await storage.read(key: 'db_port');
      final int port = int.tryParse(portStr ?? '3306') ?? 3306;
      final String? user = await storage.read(key: 'db_user');
      final String? pass = await storage.read(key: 'db_pass');
      final String? db = await storage.read(key: 'db_name');

      if (host == null || user == null) {
        throw Exception(
            'Database configuration not found. Please setup first.');
      }

      final tryDBs = [db, null];
      final secureModes = [false, true];
      final Set<String> hostsToTry = {};

      if (host != 'localhost' &&
          host != '127.0.0.1' &&
          !RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(host)) {
        try {
          final lookups = [host];
          if (!host.contains('.')) lookups.add('$host.local');
          for (var h in lookups) {
            bool resolved = false;
            try {
              final result = await InternetAddress.lookup(h)
                  .timeout(const Duration(seconds: 2));
              for (var addr in result) {
                if (addr.type == InternetAddressType.IPv4) {
                  hostsToTry.add(addr.address);
                  resolved = true;
                  LoggerService.info(
                      'MySQLPool', 'Dynamic resolved $h to IP: ${addr.address}');
                }
              }
            } catch (_) {}
            
            String? pingIp;
            if (!resolved && Platform.isWindows) {
              pingIp = await _resolveWindowsHostname(h);
              if (pingIp != null) {
                hostsToTry.add(pingIp);
                LoggerService.info('MySQLPool', 'Ping resolved $h to IP: $pingIp');
              }
            }

            if (!resolved && pingIp == null) {
              final cleanHost = h.replaceAll('.local', '');
              LoggerService.warning('MySQLPool', 'Network resolution blocked. Starting deep subnet scan for "$cleanHost"...');
              final scanIp = await _scanSubnetForHostname(cleanHost, port, user, pass ?? '', db);
              if (scanIp != null) {
                hostsToTry.add(scanIp);
                LoggerService.info('MySQLPool', 'Subnet Scanner found "$cleanHost" at IP: $scanIp');
              }
            }

            hostsToTry.add(h);
          }
        } catch (_) {}
      } else {
        hostsToTry.add(host);
      }

      Object? lastError;
      bool success = false;

      for (var currentHost in hostsToTry) {
        if (success) break;
        for (var targetDB in tryDBs) {
          if (success) break;
          for (var isSecure in secureModes) {
            if (success) break;

            try {
              LoggerService.info(
                  'MySQLPool', 'Attempting connection: $currentHost:$port | DB: ${targetDB ?? "NONE"} | Secure: $isSecure');

              connection = await MySQLConnection.createConnection(
                host: currentHost,
                port: port,
                userName: user,
                password: pass ?? '',
                databaseName: targetDB,
                secure: isSecure,
              );

              final timeout = (currentHost.endsWith('.local')) ? 3 : 5;
              await connection!.connect().timeout(Duration(seconds: timeout));

              if (connection!.connected) {
                LoggerService.info('MySQLPool', 'Connected successfully to $currentHost.');

                final isResolvedIpFromHost = (currentHost != host &&
                    RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$')
                        .hasMatch(currentHost) &&
                    !RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$')
                        .hasMatch(host));

                if (currentHost != host && !isResolvedIpFromHost) {
                  LoggerService.info('MySQLPool', 'Updating host config to $currentHost');
                  await storage.write(key: 'db_host', value: currentHost);
                  await SettingsService().syncApiUrlWithHost(currentHost);
                } else if (isResolvedIpFromHost) {
                  LoggerService.info(
                      'MySQLPool', 'Connected using mapped IP $currentHost. Config remains $host');
                }

                _connectionCompleter?.complete();
                success = true;
                return;
              }
            } catch (e) {
              lastError = e;
              LoggerService.warning(
                  'MySQLPool', 'Connection attempt failed ($currentHost): $e');
            }
          }
        }
      }

      throw Exception(
          'Could not connect to MySQL after several attempts. Last error: $lastError');
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('SocketException') ||
          errStr.contains('Failed host lookup')) {
        try {
          final storage = const FlutterSecureStorage();
          final currentHost = await storage.read(key: 'db_host');

          if (currentHost != null && !currentHost.contains('.')) {
            final mDnsHost = '$currentHost.local';
            LoggerService.warning(
                'MySQLPool', 'Failed to resolve "$currentHost". Attempting mDNS fallback to "$mDnsHost"...');

            connection = await MySQLConnection.createConnection(
              host: mDnsHost,
              port:
                  int.tryParse(await storage.read(key: 'db_port') ?? '3306') ??
                      3306,
              userName: await storage.read(key: 'db_user') ?? '',
              password: await storage.read(key: 'db_pass') ?? '',
              databaseName: await storage.read(key: 'db_name'),
              secure: false,
            );
            await connection!.connect();

            if (connection!.connected) {
              LoggerService.info('MySQLPool', 'mDNS ($mDnsHost) work! Updating config.');
              await storage.write(key: 'db_host', value: mDnsHost);
              _connectionCompleter?.complete();
              return;
            }
          }
        } catch (innerE) {
          LoggerService.error('MySQLPool', 'mDNS Fallback failed: $innerE');
        }
      }

      if (e.toString().contains('1045')) {
        throw Exception(
            'Access Denied. Please check your Username and Password.\n(Error: ${e.toString()})');
      }

      LoggerService.error('MySQLPool', 'MySQL Connection Error: $e');
      _connectionCompleter?.completeError(e);
      rethrow;
    } finally {
      _isConnecting = false;
      _connectionCompleter = null;
    }
  }

  /// Tests connection parameters before saving.
  Future<String?> testConnection({
    required String host,
    required int port,
    required String user,
    required String pass,
    required String db,
  }) async {
    final secureModes = [false, true];
    final Set<String> hostsToTry = {};

    if (host != 'localhost' &&
        host != '127.0.0.1' &&
        !RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(host)) {
      try {
        final lookups = [host];
        if (!host.contains('.')) lookups.add('$host.local');
        for (var h in lookups) {
          bool resolved = false;
          try {
            final result = await InternetAddress.lookup(h)
                .timeout(const Duration(seconds: 2));
            for (var addr in result) {
              if (addr.type == InternetAddressType.IPv4) {
                hostsToTry.add(addr.address);
                resolved = true;
              }
            }
          } catch (_) {}

          String? pingIp;
          if (!resolved && Platform.isWindows) {
            pingIp = await _resolveWindowsHostname(h);
            if (pingIp != null) {
              hostsToTry.add(pingIp);
              LoggerService.info('MySQLPool', 'Test Ping resolved $h to IP: $pingIp');
            }
          }

          if (!resolved && pingIp == null) {
             final cleanHost = h.replaceAll('.local', '');
             LoggerService.warning('MySQLPool', 'Network resolution blocked. Starting deep subnet scan for "$cleanHost"...');
             final scanIp = await _scanSubnetForHostname(cleanHost, port, user, pass, db);
             if (scanIp != null) {
                hostsToTry.add(scanIp);
                LoggerService.info('MySQLPool', 'Subnet Scanner found "$cleanHost" at IP: $scanIp');
             }
          }

          hostsToTry.add(h);
        }
      } catch (_) {}
    } else {
      hostsToTry.add(host);
    }

    if (host == 'localhost') hostsToTry.add('127.0.0.1');
    if (host == '127.0.0.1') hostsToTry.add('localhost');

    if (!host.contains('.') && host != 'localhost' && host != '127.0.0.1') {
      hostsToTry.add('$host.local');
    }

    String? lastError;

    for (var currentHost in hostsToTry) {
      for (var isSecure in secureModes) {
        MySQLConnection? testConn;
        try {
          LoggerService.info(
              'MySQLPool', 'Testing connection: $currentHost:$port (Secure: $isSecure)');
          testConn = await MySQLConnection.createConnection(
            host: currentHost,
            port: port,
            userName: user,
            password: pass,
            databaseName: db.isEmpty ? null : db,
            secure: isSecure,
          );

          await testConn.connect().timeout(const Duration(seconds: 5));
          if (testConn.connected) {
            LoggerService.info('MySQLPool', 'Test Success: $currentHost');
            await testConn.close();
            return null;
          }
        } catch (e) {
          lastError = e.toString();
          LoggerService.error('MySQLPool', 'Test Failed ($currentHost, Secure: $isSecure): $e');
        } finally {
          try {
            await testConn?.close();
          } catch (_) {}
        }
      }
    }
    return lastError ?? 'Unknown Error';
  }

  /// Persists connection settings to SecureStorage and reconnects gracefully.
  Future<void> saveConfig({
    required String host,
    required int port,
    required String user,
    required String pass,
    required String db,
    String? machineName,
  }) async {
    const storage = FlutterSecureStorage();
    await storage.write(key: 'db_host', value: host);
    await storage.write(key: 'db_port', value: port.toString());
    await storage.write(key: 'db_user', value: user);
    await storage.write(key: 'db_pass', value: pass);
    await storage.write(key: 'db_name', value: db);
    if (machineName != null && machineName.isNotEmpty) {
      await storage.write(key: 'machine_name', value: machineName);
    }

    if (connection != null) {
      try {
        if (connection!.connected) await connection!.close();
      } catch (e) {
        LoggerService.warning(
            'MySQLPool', 'Could not close MySQL connection gracefully: $e');
      }
      connection = null;
    }
    await connect();
  }
}
