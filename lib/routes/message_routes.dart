import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';
import '../models/message_model.dart';
import '../utils/response_utils.dart';
import '../utils/validation_utils.dart';
import '../config/database_config.dart';

class MessageRoutes {
  final _uuid = const Uuid();

  Router get router {
    final router = Router();

    // Get conversations for current user
    router.get('/conversations', _getConversations);

    // Get messages in a conversation
    router.get('/conversations/<conversationId>', _getMessages);

    // Send a message
    router.post('/conversations/<conversationId>', _sendMessage);

    // Mark messages as read
    router.put('/conversations/<conversationId>/read', _markAsRead);

    return router;
  }

  /// Get conversations for current user
  Future<Response> _getConversations(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      if (userId == null) {
        return ResponseUtils.unauthorized('User not authenticated');
      }

      // Get conversations with latest message
      final query = '''
        SELECT DISTINCT 
          CASE 
            WHEN m.sender_id = \$1 THEN m.receiver_id 
            ELSE m.sender_id 
          END as other_user_id,
          u.display_name as other_user_name,
          u.profile_image_url as other_user_profile_picture,
          m.conversation_id,
          latest.content as last_message,
          latest.created_at as last_message_time,
          latest.sender_id as last_message_sender_id,
          COUNT(CASE WHEN m.receiver_id = \$1 AND m.read_at IS NULL THEN 1 END) as unread_count
        FROM messages m
        JOIN users u ON (
          CASE 
            WHEN m.sender_id = \$1 THEN m.receiver_id 
            ELSE m.sender_id 
          END = u.id
        )
        JOIN (
          SELECT conversation_id, content, created_at, sender_id,
                 ROW_NUMBER() OVER (PARTITION BY conversation_id ORDER BY created_at DESC) as rn
          FROM messages
        ) latest ON m.conversation_id = latest.conversation_id AND latest.rn = 1
        WHERE m.sender_id = @userId OR m.receiver_id = @userId
        GROUP BY other_user_id, u.display_name, u.profile_image_url, m.conversation_id, 
                 latest.content, latest.created_at, latest.sender_id
        ORDER BY latest.created_at DESC
      ''';

      final result = await DatabaseConfig.connection.query(
        query,
        substitutionValues: {'userId': userId},
      );

      final conversations = result.map((row) {
        final data = row.toColumnMap();
        return {
          'conversationId': data['conversation_id'],
          'otherUser': {
            'id': data['other_user_id'],
            'name': data['other_user_name'],
            'profilePicture': data['other_user_profile_picture'],
          },
          'lastMessage': {
            'content': data['last_message'],
            'time': (data['last_message_time'] as DateTime).toIso8601String(),
            'senderId': data['last_message_sender_id'],
          },
          'unreadCount': data['unread_count'],
        };
      }).toList();

      return ResponseUtils.success({
        'conversations': conversations,
      });
    } catch (e) {
      return ResponseUtils.serverError('Error fetching conversations: $e');
    }
  }

  /// Get messages in a conversation
  Future<Response> _getMessages(Request request, String conversationId) async {
    try {
      final userId = request.context['userId'] as String?;
      if (userId == null) {
        return ResponseUtils.unauthorized('User not authenticated');
      }

      final params = request.url.queryParameters;
      final page = int.tryParse(params['page'] ?? '1') ?? 1;
      final limit = int.tryParse(params['limit'] ?? '50') ?? 50;
      final offset = (page - 1) * limit;

      // Verify user is part of this conversation
      final conversationCheck = await DatabaseConfig.connection.query(
        'SELECT COUNT(*) as count FROM messages WHERE conversation_id = @conversationId AND (sender_id = @userId OR receiver_id = @userId)',
        substitutionValues: {'conversationId': conversationId, 'userId': userId},
      );

      if (conversationCheck.first.toColumnMap()['count'] as int == 0) {
        return ResponseUtils.forbidden('You are not part of this conversation');
      }

      // Get total count
      final countResult = await DatabaseConfig.connection.query(
        'SELECT COUNT(*) as count FROM messages WHERE conversation_id = @conversationId',
        substitutionValues: {'conversationId': conversationId},
      );
      final total = countResult.first.toColumnMap()['count'] as int;

      // Get messages with sender information
      final query = '''
        SELECT m.*, u.display_name as sender_name, u.profile_image_url as sender_profile_picture
        FROM messages m
        LEFT JOIN users u ON m.sender_id = u.id
        WHERE m.conversation_id = @conversationId
        ORDER BY m.created_at DESC
        LIMIT @limit OFFSET @offset
      ''';

      final result = await DatabaseConfig.connection.query(
        query,
        substitutionValues: {
          'conversationId': conversationId,
          'limit': limit,
          'offset': offset,
        },
      );

      final messages = result.map((row) {
        final data = row.toColumnMap();
        return MessageModel.fromDatabaseRow(data).copyWith(
          senderName: data['sender_name'] as String?,
          senderProfilePicture: data['sender_profile_picture'] as String?,
        );
      }).toList();

      return ResponseUtils.success({
        'data': messages.map((message) => message.toJson()).toList(),
        'pagination': {
          'page': page,
          'limit': limit,
          'total': total,
          'totalPages': (total / limit).ceil(),
        },
      });
    } catch (e) {
      return ResponseUtils.serverError('Error fetching messages: $e');
    }
  }

  /// Send a message
  Future<Response> _sendMessage(Request request, String conversationId) async {
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
        ['receiverId', 'content'],
      );

      if (validationResult != null) {
        return ResponseUtils.error(validationResult);
      }

      final receiverId = data['receiverId'] as String;
      final content = data['content'] as String;

      // Create message
      final messageId = _uuid.v4();
      final message = MessageModel(
        id: messageId,
        conversationId: conversationId,
        senderId: userId,
        receiverId: receiverId,
        content: content,
        messageType: data['messageType'] as String? ?? 'text',
        mediaUrl: data['mediaUrl'] as String?,
        tradeId: data['tradeId'] as String?,
        createdAt: DateTime.now(),
      );

      // Insert into database
      await DatabaseConfig.connection.query(
        '''INSERT INTO messages (id, conversation_id, sender_id, receiver_id, content,
           message_type, media_url, trade_id, created_at)
           VALUES (@id, @conversationId, @senderId, @receiverId, @content, @messageType, @mediaUrl, @tradeId, @createdAt)''',
        substitutionValues: {
          'id': message.id,
          'conversationId': message.conversationId,
          'senderId': message.senderId,
          'receiverId': message.receiverId,
          'content': message.content,
          'messageType': message.messageType,
          'mediaUrl': message.mediaUrl,
          'tradeId': message.tradeId,
          'createdAt': message.createdAt,
        },
      );

      return ResponseUtils.success({
        'message': 'Message sent successfully',
        'data': message.toJson(),
      });
    } catch (e) {
      return ResponseUtils.serverError('Error sending message: $e');
    }
  }

  /// Mark messages as read
  Future<Response> _markAsRead(Request request, String conversationId) async {
    try {
      final userId = request.context['userId'] as String?;
      if (userId == null) {
        return ResponseUtils.unauthorized('User not authenticated');
      }

      // Mark all unread messages in this conversation as read
      await DatabaseConfig.connection.query(
        'UPDATE messages SET read_at = @readAt WHERE conversation_id = @conversationId AND receiver_id = @userId AND read_at IS NULL',
        substitutionValues: {
          'readAt': DateTime.now(),
          'conversationId': conversationId,
          'userId': userId,
        },
      );

      return ResponseUtils.success({
        'message': 'Messages marked as read',
      });
    } catch (e) {
      return ResponseUtils.serverError('Error marking messages as read: $e');
    }
  }
}
