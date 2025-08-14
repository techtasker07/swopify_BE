import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:dotenv/dotenv.dart';
import '../lib/routes/listing_routes.dart';
import '../lib/routes/trade_routes.dart';
import '../lib/routes/message_routes.dart';
import '../lib/routes/user_routes.dart';
import '../lib/middlewares/cors_middleware.dart';
import '../lib/config/database_config.dart';

void main() async {
  // Load environment variables
  var env = DotEnv(includePlatformEnvironment: true)..load();

  // Initialize Database
  try {
    await DatabaseConfig.initialize();
    print('Database initialized successfully');
  } catch (e) {
    print('Failed to initialize Database: $e');
    exit(1);
  }

  // Create a router
  final app = Router();

  // Apply routes (no auth routes)
  app.mount('/api/listings', ListingRoutes().router);
  app.mount('/api/trades', TradeRoutes().router);
  app.mount('/api/messages', MessageRoutes().router);
  app.mount('/api/users', UserRoutes().router);

  // Add a simple health check endpoint
  app.get('/health', (shelf.Request request) {
    return shelf.Response.ok(
      jsonEncode({'status': 'ok', 'timestamp': DateTime.now().toIso8601String()}),
      headers: {'content-type': 'application/json'},
    );
  });

  // Create a handler pipeline (no auth middleware)
  final handler = shelf.Pipeline()
      .addMiddleware(shelf.logRequests())
      .addMiddleware(corsMiddleware())
      .addHandler(app);

  // Get port from environment variable or use default
  final port = int.parse(env['PORT'] ?? '3000');
  final ip = env['HOST'] ?? '0.0.0.0';

  // Start server
  final server = await io.serve(handler, ip, port);
  print('Server running on http://${server.address.host}:${server.port}');

  // Handle graceful shutdown
  ProcessSignal.sigint.watch().listen((_) async {
    print('Shutting down server...');
    await DatabaseConfig.close();
    await server.close();
    exit(0);
  });
}