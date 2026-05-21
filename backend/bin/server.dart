import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:dotenv/dotenv.dart';

import 'package:backend/api_router.dart';
import 'package:backend/middlewares/cors_middleware.dart';
import 'package:backend/services/print_bridge_service.dart';

void main(List<String> args) async {
  // Load .env
  final env = DotEnv(includePlatformEnvironment: true)..load();
  final port = int.parse(env['PORT'] ?? '8080');

  // Static file handler for bill images etc.
  final staticHandler = createStaticHandler(
    'public',
    defaultDocument: 'index.html',
  );

  // Main Router
  final router = Router()
    ..mount('/api/v1', ApiRouter().router.call)
    ..mount('/public/', (Request req) => staticHandler(req))
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

  // Start Server
  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);

  stdout.writeln('====================================');
  stdout.writeln('  S-Link POS Backend API');
  stdout.writeln('  Listening on port ${server.port}');
  stdout.writeln('====================================');
}
