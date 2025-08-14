/// Model class for Message data
class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String receiverId;
  final String? content;
  final String messageType;
  final String? mediaUrl;
  final String? tradeId;
  final DateTime? readAt;
  final DateTime createdAt;

  // User details (denormalized for efficiency)
  final String? senderName;
  final String? senderProfilePicture;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    this.content,
    this.messageType = 'text',
    this.mediaUrl,
    this.tradeId,
    this.readAt,
    required this.createdAt,
    this.senderName,
    this.senderProfilePicture,
  });

  /// Create a copy of this message with optional new values
  MessageModel copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? receiverId,
    String? content,
    String? messageType,
    String? mediaUrl,
    String? tradeId,
    DateTime? readAt,
    DateTime? createdAt,
    String? senderName,
    String? senderProfilePicture,
  }) {
    return MessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      tradeId: tradeId ?? this.tradeId,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
      senderName: senderName ?? this.senderName,
      senderProfilePicture: senderProfilePicture ?? this.senderProfilePicture,
    );
  }

  /// Convert from JSON
  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String,
      content: json['content'] as String?,
      messageType: json['message_type'] as String? ?? 'text',
      mediaUrl: json['media_url'] as String?,
      tradeId: json['trade_id'] as String?,
      readAt: json['read_at'] != null
          ? (json['read_at'] is DateTime
              ? json['read_at'] as DateTime
              : DateTime.parse(json['read_at'] as String))
          : null,
      createdAt: json['created_at'] != null
          ? (json['created_at'] is DateTime
              ? json['created_at'] as DateTime
              : DateTime.parse(json['created_at'] as String))
          : DateTime.now(),
      senderName: json['sender_name'] as String?,
      senderProfilePicture: json['sender_profile_picture'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      'message_type': messageType,
      'media_url': mediaUrl,
      'trade_id': tradeId,
      'read_at': readAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'sender_name': senderName,
      'sender_profile_picture': senderProfilePicture,
    };
  }

  /// Convert to database map for PostgreSQL
  Map<String, dynamic> toDatabaseMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      'message_type': messageType,
      'media_url': mediaUrl,
      'trade_id': tradeId,
      'read_at': readAt,
      'created_at': createdAt,
    };
  }

  /// Create from database row
  factory MessageModel.fromDatabaseRow(Map<String, dynamic> row) {
    return MessageModel(
      id: row['id'] as String,
      conversationId: row['conversation_id'] as String,
      senderId: row['sender_id'] as String,
      receiverId: row['receiver_id'] as String,
      content: row['content'] as String?,
      messageType: row['message_type'] as String? ?? 'text',
      mediaUrl: row['media_url'] as String?,
      tradeId: row['trade_id'] as String?,
      readAt: row['read_at'] as DateTime?,
      createdAt: row['created_at'] as DateTime,
    );
  }

  /// Check if message is read
  bool get isRead => readAt != null;

  /// Format the time for display
  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 7) {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

/// Model class for Conversation data
class ConversationModel {
  final String id;
  final List<String> participants;
  final MessageModel lastMessage;
  final DateTime updatedAt;
  final bool hasUnreadMessages;
  final String? tradeId;
  
  // User details (denormalized for efficiency)
  final Map<String, UserInfo> userInfo;

  ConversationModel({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.updatedAt,
    this.hasUnreadMessages = false,
    this.tradeId,
    required this.userInfo,
  });

  /// Create a copy of this conversation with optional new values
  ConversationModel copyWith({
    String? id,
    List<String>? participants,
    MessageModel? lastMessage,
    DateTime? updatedAt,
    bool? hasUnreadMessages,
    String? tradeId,
    Map<String, UserInfo>? userInfo,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      updatedAt: updatedAt ?? this.updatedAt,
      hasUnreadMessages: hasUnreadMessages ?? this.hasUnreadMessages,
      tradeId: tradeId ?? this.tradeId,
      userInfo: userInfo ?? this.userInfo,
    );
  }

  /// Convert from JSON
  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    final userInfoMap = <String, UserInfo>{};
    if (json['userInfo'] != null) {
      (json['userInfo'] as Map<String, dynamic>).forEach((key, value) {
        userInfoMap[key] = UserInfo.fromJson(value as Map<String, dynamic>);
      });
    }

    return ConversationModel(
      id: json['id'] as String,
      participants: (json['participants'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      lastMessage: MessageModel.fromJson(
          json['lastMessage'] as Map<String, dynamic>),
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] is DateTime
              ? json['updatedAt'] as DateTime
              : DateTime.parse(json['updatedAt'] as String))
          : DateTime.now(),
      hasUnreadMessages: json['hasUnreadMessages'] as bool? ?? false,
      tradeId: json['tradeId'] as String?,
      userInfo: userInfoMap,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    final userInfoJson = <String, dynamic>{};
    userInfo.forEach((key, value) {
      userInfoJson[key] = value.toJson();
    });

    return {
      'id': id,
      'participants': participants,
      'lastMessage': lastMessage.toJson(),
      'updatedAt': updatedAt.toIso8601String(),
      'hasUnreadMessages': hasUnreadMessages,
      if (tradeId != null) 'tradeId': tradeId,
      'userInfo': userInfoJson,
    };
  }

  /// Get the other user's info (for 1-on-1 conversations)
  UserInfo getOtherUserInfo(String currentUserId) {
    final otherUserId =
        participants.firstWhere((id) => id != currentUserId, orElse: () => '');
    return userInfo[otherUserId] ?? UserInfo(name: 'Unknown', profilePicture: null);
  }
}

/// Helper class for user information in conversations
class UserInfo {
  final String name;
  final String? profilePicture;

  UserInfo({
    required this.name,
    this.profilePicture,
  });

  /// Convert from JSON
  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      name: json['name'] as String,
      profilePicture: json['profilePicture'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (profilePicture != null) 'profilePicture': profilePicture,
    };
  }
}