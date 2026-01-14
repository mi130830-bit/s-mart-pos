import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:window_manager/window_manager.dart';

import 'firebase_options.dart';
import 'state/auth_provider.dart';
import 'state/theme_provider.dart';
import 'screens/pos/pos_state_manager.dart';
import 'services/mysql_service.dart';
import 'services/system/backup_scheduler.dart';
import 'screens/dashboard/main_screen.dart';
// import 'screens/settings/initial_setup_screen.dart'; // ❌ Removed unused import
import 'screens/auth/login_screen.dart';
import 'screens/customer_display/customer_display_screen.dart';
import 'services/telegram_scheduler.dart';
import 'services/database_initializer.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';
import 'state/customer_display_provider.dart';
import 'screens/customer_display/customer_display_repository.dart'; // ✅ Import Repository

void main(List<String> args) {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // ---------------------------------------------------------
      // ✅ 1. ส่วนจัดการ Multi Window
      // ---------------------------------------------------------
      if (args.contains('multi_window')) {
        try {
          final idx = args.indexOf('multi_window');

          // 1.1 ดึง Window ID
          String windowId = "0";
          if (idx + 1 < args.length) {
            windowId = args[idx + 1];
          }

          debugPrint('🖥️ Secondary Window Starting... ID: $windowId');

          // 1.2 ดึง Arguments
          Map<String, dynamic> argument = {};
          if (idx + 2 < args.length && args[idx + 2].isNotEmpty) {
            try {
              argument = jsonDecode(args[idx + 2]) as Map<String, dynamic>;
            } catch (e) {
              debugPrint("Error decoding args: $e");
            }
          }

          // ✅ 1.3 สำคัญ: ต้อง Initialize WindowManager ใน Process นี้ด้วย!
          await windowManager.ensureInitialized();

          // ✅ 1.4 สร้าง Repository เตรียมไว้ส่งเข้า Provider
          final repository = CustomerDisplayRepository(windowId);

          if (argument['args1'] == 'customer_display') {
            runApp(CustomerDisplayApp(
              windowId: windowId,
              arguments: argument,
              repository: repository, // ✅ ส่ง repository เข้าไป
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
        await windowManager.ensureInitialized();
      } catch (e) {
        debugPrint('ERROR: windowManager failed: $e');
      }

      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);

      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProxyProvider<AuthProvider, PosStateManager>(
              create: (_) => PosStateManager(),
              update: (_, auth, posState) =>
                  (posState ?? PosStateManager())..updateUser(auth.currentUser),
            ),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ],
          child: const PosApp(),
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
          }
          TelegramScheduler().start();
        } catch (e) {
          debugPrint('⚠️ [Background Init Error]: $e');
        }
      });
    },
    (error, stack) => debugPrint('🔥 [CRITICAL]: $error\n$stack'),
  );
}

// ... PosApp Class (เหมือนเดิม) ...
class PosApp extends StatefulWidget {
  const PosApp({super.key});
  @override
  State<PosApp> createState() => _PosAppState();
}

class _PosAppState extends State<PosApp> {
  @override
  void initState() {
    super.initState();
    _setupWindow();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().tryAutoLogin();
    });
  }

  Future<void> _setupWindow() async {
    const windowOptions = WindowOptions(
      size: Size(1300, 900),
      title: 'S_MartPOS', // ✅ Updated Title
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
    return Consumer2<AuthProvider, ThemeProvider>(
      builder: (context, auth, theme, _) {
        if (auth.isCheckingAuth) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: theme.themeMode,
          theme: AppTheme.lightTheme.copyWith(
            textTheme: AppTheme.lightTheme.textTheme
                .apply(fontFamily: theme.fontFamily),
          ),
          darkTheme: AppTheme.darkTheme.copyWith(
            textTheme: AppTheme.darkTheme.textTheme
                .apply(fontFamily: theme.fontFamily),
          ),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('th', 'TH'), Locale('en', 'US')],
          locale: const Locale('th', 'TH'),
          home: auth.isAuthenticated ? const MainScreen() : const LoginScreen(),
        );
      },
    );
  }
}

// ✅ แก้ไข Class CustomerDisplayApp ให้รับ Repository
class CustomerDisplayApp extends StatelessWidget {
  final String windowId;
  final Map<String, dynamic>? arguments;
  final CustomerDisplayRepository repository; // ✅ เพิ่มตัวแปรนี้

  const CustomerDisplayApp({
    super.key,
    required this.windowId,
    this.arguments,
    required this.repository, // ✅ รับค่าเข้ามา
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Customer Display',
      theme: AppTheme.lightTheme,
      home: ChangeNotifierProvider(
        create: (_) => CustomerDisplayProvider(
            repository), // ✅ ส่ง Repository ให้ Provider
        child: CustomerDisplayScreen(
          windowId: windowId,
          arguments: arguments,
        ),
      ),
    );
  }
}
