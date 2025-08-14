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

  // Add database test endpoint
  app.get('/db-test', (shelf.Request request) async {
    try {
      final result = await DatabaseConfig.connection.query('SELECT COUNT(*) as count FROM users');
      final userCount = result.first.toColumnMap()['count'] as int;

      return shelf.Response.ok(
        jsonEncode({
          'database_status': 'connected',
          'timestamp': DateTime.now().toIso8601String(),
          'total_users': userCount,
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return shelf.Response.ok(
        jsonEncode({
          'database_status': 'error',
          'timestamp': DateTime.now().toIso8601String(),
          'error': e.toString(),
        }),
        headers: {'content-type': 'application/json'},
      );
    }
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
        'available_routes': {
          'root': 'GET /',
          'health': 'GET /health',
          'api_info': 'GET /api',
          'listings': {
            'root': 'GET /api/listings',
            'test': 'GET /api/listings/test',
            'get_all': 'GET /api/listings/',
            'get_by_id': 'GET /api/listings/<id>',
            'create': 'POST /api/listings/',
            'update': 'PUT /api/listings/<id>',
            'delete': 'DELETE /api/listings/<id>',
            'by_user': 'GET /api/listings/user/<userId>'
          },
          'trades': {
            'test': 'GET /api/trades/test',
            'get_all': 'GET /api/trades/?userId=<userId>',
            'get_by_id': 'GET /api/trades/<id>',
            'create': 'POST /api/trades/',
            'update_status': 'PUT /api/trades/<id>/status',
            'cancel': 'DELETE /api/trades/<id>'
          },
          'messages': {
            'root': 'GET /api/messages',
            'test': 'GET /api/messages/test',
            'conversations': 'GET /api/messages/conversations',
            'get_messages': 'GET /api/messages/conversations/<conversationId>',
            'send_message': 'POST /api/messages/conversations/<conversationId>',
            'mark_read': 'PUT /api/messages/conversations/<conversationId>/read'
          },
          'users': {
            'root': 'GET /api/users',
            'test': 'GET /api/users/test',
            'create_profile': 'POST /api/users/profile',
            'get_user': 'GET /api/users/<id>',
            'update_user': 'PUT /api/users/<id>',
            'search': 'GET /api/users/search'
          }
        }
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