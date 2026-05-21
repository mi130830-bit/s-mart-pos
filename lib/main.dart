import 'dart:convert';
import 'dart:async';
import 'dart:io';


import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:window_manager/window_manager.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'state/auth_provider.dart';
import 'state/theme_provider.dart';

import 'services/mysql_service.dart';
import 'services/system/backup_scheduler.dart';
import 'services/local_db_service.dart';
import 'screens/dashboard/main_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/customer_display/customer_display_screen.dart';
import 'screens/settings/initial_setup_screen.dart';
import 'services/telegram_scheduler.dart';
import 'services/telegram_service.dart';
import 'services/notification_scheduler.dart';
import 'services/delivery_reminder_scheduler.dart';
import 'services/database_initializer.dart';
import 'services/settings_service.dart';
import 'services/system/network_discovery_service.dart';
import 'theme/app_theme.dart';
import 'screens/customer_display/customer_display_repository.dart';
import 'services/command_service.dart';
import 'services/alert_service.dart';

void main(List<String> args) {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await initializeDateFormatting('th', null);

      // ---------------------------------------------------------
      // ✅ 0. ระบบป้องกันเปิดแอปซ้อน (Port Binding + PowerShell Popup)
      // ---------------------------------------------------------
      // ⚠️ ดักเฉพาะ "หน้าจอหลัก" (ไม่บล็อกหน้าจอ Customer Display)
      if (Platform.isWindows && !args.contains('multi_window')) {
        try {
          // ใช้ Port 59999 เป็นตัวล็อค (ทนทาน 100% แบบ Pure Dart ไม่ต้องง้อ win32)
          await ServerSocket.bind(InternetAddress.loopbackIPv4, 59999);
          debugPrint('✅ [System] Instance ล็อคสำเร็จ (Port 59999)');
        } catch (e) {
          debugPrint(
              '⚠️ [System] พบการเปิดแอปซ้อน! กำลังแสดง Popup แจ้งเตือน...');

          // ใช้ PowerShell เรียก Popup แจ้งเตือนของ Windows ขึ้นมา (UX ดีเยี่ยม!)
          Process.runSync('powershell', [
            '-WindowStyle',
            'Hidden',
            '-Command',
            r'''Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show("S.Mart POS กำลังทำงานอยู่แล้ว ไม่สามารถเปิดซ้อนกันได้`n(หากมองไม่เห็นหน้าต่าง ลองเช็กดูที่ Taskbar ด้านล่างครับ)", "แจ้งเตือนระบบ (S.Mart POS)")'''
          ]);

          exit(0); // ปิดแอปตัวที่ 2 ทิ่นทันที ป้องกัน Database ล็อกพัง
        }
      }

      // ✅ Pre-load connectivity settings (like api_url) from Prefs for early API access
      await SettingsService().preLoad();

      // ---------------------------------------------------------
      // ✅ 1. ส่วนจัดการ Multi Window (จอฝั่งลูกค้า)
      // ---------------------------------------------------------
      if (args.contains('multi_window')) {
        try {
          final idx = args.indexOf('multi_window');
          String windowId = "0";
          if (idx + 1 < args.length) {
            windowId = args[idx + 1];
          }

          debugPrint('🖥️ Secondary Window Starting... ID: $windowId');

          Map<String, dynamic> argument = {};
          if (idx + 2 < args.length && args[idx + 2].isNotEmpty) {
            try {
              argument = jsonDecode(args[idx + 2]) as Map<String, dynamic>;
            } catch (e) {
              debugPrint("Error decoding args: $e");
            }
          }

          await windowManager.ensureInitialized();
          final repository = CustomerDisplayRepository(windowId);

          if (argument['args1'] == 'customer_display') {
            runApp(CustomerDisplayApp(
              windowId: windowId,
              arguments: argument,
              repository: repository,
            ));
            return;
          }
        } catch (e) {
          debugPrint('🔥 [MultiWindow] Error: $e');
        }
        exit(0);
      }

      // ---------------------------------------------------------
      // ✅ 2. ส่วน Main Process (จอหลักทำงานปกติ)
      // ---------------------------------------------------------
      try {
        debugPrint('➡️ [System] About to initialize windowManager...');
        await windowManager.ensureInitialized();
        debugPrint('✅ [System] windowManager initialized.');
      } catch (e) {
        debugPrint('ERROR: windowManager failed: $e');
      }

      // ✅ [Resilience] Protect against Bootstrap failures
      try {
        debugPrint('➡️ [System] About to initialize Firebase...');
        await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform);
        debugPrint('✅ [System] Firebase initialized.');

        // ✅ [Fix] Firestore Windows SDK Race Condition workaround
        // Removed as it crashes immediately:
        // if (Platform.isWindows) {
        //   try {
        //     debugPrint('➡️ [System] About to access Firestore...');
        //     // await FirebaseFirestore.instance.collection('system_init').limit(1).get();
        //     debugPrint('✅ [System] Firestore access complete.');
        //   } catch (e) {
        //     debugPrint('⚠️ Firestore access warning: $e');
        //   }
        // }
      } catch (e) {
        debugPrint('⚠️ Firebase Initialization warning: $e');
      }

      try {
        await LocalDbService().init();
      } catch (e) {
        debugPrint('⚠️ Local DB (Isar) Initialization warning: $e');
      }

      runApp(
        const ProviderScope(
          child: PosApp(),
        ),
      );

      // Background Initialization
      Future.delayed(const Duration(milliseconds: 500), () async {
        try {
          await DatabaseInitializer.initialize();

          if (MySQLService().isConnected()) {
            await SettingsService().loadSettings();
            final shopName = SettingsService().shopName;
            if (shopName.isNotEmpty) {
              await windowManager.setTitle(shopName);
            }
            await BackupScheduler().init();
          } else {
            debugPrint(
                '⚠️ [Background Init] MySQL NOT CONNECTED. Skipping Listener.');
          }
          TelegramScheduler().start();
          NotificationScheduler().start();
          // ✅ Start end-of-month delivery reminder
          DeliveryReminderScheduler.navigatorKey = _navigatorKey;
          DeliveryReminderScheduler().start();

          // ✅ Notify App Start
          if (await TelegramService()
              .shouldNotify(TelegramService.keyNotifyAppOpen)) {
            TelegramService().sendMessage('📱 *เปิดแอปพลิเคชัน* (App Open)\n'
                '━━━━━━━━━━━━━━━━━━\n'
                '📅 เวลา: ${DateTime.now().toString().substring(0, 19)}\n'
                '💻 เครื่อง: ${Platform.localHostname}\n'
                '━━━━━━━━━━━━━━━━━━');
          }

          NetworkDiscoveryService().start();

          // ✅ [Fixed] CommandService now uses REST Polling on Windows, safe to start.
          CommandService().startListening();
        } catch (e) {
          debugPrint('⚠️ [Background Init Error]: $e');
        }
      });
    },
    (error, stack) => debugPrint('🔥 [CRITICAL]: $error\n$stack'),
  );
}

// ---------------------------------------------------------
// ✅ PosApp (ส่วนของ UI หน้าจอหลัก)
// ---------------------------------------------------------

// ✅ Global Navigator Key for background dialogs (e.g. DeliveryReminderScheduler)
final GlobalKey<NavigatorState> _navigatorKey = AlertService.navigatorKey;

class PosApp extends ConsumerStatefulWidget {
  const PosApp({super.key});
  @override
  ConsumerState<PosApp> createState() => _PosAppState();
}

class _PosAppState extends ConsumerState<PosApp> {
  @override
  void initState() {
    super.initState();
    _setupWindow();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).tryAutoLogin();
    });
  }

  Future<void> _setupWindow() async {
    const windowOptions = WindowOptions(
      size: Size(1300, 900),
      title: 'S_MartPOS',
    );
    try {
      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
        await windowManager.maximize();
      });
    } catch (e) {
      debugPrint("Warning: WindowManager setup failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final themeState = ref.watch(themeProvider);

    if (authState.isCheckingAuth) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor:
              themeState.isDarkMode ? const Color(0xFF1A1C1E) : Colors.white,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(
                  'กำลังตรวจสอบการเชื่อมต่อ...',
                  style: TextStyle(
                    fontSize: 18,
                    color: themeState.isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                FutureBuilder<Map<String, String?>>(
                  future: MySQLService().getConfig(),
                  builder: (context, snapshot) {
                    final host = snapshot.data?['host'] ?? 'localhost';
                    return Text(
                      'Target: $host',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    try {
      return MaterialApp(
        navigatorKey: _navigatorKey,
        debugShowCheckedModeBanner: false,
        themeMode: themeState.themeMode,
        theme: AppTheme.lightTheme.copyWith(
          textTheme: AppTheme.lightTheme.textTheme
              .apply(fontFamily: themeState.fontFamily),
        ),
        darkTheme: AppTheme.darkTheme.copyWith(
          textTheme: AppTheme.darkTheme.textTheme
              .apply(fontFamily: themeState.fontFamily),
        ),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('th', 'TH'), // Thai
          Locale('en', 'US'), // English
        ],
        locale: const Locale('th', 'TH'),
        home: authState.isSetupRequired
            ? const InitialSetupScreen()
            : (authState.isAuthenticated ? const MainScreen() : const LoginScreen()),
      );
    } catch (e, stack) {
      debugPrint('🔥 [Main] Error building MaterialApp: $e\n$stack');
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: Text(
            'CRITICAL ERROR:\n$e',
            style: const TextStyle(color: Colors.red, fontSize: 24),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
  }
}

// ---------------------------------------------------------
// ✅ CustomerDisplayApp (ส่วนของ UI จอฝั่งลูกค้า)
// ---------------------------------------------------------
class CustomerDisplayApp extends StatelessWidget {
  final String windowId;
  final Map<String, dynamic>? arguments;
  final CustomerDisplayRepository repository;

  const CustomerDisplayApp({
    super.key,
    required this.windowId,
    this.arguments,
    required this.repository,
  });

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Customer Display',
        theme: AppTheme.lightTheme,
        home: CustomerDisplayScreen(
          windowId: windowId,
          arguments: arguments,
        ),
      ),
    );
  }
}
