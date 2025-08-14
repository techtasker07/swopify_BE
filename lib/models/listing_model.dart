import 'dart:convert';

/// Model class for Listing data
class ListingModel {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String category;
  final String? condition;
  final double? estimatedValue;
  final List<String> images;
  final List<String> tradePreferences;
  final Map<String, dynamic>? location;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  // User details (denormalized for efficiency)
  final String? userName;
  final String? userProfilePicture;

  ListingModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.category,
    this.condition,
    this.estimatedValue,
    this.images = const [],
    this.tradePreferences = const [],
    this.location,
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
    this.userName,
    this.userProfilePicture,
  });

  /// Create a copy of this listing with optional new values
  ListingModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    String? category,
    String? condition,
    double? estimatedValue,
    List<String>? images,
    List<String>? tradePreferences,
    Map<String, dynamic>? location,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userName,
    String? userProfilePicture,
  }) {
    return ListingModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      condition: condition ?? this.condition,
      estimatedValue: estimatedValue ?? this.estimatedValue,
      images: images ?? this.images,
      tradePreferences: tradePreferences ?? this.tradePreferences,
      location: location ?? this.location,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userName: userName ?? this.userName,
      userProfilePicture: userProfilePicture ?? this.userProfilePicture,
    );
  }

  /// Convert from JSON
  factory ListingModel.fromJson(Map<String, dynamic> json) {
    return ListingModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      category: json['category'] as String,
      condition: json['condition'] as String?,
      estimatedValue: (json['estimated_value'] as num?)?.toDouble(),
      images: (json['images'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      tradePreferences: (json['trade_preferences'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      location: json['location'] as Map<String, dynamic>?,
      status: json['status'] as String? ?? 'active',
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
      userName: json['user_name'] as String?,
      userProfilePicture: json['user_profile_picture'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'category': category,
      'condition': condition,
      'estimated_value': estimatedValue,
      'images': images,
      'trade_preferences': tradePreferences,
      'location': location,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'user_name': userName,
      'user_profile_picture': userProfilePicture,
    };
  }

  /// Convert to database map for PostgreSQL
  Map<String, dynamic> toDatabaseMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'category': category,
      'condition': condition,
      'estimated_value': estimatedValue,
      'images': images,
      'trade_preferences': tradePreferences,
      'location': location != null ? jsonEncode(location) : null,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  /// Create from database row
  factory ListingModel.fromDatabaseRow(Map<String, dynamic> row) {
    return ListingModel(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      title: row['title'] as String,
      description: row['description'] as String? ?? '',
      category: row['category'] as String,
      condition: row['condition'] as String?,
      estimatedValue: (row['estimated_value'] as num?)?.toDouble(),
      images: (row['images'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      tradePreferences: (row['trade_preferences'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      location: row['location'] != null
          ? jsonDecode(row['location'] as String) as Map<String, dynamic>
          : null,
      status: row['status'] as String? ?? 'active',
      createdAt: row['created_at'] as DateTime,
      updatedAt: row['updated_at'] as DateTime,
    );
  }
}