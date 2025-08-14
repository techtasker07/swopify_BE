import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';
import '../models/listing_model.dart';
import '../utils/response_utils.dart';
import '../utils/validation_utils.dart';
import '../config/database_config.dart';

class ListingRoutes {
  final _uuid = const Uuid();

  Router get router {
    final router = Router();

    // Test endpoint
    router.get('/test', (Request request) {
      return Response.ok(
        jsonEncode({
          'message': 'Listings API is working',
          'timestamp': DateTime.now().toIso8601String(),
        }),
        headers: {'content-type': 'application/json'},
      );
    });

    // Get all listings with pagination and filters
    router.get('/', _getListings);

    // Get a specific listing by ID
    router.get('/<id>', _getListingById);

    // Create a new listing
    router.post('/', _createListing);

    // Update a listing
    router.put('/<id>', _updateListing);

    // Delete a listing
    router.delete('/<id>', _deleteListing);

    // Get listings by user ID
    router.get('/user/<userId>', _getListingsByUser);

    return router;
  }

  /// Get all listings with pagination and filters
  Future<Response> _getListings(Request request) async {
    try {
      final params = request.url.queryParameters;
      final page = int.tryParse(params['page'] ?? '1') ?? 1;
      final limit = int.tryParse(params['limit'] ?? '20') ?? 20;
      final category = params['category'];
      final offset = (page - 1) * limit;
      
      // Build query
      var whereClause = 'WHERE status = \'active\'';
      final substitutionValues = <String, dynamic>{};

      if (category != null && category.isNotEmpty) {
        whereClause += ' AND category = @category';
        substitutionValues['category'] = category;
      }

      // Get total count
      final countResult = await DatabaseConfig.connection.query(
        'SELECT COUNT(*) as count FROM listings $whereClause',
        substitutionValues: substitutionValues,
      );
      final total = countResult.first.toColumnMap()['count'] as int;

      // Get listings with pagination
      final query = '''
        SELECT l.*, u.display_name as user_name, u.profile_image_url as user_profile_picture
        FROM listings l
        LEFT JOIN users u ON l.user_id = u.id
        $whereClause
        ORDER BY l.created_at DESC
        LIMIT @limit OFFSET @offset
      ''';

      substitutionValues['limit'] = limit;
      substitutionValues['offset'] = offset;

      final result = await DatabaseConfig.connection.query(query, substitutionValues: substitutionValues);
      
      final listings = result.map((row) {
        final data = row.toColumnMap();
        return ListingModel.fromDatabaseRow(data).copyWith(
          userName: data['user_name'] as String?,
          userProfilePicture: data['user_profile_picture'] as String?,
        );
      }).toList();
      
      return ResponseUtils.success({
        'data': listings.map((listing) => listing.toJson()).toList(),
        'pagination': {
          'page': page,
          'limit': limit,
          'total': total,
          'totalPages': (total / limit).ceil(),
        },
      });
    } catch (e) {
      return ResponseUtils.serverError('Error fetching listings: $e');
    }
  }

  /// Get a specific listing by ID
  Future<Response> _getListingById(Request request, String id) async {
    try {
      final query = '''
        SELECT l.*, u.display_name as user_name, u.profile_image_url as user_profile_picture
        FROM listings l
        LEFT JOIN users u ON l.user_id = u.id
        WHERE l.id = @id
      ''';

      final result = await DatabaseConfig.connection.query(query, substitutionValues: {'id': id});
      
      if (result.isEmpty) {
        return ResponseUtils.notFound('Listing not found');
      }
      
      final data = result.first.toColumnMap();
      final listing = ListingModel.fromDatabaseRow(data).copyWith(
        userName: data['user_name'] as String?,
        userProfilePicture: data['user_profile_picture'] as String?,
      );
      
      return ResponseUtils.success({
        'listing': listing.toJson(),
      });
    } catch (e) {
      return ResponseUtils.serverError('Error fetching listing: $e');
    }
  }

  /// Create a new listing
  Future<Response> _createListing(Request request) async {
    try {
      // Parse request body
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      // Validate required fields (including userId from frontend)
      final validationResult = ValidationUtils.validateFields(
        data,
        ['userId', 'title', 'description', 'category'],
      );

      if (validationResult != null) {
        return ResponseUtils.error(validationResult);
      }

      final userId = data['userId'] as String;

      // Create listing
      final listingId = _uuid.v4();
      final listing = ListingModel(
        id: listingId,
        userId: userId,
        title: data['title'] as String,
        description: data['description'] as String,
        category: data['category'] as String,
        condition: data['condition'] as String?,
        estimatedValue: (data['estimatedValue'] as num?)?.toDouble(),
        images: (data['images'] as List<dynamic>?)?.cast<String>() ?? [],
        tradePreferences: (data['tradePreferences'] as List<dynamic>?)?.cast<String>() ?? [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Insert into database
      await DatabaseConfig.connection.execute(
        '''INSERT INTO listings (id, user_id, title, description, category, condition,
           estimated_value, images, trade_preferences, status, created_at, updated_at)
           VALUES (@id, @userId, @title, @description, @category, @condition,
           @estimatedValue, @images, @tradePreferences, @status, @createdAt, @updatedAt)''',
        substitutionValues: {
          'id': listing.id,
          'userId': listing.userId,
          'title': listing.title,
          'description': listing.description,
          'category': listing.category,
          'condition': listing.condition,
          'estimatedValue': listing.estimatedValue,
          'images': listing.images,
          'tradePreferences': listing.tradePreferences,
          'status': listing.status,
          'createdAt': listing.createdAt,
          'updatedAt': listing.updatedAt,
        },
      );

      return ResponseUtils.success({
        'message': 'Listing created successfully',
        'listing': listing.toJson(),
      });
    } catch (e) {
      return ResponseUtils.serverError('Error creating listing: $e');
    }
  }

  /// Update a listing
  Future<Response> _updateListing(Request request, String id) async {
    try {
      // Parse request body to get userId
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final userId = data['userId'] as String?;
      if (userId == null) {
        return ResponseUtils.error('userId is required in request body');
      }

      // Check if listing exists and belongs to user
      final existingResult = await DatabaseConfig.connection.query(
        'SELECT user_id FROM listings WHERE id = @id',
        substitutionValues: {'id': id},
      );

      if (existingResult.isEmpty) {
        return ResponseUtils.notFound('Listing not found');
      }

      final listingUserId = existingResult.first.toColumnMap()['user_id'] as String;
      if (listingUserId != userId) {
        return ResponseUtils.forbidden('You can only update your own listings');
      }

      // Build update query
      final updateFields = <String>[];
      final substitutionValues = <String, dynamic>{'id': id};

      if (data.containsKey('title')) {
        updateFields.add('title = @title');
        substitutionValues['title'] = data['title'];
      }

      if (data.containsKey('description')) {
        updateFields.add('description = @description');
        substitutionValues['description'] = data['description'];
      }

      if (data.containsKey('category')) {
        updateFields.add('category = @category');
        substitutionValues['category'] = data['category'];
      }

      if (data.containsKey('condition')) {
        updateFields.add('condition = @condition');
        substitutionValues['condition'] = data['condition'];
      }

      if (data.containsKey('estimatedValue')) {
        updateFields.add('estimated_value = @estimatedValue');
        substitutionValues['estimatedValue'] = (data['estimatedValue'] as num?)?.toDouble();
      }

      if (data.containsKey('images')) {
        updateFields.add('images = @images');
        substitutionValues['images'] = (data['images'] as List<dynamic>?)?.cast<String>() ?? [];
      }

      if (data.containsKey('tradePreferences')) {
        updateFields.add('trade_preferences = @tradePreferences');
        substitutionValues['tradePreferences'] = (data['tradePreferences'] as List<dynamic>?)?.cast<String>() ?? [];
      }

      if (updateFields.isEmpty) {
        return ResponseUtils.error('No fields to update');
      }

      updateFields.add('updated_at = @updatedAt');
      substitutionValues['updatedAt'] = DateTime.now();

      await DatabaseConfig.connection.execute(
        'UPDATE listings SET ${updateFields.join(', ')} WHERE id = @id',
        substitutionValues: substitutionValues,
      );

      // Get updated listing
      final updatedResult = await DatabaseConfig.connection.query(
        'SELECT * FROM listings WHERE id = @id',
        substitutionValues: {'id': id},
      );

      final listing = ListingModel.fromDatabaseRow(updatedResult.first.toColumnMap());

      return ResponseUtils.success({
        'message': 'Listing updated successfully',
        'listing': listing.toJson(),
      });
    } catch (e) {
      return ResponseUtils.serverError('Error updating listing: $e');
    }
  }

  /// Delete a listing
  Future<Response> _deleteListing(Request request, String id) async {
    try {
      // Parse request body to get userId
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final userId = data['userId'] as String?;
      if (userId == null) {
        return ResponseUtils.error('userId is required in request body');
      }

      // Check if listing exists and belongs to user
      final existingResult = await DatabaseConfig.connection.query(
        'SELECT user_id FROM listings WHERE id = @id',
        substitutionValues: {'id': id},
      );

      if (existingResult.isEmpty) {
        return ResponseUtils.notFound('Listing not found');
      }

      final listingUserId = existingResult.first.toColumnMap()['user_id'] as String;
      if (listingUserId != userId) {
        return ResponseUtils.forbidden('You can only delete your own listings');
      }

      // Soft delete by updating status
      await DatabaseConfig.connection.execute(
        'UPDATE listings SET status = \'deleted\', updated_at = @updatedAt WHERE id = @id',
        substitutionValues: {
          'updatedAt': DateTime.now(),
          'id': id,
        },
      );

      return ResponseUtils.success({
        'message': 'Listing deleted successfully',
      });
    } catch (e) {
      return ResponseUtils.serverError('Error deleting listing: $e');
    }
  }

  /// Get listings by user ID
  Future<Response> _getListingsByUser(Request request, String userId) async {
    try {
      final params = request.url.queryParameters;
      final page = int.tryParse(params['page'] ?? '1') ?? 1;
      final limit = int.tryParse(params['limit'] ?? '20') ?? 20;
      final offset = (page - 1) * limit;
      
      // Get total count
      final countResult = await DatabaseConfig.connection.query(
        'SELECT COUNT(*) as count FROM listings WHERE user_id = @userId AND status = \'active\'',
        substitutionValues: {'userId': userId},
      );
      final total = countResult.first.toColumnMap()['count'] as int;

      // Get listings
      final query = '''
        SELECT l.*, u.display_name as user_name, u.profile_image_url as user_profile_picture
        FROM listings l
        LEFT JOIN users u ON l.user_id = u.id
        WHERE l.user_id = @userId AND l.status = 'active'
        ORDER BY l.created_at DESC
        LIMIT @limit OFFSET @offset
      ''';

      final result = await DatabaseConfig.connection.query(query, substitutionValues: {
        'userId': userId,
        'limit': limit,
        'offset': offset,
      });
      
      final listings = result.map((row) {
        final data = row.toColumnMap();
        return ListingModel.fromDatabaseRow(data).copyWith(
          userName: data['user_name'] as String?,
          userProfilePicture: data['user_profile_picture'] as String?,
        );
      }).toList();
      
      return ResponseUtils.success({
        'data': listings.map((listing) => listing.toJson()).toList(),
        'pagination': {
          'page': page,
          'limit': limit,
          'total': total,
          'totalPages': (total / limit).ceil(),
        },
      });
    } catch (e) {
      return ResponseUtils.serverError('Error fetching user listings: $e');
    }
  }
}
