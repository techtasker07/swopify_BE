import 'dart:io';
import 'package:postgres/postgres.dart';
import 'package:dotenv/dotenv.dart';
import 'package:logging/logging.dart';

final _logger = Logger('DatabaseConfig');

class DatabaseConfig {
  static PostgreSQLConnection? _connection;

  /// Initialize database connection
  static Future<void> initialize() async {
    try {
      final env = DotEnv(includePlatformEnvironment: true)..load();

      // Ensure we have all required database credentials
      // Prioritize Platform.environment for deployment platforms like Render
      final dbHost = Platform.environment['DB_HOST'] ?? env['DB_HOST'];
      final dbPort = Platform.environment['DB_PORT'] ?? env['DB_PORT'];
      final dbName = Platform.environment['DB_NAME'] ?? env['DB_NAME'];
      final dbUser = Platform.environment['DB_USER'] ?? env['DB_USER'];
      final dbPassword = Platform.environment['DB_PASSWORD'] ?? env['DB_PASSWORD'];

      if (dbHost == null || dbPort == null || dbName == null || dbUser == null || dbPassword == null) {
        throw Exception('Missing required database environment variables. Please check your .env file.');
      }

      _connection = PostgreSQLConnection(
        dbHost,
        int.parse(dbPort),
        dbName,
        username: dbUser,
        password: dbPassword,
        useSSL: true,
        timeoutInSeconds: 30,
        queryTimeoutInSeconds: 30,
      );

      _logger.info('Connecting to database: $dbHost:$dbPort/$dbName as $dbUser');

      await _connection!.open();

      _logger.info('Database connected successfully');

      // Create tables if they don't exist
      await _createTables();

    } catch (e) {
      _logger.severe('Failed to connect to database: $e');
      rethrow;
    }
  }

  /// Get database connection
  static PostgreSQLConnection get connection {
    if (_connection == null) {
      throw Exception('Database not initialized. Call DatabaseConfig.initialize() first.');
    }
    return _connection!;
  }

  /// Close database connection
  static Future<void> close() async {
    if (_connection != null) {
      await _connection!.close();
      _connection = null;
      _logger.info('Database connection closed');
    }
  }
  
  /// Create database tables
  static Future<void> _createTables() async {
    try {
      // Users table
      await _connection!.execute('''
        CREATE TABLE IF NOT EXISTS users (
          id VARCHAR(255) PRIMARY KEY,
          email VARCHAR(255) UNIQUE NOT NULL,
          display_name VARCHAR(255),
          bio TEXT,
          profile_image_url TEXT,
          phone_number VARCHAR(20),
          location JSONB,
          interests TEXT[],
          trade_preferences TEXT[],
          kyc_verified BOOLEAN DEFAULT FALSE,
          barter_score INTEGER DEFAULT 0,
          badges TEXT[],
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      
      // Listings table
      await _connection!.execute('''
        CREATE TABLE IF NOT EXISTS listings (
          id VARCHAR(255) PRIMARY KEY,
          user_id VARCHAR(255) REFERENCES users(id) ON DELETE CASCADE,
          title VARCHAR(255) NOT NULL,
          description TEXT,
          category VARCHAR(100) NOT NULL,
          condition VARCHAR(50),
          estimated_value DECIMAL(10,2),
          images TEXT[],
          trade_preferences TEXT[],
          location JSONB,
          status VARCHAR(50) DEFAULT 'active',
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      
      // Trades table
      await _connection!.execute('''
        CREATE TABLE IF NOT EXISTS trades (
          id VARCHAR(255) PRIMARY KEY,
          initiator_id VARCHAR(255) REFERENCES users(id) ON DELETE CASCADE,
          receiver_id VARCHAR(255) REFERENCES users(id) ON DELETE CASCADE,
          initiator_listing_id VARCHAR(255) REFERENCES listings(id) ON DELETE CASCADE,
          receiver_listing_id VARCHAR(255) REFERENCES listings(id) ON DELETE CASCADE,
          status VARCHAR(50) DEFAULT 'pending',
          trade_coins INTEGER DEFAULT 0,
          message TEXT,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      
      // Messages table
      await _connection!.execute('''
        CREATE TABLE IF NOT EXISTS messages (
          id VARCHAR(255) PRIMARY KEY,
          conversation_id VARCHAR(255) NOT NULL,
          sender_id VARCHAR(255) REFERENCES users(id) ON DELETE CASCADE,
          receiver_id VARCHAR(255) REFERENCES users(id) ON DELETE CASCADE,
          content TEXT,
          message_type VARCHAR(50) DEFAULT 'text',
          media_url TEXT,
          trade_id VARCHAR(255) REFERENCES trades(id) ON DELETE SET NULL,
          read_at TIMESTAMP,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      
      // Reviews table
      await _connection!.execute('''
        CREATE TABLE IF NOT EXISTS reviews (
          id VARCHAR(255) PRIMARY KEY,
          reviewer_id VARCHAR(255) REFERENCES users(id) ON DELETE CASCADE,
          reviewee_id VARCHAR(255) REFERENCES users(id) ON DELETE CASCADE,
          trade_id VARCHAR(255) REFERENCES trades(id) ON DELETE CASCADE,
          rating INTEGER CHECK (rating >= 1 AND rating <= 5),
          comment TEXT,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      
      // Trade groups table
      await _connection!.execute('''
        CREATE TABLE IF NOT EXISTS trade_groups (
          id VARCHAR(255) PRIMARY KEY,
          name VARCHAR(255) NOT NULL,
          description TEXT,
          category VARCHAR(100),
          creator_id VARCHAR(255) REFERENCES users(id) ON DELETE CASCADE,
          member_count INTEGER DEFAULT 1,
          is_public BOOLEAN DEFAULT TRUE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      
      // Group members table
      await _connection!.execute('''
        CREATE TABLE IF NOT EXISTS group_members (
          id VARCHAR(255) PRIMARY KEY,
          group_id VARCHAR(255) REFERENCES trade_groups(id) ON DELETE CASCADE,
          user_id VARCHAR(255) REFERENCES users(id) ON DELETE CASCADE,
          role VARCHAR(50) DEFAULT 'member',
          joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          UNIQUE(group_id, user_id)
        )
      ''');
      
      // Safe exchange zones table
      await _connection!.execute('''
        CREATE TABLE IF NOT EXISTS safe_exchange_zones (
          id VARCHAR(255) PRIMARY KEY,
          name VARCHAR(255) NOT NULL,
          address TEXT NOT NULL,
          location JSONB NOT NULL,
          business_type VARCHAR(100),
          verified BOOLEAN DEFAULT FALSE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      
      // Create indexes for better performance
      await _connection!.execute('CREATE INDEX IF NOT EXISTS idx_listings_user_id ON listings(user_id)');
      await _connection!.execute('CREATE INDEX IF NOT EXISTS idx_listings_category ON listings(category)');
      await _connection!.execute('CREATE INDEX IF NOT EXISTS idx_listings_status ON listings(status)');
      await _connection!.execute('CREATE INDEX IF NOT EXISTS idx_trades_initiator_id ON trades(initiator_id)');
      await _connection!.execute('CREATE INDEX IF NOT EXISTS idx_trades_receiver_id ON trades(receiver_id)');
      await _connection!.execute('CREATE INDEX IF NOT EXISTS idx_trades_status ON trades(status)');
      await _connection!.execute('CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON messages(conversation_id)');
      await _connection!.execute('CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON messages(sender_id)');
      await _connection!.execute('CREATE INDEX IF NOT EXISTS idx_messages_receiver_id ON messages(receiver_id)');
      
      _logger.info('Database tables created successfully');
    } catch (e) {
      _logger.severe('Failed to create database tables: $e');
      rethrow;
    }
  }
}
