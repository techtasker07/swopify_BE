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
  try {
    // Load environment variables
    var env = DotEnv(includePlatformEnvironment: true)..load();
    print('Environment variables loaded');

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

  // Add root route
  app.get('/', (shelf.Request request) {
    return shelf.Response.ok(
      jsonEncode({
        'message': 'Swopify Backend API',
        'version': '1.0.0',
        'status': 'running',
        'timestamp': DateTime.now().toIso8601String(),
        'endpoints': {
          'health': '/health',
          'listings': '/api/listings',
          'trades': '/api/trades',
          'messages': '/api/messages',
          'users': '/api/users'
        }
      }),
      headers: {'content-type': 'application/json'},
    );
  });

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

  // Add API info endpoint
  app.get('/api', (shelf.Request request) {
    return shelf.Response.ok(
      jsonEncode({
        'message': 'Swopify API',
        'version': '1.0.0',
        'endpoints': {
          'listings': '/api/listings',
          'trades': '/api/trades',
          'messages': '/api/messages',
          'users': '/api/users'
        }
      }),
      headers: {'content-type': 'application/json'},
    );
  });

  // Catch-all route for debugging
  app.all('/<path|.*>', (shelf.Request request) {
    return shelf.Response.notFound(
      jsonEncode({
        'error': 'Route not found',
        'path': request.url.path,
        'method': request.method,
        'available_routes': [
          '/',
          '/health',
          '/api',
          '/api/listings',
          '/api/trades',
          '/api/messages',
          '/api/users'
        ]
      }),
      headers: {'content-type': 'application/json'},
    );
  });

  // Create a handler pipeline (no auth middleware)
  final handler = shelf.Pipeline()
      .addMiddleware(shelf.logRequests())
      .addMiddleware(corsMiddleware())
      .addHandler(app);

  // Get port from environment variable or use default
  // Render.com sets PORT environment variable, so we prioritize that
  final port = int.parse(Platform.environment['PORT'] ?? env['PORT'] ?? '3000');
  final ip = env['HOST'] ?? '0.0.0.0';

  // Start server
  final server = await io.serve(handler, ip, port);
  print('Server running on http://${server.address.host}:${server.port}');
  print('Environment: ${env['ENVIRONMENT'] ?? 'development'}');
  print('Available routes:');
  print('  GET  /');
  print('  GET  /health');
  print('  GET  /api');
  print('  *    /api/listings');
  print('  *    /api/trades');
  print('  *    /api/messages');
  print('  *    /api/users');

    // Handle graceful shutdown
    ProcessSignal.sigint.watch().listen((_) async {
      print('Shutting down server...');
      await DatabaseConfig.close();
      await server.close();
      exit(0);
    });
  } catch (e, stackTrace) {
    print('Failed to start server: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}