import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:dotenv/dotenv.dart';

import 'package:backend/api_router.dart';
import 'package:backend/middlewares/cors_middleware.dart';
import 'package:backend/services/print_bridge_service.dart';
import 'package:backend/services/database_migration_service.dart';
import 'package:backend/env_config.dart';

void main(List<String> args) async {
  // Load .env
  final env = DotEnv(includePlatformEnvironment: true)..load();
  final port = int.parse(env['PORT'] ?? '8080');

  // Apply additive, idempotent schema upgrades before any request is served.
  await DatabaseMigrationService().run();

  // Locate public directory dynamically
  String findPublicDir() {
    final candidateDirs = [
      'backend/public',
      'public',
      '${Directory.current.path}/backend/public',
      '${Directory.current.path}/public',
      '${File(Platform.resolvedExecutable).parent.path}/backend/public',
      '${File(Platform.resolvedExecutable).parent.path}/public',
    ];
    for (final d in candidateDirs) {
      if (Directory(d).existsSync()) return d;
    }
    return 'public';
  }

  final publicDir = findPublicDir();

  // Static file handler for bill images etc.
  final staticHandler = createStaticHandler(
    publicDir,
    defaultDocument: 'index.html',
  );

  final writableDir = EnvConfig().writableDir;
  final writableStaticHandler = createStaticHandler(writableDir);

  final writableShopDir = '$writableDir/shop';
  final shopDir = Directory(writableShopDir).existsSync()
      ? writableShopDir
      : '$publicDir/shop';
  final shopStaticHandler = Directory(shopDir).existsSync()
      ? createStaticHandler(shopDir, defaultDocument: 'index.html')
      : staticHandler;

  Response serveGpsHtml(Request req) {
    final candidatePaths = [
      '$writableDir/gps.html',
      '$publicDir/gps.html',
      'public/gps.html',
      'backend/public/gps.html',
      '${Directory.current.path}/public/gps.html',
      '${Directory.current.path}/backend/public/gps.html',
      '${File(Platform.resolvedExecutable).parent.path}/public/gps.html',
      '${File(Platform.resolvedExecutable).parent.path}/backend/public/gps.html',
    ];
    for (final p in candidatePaths) {
      final f = File(p);
      if (f.existsSync()) {
        return Response.ok(
          f.readAsStringSync(),
          headers: {'Content-Type': 'text/html; charset=utf-8'},
        );
      }
    }
    return Response.notFound('gps.html not found');
  }

  Response serveShopHtml(Request req) {
    final candidatePaths = [
      '$writableDir/shop/index.html',
      '$publicDir/shop/index.html',
      'backend/public/shop/index.html',
      'public/shop/index.html',
      '${Directory.current.path}/backend/public/shop/index.html',
      '${Directory.current.path}/public/shop/index.html',
      '${File(Platform.resolvedExecutable).parent.path}/backend/public/shop/index.html',
      '${File(Platform.resolvedExecutable).parent.path}/public/shop/index.html',
    ];
    for (final p in candidatePaths) {
      final f = File(p);
      if (f.existsSync()) {
        return Response.ok(
          f.readAsStringSync(),
          headers: {'Content-Type': 'text/html; charset=utf-8'},
        );
      }
    }
    return Response.notFound('shop/index.html not found');
  }

  // Main Router
  final router = Router()
    ..mount('/api/v1', ApiRouter().router.call)
    ..mount('/shop/', (Request req) {
      return shopStaticHandler(req);
    })
    ..mount('/public/', (Request req) {
      if (req.url.path.startsWith('bills/') ||
          req.url.path.startsWith('products/')) {
        return writableStaticHandler(req);
      }
      return staticHandler(req);
    })
    ..get('/gps.html', serveGpsHtml)
    ..get('/gps', serveGpsHtml)
    ..get('/shop.html', serveShopHtml)
    ..get('/shop', serveShopHtml)
    ..get(
      '/health',
      (Request req) => Response.ok(
        '{"status": "ok"}',
        headers: {'Content-Type': 'application/json'},
      ),
    )
    ..get('/', (Request req) => Response.ok('S-Link POS Backend API v1.0'));

  // Apply middleware pipeline
  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsMiddleware())
      .addHandler(optionsHandler(router.call));

  // Start Firestore -> MySQL Bridge
  PrintBridgeService().startBridge();

  // Start Server (Dual-stack IPv4 & IPv6 for Cloudflare Tunnel compatibility)
  final server = await HttpServer.bind(
    InternetAddress.anyIPv6,
    port,
    v6Only: false,
  );
  shelf_io.serveRequests(server, handler);

  stdout.writeln('====================================');
  stdout.writeln('  S-Link POS Backend API');
  stdout.writeln('  Listening on port ${server.port}');
  stdout.writeln('====================================');
}
