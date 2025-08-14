import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';
import '../models/trade_model.dart';
import '../utils/response_utils.dart';
import '../utils/validation_utils.dart';
import '../config/database_config.dart';

class TradeRoutes {
  final _uuid = const Uuid();

  Router get router {
    final router = Router();

    // Test endpoint
    router.get('/test', (Request request) {
      return Response.ok(
        jsonEncode({
          'message': 'Trades API is working',
          'timestamp': DateTime.now().toIso8601String(),
          'endpoints': {
            'get_trades': 'GET /api/trades/?userId=<userId>',
            'get_trade': 'GET /api/trades/<id>',
            'create_trade': 'POST /api/trades/',
            'update_status': 'PUT /api/trades/<id>/status',
            'cancel_trade': 'DELETE /api/trades/<id>'
          }
        }),
        headers: {'content-type': 'application/json'},
      );
    });

    // Get all trades for current user
    router.get('/', _getTrades);

    // Get a specific trade by ID
    router.get('/<id>', _getTradeById);

    // Create a new trade proposal
    router.post('/', _createTrade);

    // Update trade status (accept, reject, complete)
    router.put('/<id>/status', _updateTradeStatus);

    // Cancel a trade
    router.delete('/<id>', _cancelTrade);

    return router;
  }

  /// Get all trades for a user (userId passed as query parameter)
  Future<Response> _getTrades(Request request) async {
    try {
      final params = request.url.queryParameters;
      final userId = params['userId'];
      if (userId == null) {
        return ResponseUtils.error('userId query parameter is required');
      }

      final page = int.tryParse(params['page'] ?? '1') ?? 1;
      final limit = int.tryParse(params['limit'] ?? '20') ?? 20;
      final status = params['status'];
      final offset = (page - 1) * limit;

      // Build query with substitution values
      var whereClause = 'WHERE (t.initiator_id = @userId OR t.receiver_id = @userId)';
      final substitutionValues = <String, dynamic>{'userId': userId};

      if (status != null && status.isNotEmpty) {
        whereClause += ' AND t.status = @status';
        substitutionValues['status'] = status;
      }

      // Get total count
      final countResult = await DatabaseConfig.connection.query(
        'SELECT COUNT(*) as count FROM trades t $whereClause',
        substitutionValues: substitutionValues,
      );
      final total = countResult.first.toColumnMap()['count'] as int;
      
      // Get trades with user and listing information
      final query = '''
        SELECT t.*,
               u1.display_name as initiator_name, u1.profile_image_url as initiator_profile_picture,
               u2.display_name as receiver_name, u2.profile_image_url as receiver_profile_picture,
               l1.title as initiator_listing_title, l1.images as initiator_listing_images,
               l2.title as receiver_listing_title, l2.images as receiver_listing_images
        FROM trades t
        LEFT JOIN users u1 ON t.initiator_id = u1.id
        LEFT JOIN users u2 ON t.receiver_id = u2.id
        LEFT JOIN listings l1 ON t.initiator_listing_id = l1.id
        LEFT JOIN listings l2 ON t.receiver_listing_id = l2.id
        $whereClause
        ORDER BY t.created_at DESC
        LIMIT @limit OFFSET @offset
      ''';

      substitutionValues['limit'] = limit;
      substitutionValues['offset'] = offset;

      final result = await DatabaseConfig.connection.query(
        query,
        substitutionValues: substitutionValues,
      );

      final trades = result.map((row) {
        final data = row.toColumnMap();
        return TradeModel.fromDatabaseRow(data).copyWith(
          initiatorName: data['initiator_name'] as String?,
          initiatorProfilePicture: data['initiator_profile_picture'] as String?,
          receiverName: data['receiver_name'] as String?,
          receiverProfilePicture: data['receiver_profile_picture'] as String?,
        );
      }).toList();
      
      return ResponseUtils.success({
        'data': trades.map((trade) => trade.toJson()).toList(),
        'pagination': {
          'page': page,
          'limit': limit,
          'total': total,
          'totalPages': (total / limit).ceil(),
        },
      });
    } catch (e) {
      return ResponseUtils.serverError('Error fetching trades: $e');
    }
  }

  /// Get a specific trade by ID
  Future<Response> _getTradeById(Request request, String id) async {
    try {
      final userId = request.context['userId'] as String?;
      if (userId == null) {
        return ResponseUtils.unauthorized('User not authenticated');
      }

      final query = '''
        SELECT t.*,
               u1.display_name as initiator_name, u1.profile_image_url as initiator_profile_picture,
               u2.display_name as receiver_name, u2.profile_image_url as receiver_profile_picture,
               l1.title as initiator_listing_title, l1.images as initiator_listing_images,
               l2.title as receiver_listing_title, l2.images as receiver_listing_images
        FROM trades t
        LEFT JOIN users u1 ON t.initiator_id = u1.id
        LEFT JOIN users u2 ON t.receiver_id = u2.id
        LEFT JOIN listings l1 ON t.initiator_listing_id = l1.id
        LEFT JOIN listings l2 ON t.receiver_listing_id = l2.id
        WHERE t.id = @id AND (t.initiator_id = @userId OR t.receiver_id = @userId)
      ''';

      final result = await DatabaseConfig.connection.query(
        query,
        substitutionValues: {'id': id, 'userId': userId},
      );

      if (result.isEmpty) {
        return ResponseUtils.notFound('Trade not found');
      }

      final data = result.first.toColumnMap();
      final trade = TradeModel.fromDatabaseRow(data).copyWith(
        initiatorName: data['initiator_name'] as String?,
        initiatorProfilePicture: data['initiator_profile_picture'] as String?,
        receiverName: data['receiver_name'] as String?,
        receiverProfilePicture: data['receiver_profile_picture'] as String?,
      );
      
      return ResponseUtils.success({
        'trade': trade.toJson(),
      });
    } catch (e) {
      return ResponseUtils.serverError('Error fetching trade: $e');
    }
  }

  /// Create a new trade proposal
  Future<Response> _createTrade(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      if (userId == null) {
        return ResponseUtils.unauthorized('User not authenticated');
      }

      // Parse request body
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      // Validate required fields
      final validationResult = ValidationUtils.validateFields(
        data,
        ['receiverId', 'initiatorListingId', 'receiverListingId'],
      );

      if (validationResult != null) {
        return ResponseUtils.error(validationResult);
      }

      final receiverId = data['receiverId'] as String;
      final initiatorListingId = data['initiatorListingId'] as String;
      final receiverListingId = data['receiverListingId'] as String;

      // Validate that user owns the initiator listing
      final initiatorListingResult = await DatabaseConfig.connection.query(
        'SELECT user_id FROM listings WHERE id = @id',
        substitutionValues: {'id': initiatorListingId},
      );

      if (initiatorListingResult.isEmpty) {
        return ResponseUtils.notFound('Initiator listing not found');
      }

      final initiatorListingUserId = initiatorListingResult.first.toColumnMap()['user_id'] as String;
      if (initiatorListingUserId != userId) {
        return ResponseUtils.forbidden('You can only trade your own listings');
      }

      // Validate that receiver listing exists and belongs to receiver
      final receiverListingResult = await DatabaseConfig.connection.query(
        'SELECT user_id FROM listings WHERE id = @id',
        substitutionValues: {'id': receiverListingId},
      );

      if (receiverListingResult.isEmpty) {
        return ResponseUtils.notFound('Receiver listing not found');
      }

      final receiverListingUserId = receiverListingResult.first.toColumnMap()['user_id'] as String;
      if (receiverListingUserId != receiverId) {
        return ResponseUtils.error('Receiver listing does not belong to specified receiver');
      }

      // Create trade
      final tradeId = _uuid.v4();
      final trade = TradeModel(
        id: tradeId,
        initiatorId: userId,
        receiverId: receiverId,
        initiatorListingId: initiatorListingId,
        receiverListingId: receiverListingId,
        message: data['message'] as String?,
        tradeCoins: (data['tradeCoins'] as int?) ?? 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Insert into database
      await DatabaseConfig.connection.query(
        '''INSERT INTO trades (id, initiator_id, receiver_id, initiator_listing_id,
           receiver_listing_id, status, trade_coins, message, created_at, updated_at)
           VALUES (@id, @initiatorId, @receiverId, @initiatorListingId, @receiverListingId, @status, @tradeCoins, @message, @createdAt, @updatedAt)''',
        substitutionValues: {
          'id': trade.id,
          'initiatorId': trade.initiatorId,
          'receiverId': trade.receiverId,
          'initiatorListingId': trade.initiatorListingId,
          'receiverListingId': trade.receiverListingId,
          'status': trade.status,
          'tradeCoins': trade.tradeCoins,
          'message': trade.message,
          'createdAt': trade.createdAt,
          'updatedAt': trade.updatedAt,
        },
      );

      return ResponseUtils.success({
        'message': 'Trade proposal created successfully',
        'trade': trade.toJson(),
      });
    } catch (e) {
      return ResponseUtils.serverError('Error creating trade: $e');
    }
  }

  /// Update trade status
  Future<Response> _updateTradeStatus(Request request, String id) async {
    try {
      final userId = request.context['userId'] as String?;
      if (userId == null) {
        return ResponseUtils.unauthorized('User not authenticated');
      }

      // Parse request body
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final newStatus = data['status'] as String?;
      if (newStatus == null) {
        return ResponseUtils.error('Status is required');
      }

      // Validate status
      final validStatuses = ['accepted', 'rejected', 'completed'];
      if (!validStatuses.contains(newStatus)) {
        return ResponseUtils.error('Invalid status. Must be one of: ${validStatuses.join(', ')}');
      }

      // Check if trade exists and user is involved
      final existingResult = await DatabaseConfig.connection.query(
        'SELECT initiator_id, receiver_id, status FROM trades WHERE id = @id',
        substitutionValues: {'id': id},
      );

      if (existingResult.isEmpty) {
        return ResponseUtils.notFound('Trade not found');
      }

      final tradeData = existingResult.first.toColumnMap();
      final initiatorId = tradeData['initiator_id'] as String;
      final receiverId = tradeData['receiver_id'] as String;
      final currentStatus = tradeData['status'] as String;

      if (userId != initiatorId && userId != receiverId) {
        return ResponseUtils.forbidden('You are not involved in this trade');
      }

      // Validate status transitions
      if (currentStatus == 'completed' || currentStatus == 'rejected') {
        return ResponseUtils.error('Cannot update status of a completed or rejected trade');
      }

      // Only receiver can accept/reject, both can mark as completed
      if ((newStatus == 'accepted' || newStatus == 'rejected') && userId != receiverId) {
        return ResponseUtils.forbidden('Only the receiver can accept or reject a trade');
      }

      // Update trade status
      await DatabaseConfig.connection.query(
        'UPDATE trades SET status = @status, updated_at = @updatedAt WHERE id = @id',
        substitutionValues: {
          'status': newStatus,
          'updatedAt': DateTime.now(),
          'id': id,
        },
      );

      // Get updated trade
      final updatedResult = await DatabaseConfig.connection.query(
        'SELECT * FROM trades WHERE id = @id',
        substitutionValues: {'id': id},
      );

      final trade = TradeModel.fromDatabaseRow(updatedResult.first.toColumnMap());

      return ResponseUtils.success({
        'message': 'Trade status updated successfully',
        'trade': trade.toJson(),
      });
    } catch (e) {
      return ResponseUtils.serverError('Error updating trade status: $e');
    }
  }

  /// Cancel a trade
  Future<Response> _cancelTrade(Request request, String id) async {
    try {
      final userId = request.context['userId'] as String?;
      if (userId == null) {
        return ResponseUtils.unauthorized('User not authenticated');
      }

      // Check if trade exists and user is the initiator
      final existingResult = await DatabaseConfig.connection.query(
        'SELECT initiator_id, status FROM trades WHERE id = @id',
        substitutionValues: {'id': id},
      );

      if (existingResult.isEmpty) {
        return ResponseUtils.notFound('Trade not found');
      }

      final tradeData = existingResult.first.toColumnMap();
      final initiatorId = tradeData['initiator_id'] as String;
      final currentStatus = tradeData['status'] as String;

      if (userId != initiatorId) {
        return ResponseUtils.forbidden('Only the trade initiator can cancel a trade');
      }

      if (currentStatus != 'pending') {
        return ResponseUtils.error('Can only cancel pending trades');
      }

      // Update trade status to cancelled
      await DatabaseConfig.connection.query(
        'UPDATE trades SET status = \'cancelled\', updated_at = @updatedAt WHERE id = @id',
        substitutionValues: {
          'updatedAt': DateTime.now(),
          'id': id,
        },
      );

      return ResponseUtils.success({
        'message': 'Trade cancelled successfully',
      });
    } catch (e) {
      return ResponseUtils.serverError('Error cancelling trade: $e');
    }
  }
}
