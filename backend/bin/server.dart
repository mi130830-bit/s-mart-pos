import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:dotenv/dotenv.dart';

import 'package:backend/api_router.dart';
import 'package:backend/middlewares/cors_middleware.dart';
import 'package:backend/services/print_bridge_service.dart';
import 'package:backend/env_config.dart';

void main(List<String> args) async {
  // Load .env
  final env = DotEnv(includePlatformEnvironment: true)..load();
  final port = int.parse(env['PORT'] ?? '8080');

  // Static file handler for bill images etc.
  final staticHandler = createStaticHandler(
    'public',
    defaultDocument: 'index.html',
  );

  // Writable static file handler (for bills saved in AppData/Local)
  final writableDir = EnvConfig().writableDir;
  final writableStaticHandler = createStaticHandler(
    writableDir,
  );

  Response serveGpsHtml(Request req) {
    final candidatePaths = [
      'public/gps.html',
      '${Directory.current.path}/public/gps.html',
      '${File(Platform.resolvedExecutable).parent.path}/public/gps.html',
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

  // Main Router
  final router = Router()
    ..mount('/api/v1', ApiRouter().router.call)
    ..mount('/public/', (Request req) {
      if (req.url.path.startsWith('bills/')) {
        return writableStaticHandler(req);
      }
      return staticHandler(req);
    })
    ..get('/gps.html', serveGpsHtml)
    ..get('/gps', serveGpsHtml)
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
  final server = await HttpServer.bind(InternetAddress.anyIPv6, port, v6Only: false);
  shelf_io.serveRequests(server, handler);

  stdout.writeln('====================================');
  stdout.writeln('  S-Link POS Backend API');
  stdout.writeln('  Listening on port ${server.port}');
  stdout.writeln('====================================');
}
