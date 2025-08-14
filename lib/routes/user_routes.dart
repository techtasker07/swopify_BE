import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../utils/response_utils.dart';
import '../utils/validation_utils.dart';
import '../config/database_config.dart';

class UserRoutes {
  final _uuid = const Uuid();

  Router get router {
    final router = Router();

    // Root route for users API
    router.get('/', (Request request) {
      return Response.ok(
        jsonEncode({
          'message': 'Users API',
          'version': '1.0.0',
          'endpoints': {
            'get_all_users': 'GET /api/users/all',
            'create_profile': 'POST /api/users/profile',
            'get_user': 'GET /api/users/<id>',
            'update_user': 'PUT /api/users/<id>',
            'search_users': 'GET /api/users/search',
            'test': 'GET /api/users/test'
          }
        }),
        headers: {'content-type': 'application/json'},
      );
    });

    // Test endpoint
    router.get('/test', (Request request) async {
      try {
        // Test database connection
        final result = await DatabaseConfig.connection.query('SELECT COUNT(*) as count FROM users');
        final userCount = result.first.toColumnMap()['count'] as int;

        return Response.ok(
          jsonEncode({
            'message': 'Users API is working',
            'timestamp': DateTime.now().toIso8601String(),
            'database_connected': true,
            'total_users': userCount,
          }),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        return Response.ok(
          jsonEncode({
            'message': 'Users API is working but database connection failed',
            'timestamp': DateTime.now().toIso8601String(),
            'database_connected': false,
            'error': e.toString(),
          }),
          headers: {'content-type': 'application/json'},
        );
      }
    });

    // Get all users (for testing/admin purposes)
    router.get('/all', _getAllUsers);

    // Create user profile (called from frontend after successful auth)
    router.post('/profile', _createUserProfile);

    // Get user by ID
    router.get('/<id>', _getUserById);

    // Update user profile
    router.put('/<id>', _updateUserProfile);

    // Search users
    router.get('/search', _searchUsers);

    return router;
  }

  /// Create user profile (called from frontend after successful auth)
  Future<Response> _createUserProfile(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      // Validate required fields
      final validationResult = ValidationUtils.validateFields(
        data,
        ['id', 'email'], // Only require Firebase UID and email
      );

      if (validationResult != null) {
        return ResponseUtils.error(validationResult);
      }

      // Check if user already exists
      final existingResult = await DatabaseConfig.connection.query(
        'SELECT id FROM users WHERE id = @id',
        substitutionValues: {'id': data['id']},
      );

      if (existingResult.isNotEmpty) {
        return ResponseUtils.error('User already exists');
      }

      // Create user profile
      final user = UserModel(
        id: data['id'] as String, // Use Firebase UID
        email: data['email'] as String,
        displayName: data['displayName'] as String? ?? 'User', // Default if not provided
        bio: data['bio'] as String? ?? '', // Default if not provided
        profileImageUrl: data['profileImageUrl'] as String?,
        phoneNumber: data['phoneNumber'] as String?,
        location: data['location'] as Map<String, dynamic>?,
        interests: (data['interests'] as List<dynamic>?)?.cast<String>() ?? [],
        tradePreferences: (data['tradePreferences'] as List<dynamic>?)?.cast<String>() ?? [],
        kycVerified: data['kycVerified'] as bool? ?? false,
        barterScore: data['barterScore'] as int? ?? 0,
        badges: (data['badges'] as List<dynamic>?)?.cast<String>() ?? [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Insert into database
      await DatabaseConfig.connection.execute(
        '''INSERT INTO users (id, email, display_name, bio, profile_image_url, phone_number,
           location, interests, trade_preferences, kyc_verified, barter_score, badges, created_at, updated_at)
           VALUES (@id, @email, @displayName, @bio, @profileImageUrl, @phoneNumber,
           @location, @interests, @tradePreferences, @kycVerified, @barterScore, @badges, @createdAt, @updatedAt)''',
        substitutionValues: {
          'id': user.id,
          'email': user.email,
          'displayName': user.displayName,
          'bio': user.bio,
          'profileImageUrl': user.profileImageUrl,
          'phoneNumber': user.phoneNumber,
          'location': user.location != null ? jsonEncode(user.location) : null,
          'interests': user.interests,
          'tradePreferences': user.tradePreferences,
          'kycVerified': user.kycVerified,
          'barterScore': user.barterScore,
          'badges': user.badges,
          'createdAt': user.createdAt,
          'updatedAt': user.updatedAt,
        },
      );

      return ResponseUtils.success({
        'message': 'User profile created successfully',
        'user': user.toJson(),
      });
    } catch (e) {
      return ResponseUtils.serverError('Error creating user profile: $e');
    }
  }

  /// Get user by ID
  Future<Response> _getUserById(Request request, String id) async {
    try {
      final result = await DatabaseConfig.connection.query(
        'SELECT * FROM users WHERE id = @id',
        substitutionValues: {'id': id},
      );

      if (result.isEmpty) {
        return ResponseUtils.notFound('User not found');
      }

      final user = UserModel.fromDatabaseRow(result.first.toColumnMap());

      // Return public profile information only
      return ResponseUtils.success({
        'user': {
          'id': user.id,
          'displayName': user.displayName,
          'bio': user.bio,
          'profileImageUrl': user.profileImageUrl,
          'barterScore': user.barterScore,
          'badges': user.badges,
          'kycVerified': user.kycVerified,
          'createdAt': user.createdAt.toIso8601String(),
        },
      });
    } catch (e) {
      return ResponseUtils.serverError('Error fetching user: $e');
    }
  }

  /// Update user profile by ID
  Future<Response> _updateUserProfile(Request request, String userId) async {
    try {
      // Parse request body
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      // Check if user exists
      final existingResult = await DatabaseConfig.connection.query(
        'SELECT id FROM users WHERE id = @userId',
        substitutionValues: {'userId': userId},
      );

      if (existingResult.isEmpty) {
        return ResponseUtils.notFound('User not found');
      }

      // Build update query
      final updateFields = <String>[];
      final substitutionValues = <String, dynamic>{'userId': userId};

      if (data.containsKey('displayName')) {
        updateFields.add('display_name = @displayName');
        substitutionValues['displayName'] = data['displayName'];
      }

      if (data.containsKey('bio')) {
        updateFields.add('bio = @bio');
        substitutionValues['bio'] = data['bio'];
      }

      if (data.containsKey('phoneNumber')) {
        updateFields.add('phone_number = @phoneNumber');
        substitutionValues['phoneNumber'] = data['phoneNumber'];
      }

      if (data.containsKey('profileImageUrl')) {
        updateFields.add('profile_image_url = @profileImageUrl');
        substitutionValues['profileImageUrl'] = data['profileImageUrl'];
      }

      if (data.containsKey('interests')) {
        updateFields.add('interests = @interests');
        substitutionValues['interests'] = (data['interests'] as List<dynamic>?)?.cast<String>() ?? [];
      }

      if (data.containsKey('tradePreferences')) {
        updateFields.add('trade_preferences = @tradePreferences');
        substitutionValues['tradePreferences'] = (data['tradePreferences'] as List<dynamic>?)?.cast<String>() ?? [];
      }

      if (data.containsKey('location')) {
        updateFields.add('location = @location');
        substitutionValues['location'] = jsonEncode(data['location']);
      }

      if (updateFields.isEmpty) {
        return ResponseUtils.error('No fields to update');
      }

      updateFields.add('updated_at = @updatedAt');
      substitutionValues['updatedAt'] = DateTime.now();

      await DatabaseConfig.connection.execute(
        'UPDATE users SET ${updateFields.join(', ')} WHERE id = @userId',
        substitutionValues: substitutionValues,
      );

      // Get updated user
      final updatedResult = await DatabaseConfig.connection.query(
        'SELECT * FROM users WHERE id = @userId',
        substitutionValues: {'userId': userId},
      );

      final user = UserModel.fromDatabaseRow(updatedResult.first.toColumnMap());

      return ResponseUtils.success({
        'message': 'Profile updated successfully',
        'user': user.toJson(),
      });
    } catch (e) {
      return ResponseUtils.serverError('Error updating profile: $e');
    }
  }

  /// Search users
  Future<Response> _searchUsers(Request request) async {
    try {
      final params = request.url.queryParameters;
      final query = params['q'];
      final page = int.tryParse(params['page'] ?? '1') ?? 1;
      final limit = int.tryParse(params['limit'] ?? '20') ?? 20;
      final offset = (page - 1) * limit;

      if (query == null || query.isEmpty) {
        return ResponseUtils.error('Search query is required');
      }

      // Search users by display name
      final searchQuery = '''
        SELECT id, display_name, bio, profile_image_url, barter_score, badges, kyc_verified, created_at
        FROM users
        WHERE display_name ILIKE @query
        ORDER BY barter_score DESC, created_at DESC
        LIMIT @limit OFFSET @offset
      ''';

      final result = await DatabaseConfig.connection.query(
        searchQuery,
        substitutionValues: {
          'query': '%$query%',
          'limit': limit,
          'offset': offset,
        },
      );

      // Get total count
      final countResult = await DatabaseConfig.connection.query(
        'SELECT COUNT(*) as count FROM users WHERE display_name ILIKE @query',
        substitutionValues: {'query': '%$query%'},
      );
      final total = countResult.first.toColumnMap()['count'] as int;

      final users = result.map((row) {
        final data = row.toColumnMap();
        return {
          'id': data['id'],
          'displayName': data['display_name'],
          'bio': data['bio'],
          'profileImageUrl': data['profile_image_url'],
          'barterScore': data['barter_score'],
          'badges': data['badges'],
          'kycVerified': data['kyc_verified'],
          'createdAt': (data['created_at'] as DateTime).toIso8601String(),
        };
      }).toList();

      return ResponseUtils.success({
        'data': users,
        'pagination': {
          'page': page,
          'limit': limit,
          'total': total,
          'totalPages': (total / limit).ceil(),
        },
      });
    } catch (e) {
      return ResponseUtils.serverError('Error searching users: $e');
    }
  }

  /// Get all users (for testing/admin purposes)
  Future<Response> _getAllUsers(Request request) async {
    try {
      final params = request.url.queryParameters;
      final page = int.tryParse(params['page'] ?? '1') ?? 1;
      final limit = int.tryParse(params['limit'] ?? '20') ?? 20;
      final offset = (page - 1) * limit;

      // Get total count
      final countResult = await DatabaseConfig.connection.query(
        'SELECT COUNT(*) as count FROM users',
      );
      final total = countResult.first.toColumnMap()['count'] as int;

      // Get users with pagination
      final result = await DatabaseConfig.connection.query(
        '''SELECT id, email, display_name, bio, profile_image_url, barter_score,
           badges, kyc_verified, created_at
           FROM users
           ORDER BY created_at DESC
           LIMIT @limit OFFSET @offset''',
        substitutionValues: {
          'limit': limit,
          'offset': offset,
        },
      );

      final users = result.map((row) {
        final data = row.toColumnMap();
        return {
          'id': data['id'],
          'email': data['email'],
          'displayName': data['display_name'],
          'bio': data['bio'],
          'profileImageUrl': data['profile_image_url'],
          'barterScore': data['barter_score'],
          'badges': data['badges'],
          'kycVerified': data['kyc_verified'],
          'createdAt': (data['created_at'] as DateTime).toIso8601String(),
        };
      }).toList();

      return ResponseUtils.success({
        'data': users,
        'pagination': {
          'page': page,
          'limit': limit,
          'total': total,
          'totalPages': (total / limit).ceil(),
        },
      });
    } catch (e) {
      return ResponseUtils.serverError('Error fetching users: $e');
    }
  }
}
