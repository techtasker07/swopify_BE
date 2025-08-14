/// Model class for Trade data
class TradeModel {
  final String id;
  final String initiatorId;
  final String receiverId;
  final String initiatorListingId;
  final String receiverListingId;
  final String status; // 'pending', 'accepted', 'rejected', 'completed', 'cancelled'
  final int tradeCoins;
  final String? message;
  final DateTime createdAt;
  final DateTime updatedAt;

  // User details (denormalized for efficiency)
  final String? initiatorName;
  final String? initiatorProfilePicture;
  final String? receiverName;
  final String? receiverProfilePicture;

  TradeModel({
    required this.id,
    required this.initiatorId,
    required this.receiverId,
    required this.initiatorListingId,
    required this.receiverListingId,
    this.status = 'pending',
    this.tradeCoins = 0,
    this.message,
    required this.createdAt,
    required this.updatedAt,
    this.initiatorName,
    this.initiatorProfilePicture,
    this.receiverName,
    this.receiverProfilePicture,
  });

  /// Create a copy of this trade with optional new values
  TradeModel copyWith({
    String? id,
    String? initiatorId,
    String? receiverId,
    String? initiatorListingId,
    String? receiverListingId,
    String? status,
    int? tradeCoins,
    String? message,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? initiatorName,
    String? initiatorProfilePicture,
    String? receiverName,
    String? receiverProfilePicture,
  }) {
    return TradeModel(
      id: id ?? this.id,
      initiatorId: initiatorId ?? this.initiatorId,
      receiverId: receiverId ?? this.receiverId,
      initiatorListingId: initiatorListingId ?? this.initiatorListingId,
      receiverListingId: receiverListingId ?? this.receiverListingId,
      status: status ?? this.status,
      tradeCoins: tradeCoins ?? this.tradeCoins,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      initiatorName: initiatorName ?? this.initiatorName,
      initiatorProfilePicture: initiatorProfilePicture ?? this.initiatorProfilePicture,
      receiverName: receiverName ?? this.receiverName,
      receiverProfilePicture: receiverProfilePicture ?? this.receiverProfilePicture,
    );
  }

  /// Convert from JSON
  factory TradeModel.fromJson(Map<String, dynamic> json) {
    return TradeModel(
      id: json['id'] as String,
      initiatorId: json['initiator_id'] as String,
      receiverId: json['receiver_id'] as String,
      initiatorListingId: json['initiator_listing_id'] as String,
      receiverListingId: json['receiver_listing_id'] as String,
      status: json['status'] as String? ?? 'pending',
      tradeCoins: json['trade_coins'] as int? ?? 0,
      message: json['message'] as String?,
      createdAt: json['created_at'] != null
          ? (json['created_at'] is DateTime
              ? json['created_at'] as DateTime
              : DateTime.parse(json['created_at'] as String))
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? (json['updated_at'] is DateTime
              ? json['updated_at'] as DateTime
              : DateTime.parse(json['updated_at'] as String))
          : DateTime.now(),
      initiatorName: json['initiator_name'] as String?,
      initiatorProfilePicture: json['initiator_profile_picture'] as String?,
      receiverName: json['receiver_name'] as String?,
      receiverProfilePicture: json['receiver_profile_picture'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'initiator_id': initiatorId,
      'receiver_id': receiverId,
      'initiator_listing_id': initiatorListingId,
      'receiver_listing_id': receiverListingId,
      'status': status,
      'trade_coins': tradeCoins,
      'message': message,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'initiator_name': initiatorName,
      'initiator_profile_picture': initiatorProfilePicture,
      'receiver_name': receiverName,
      'receiver_profile_picture': receiverProfilePicture,
    };
  }

  /// Convert to database map for PostgreSQL
  Map<String, dynamic> toDatabaseMap() {
    return {
      'id': id,
      'initiator_id': initiatorId,
      'receiver_id': receiverId,
      'initiator_listing_id': initiatorListingId,
      'receiver_listing_id': receiverListingId,
      'status': status,
      'trade_coins': tradeCoins,
      'message': message,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  /// Create from database row
  factory TradeModel.fromDatabaseRow(Map<String, dynamic> row) {
    return TradeModel(
      id: row['id'] as String,
      initiatorId: row['initiator_id'] as String,
      receiverId: row['receiver_id'] as String,
      initiatorListingId: row['initiator_listing_id'] as String,
      receiverListingId: row['receiver_listing_id'] as String,
      status: row['status'] as String? ?? 'pending',
      tradeCoins: row['trade_coins'] as int? ?? 0,
      message: row['message'] as String?,
      createdAt: row['created_at'] as DateTime,
      updatedAt: row['updated_at'] as DateTime,
    );
  }

  /// Check if trade is active
  bool get isActive {
    return status == 'pending';
  }

  /// Check if trade is completed
  bool get isCompleted {
    return status == 'completed';
  }

  /// Check if trade is cancelled
  bool get isCancelled {
    return status == 'rejected' || status == 'cancelled';
  }

  /// Get formatted date
  String get formattedDate {
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }
}