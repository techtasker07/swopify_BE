import 'dart:convert';

/// Model class for User data
class UserModel {
  final String id;
  final String email;
  final String displayName;
  final String bio;
  final String? profileImageUrl;
  final String? phoneNumber;
  final Map<String, dynamic>? location;
  final List<String> interests;
  final List<String> tradePreferences;
  final bool kycVerified;
  final int barterScore;
  final List<String> badges;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    this.bio = '',
    this.profileImageUrl,
    this.phoneNumber,
    this.location,
    this.interests = const [],
    this.tradePreferences = const [],
    this.kycVerified = false,
    this.barterScore = 0,
    this.badges = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a copy of this user with optional new values
  UserModel copyWith({
    String? id,
    String? email,
    String? displayName,
    String? bio,
    String? profileImageUrl,
    String? phoneNumber,
    Map<String, dynamic>? location,
    List<String>? interests,
    List<String>? tradePreferences,
    bool? kycVerified,
    int? barterScore,
    List<String>? badges,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      location: location ?? this.location,
      interests: interests ?? this.interests,
      tradePreferences: tradePreferences ?? this.tradePreferences,
      kycVerified: kycVerified ?? this.kycVerified,
      barterScore: barterScore ?? this.barterScore,
      badges: badges ?? this.badges,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Convert from JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      profileImageUrl: json['profile_image_url'] as String?,
      phoneNumber: json['phone_number'] as String?,
      location: json['location'] as Map<String, dynamic>?,
      interests: (json['interests'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      tradePreferences: (json['trade_preferences'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      kycVerified: json['kyc_verified'] as bool? ?? false,
      barterScore: json['barter_score'] as int? ?? 0,
      badges: (json['badges'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
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
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'bio': bio,
      'profile_image_url': profileImageUrl,
      'phone_number': phoneNumber,
      'location': location,
      'interests': interests,
      'trade_preferences': tradePreferences,
      'kyc_verified': kycVerified,
      'barter_score': barterScore,
      'badges': badges,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Convert to database map for PostgreSQL
  Map<String, dynamic> toDatabaseMap() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'bio': bio,
      'profile_image_url': profileImageUrl,
      'phone_number': phoneNumber,
      'location': location != null ? jsonEncode(location) : null,
      'interests': interests,
      'trade_preferences': tradePreferences,
      'kyc_verified': kycVerified,
      'barter_score': barterScore,
      'badges': badges,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  /// Create from database row
  factory UserModel.fromDatabaseRow(Map<String, dynamic> row) {
    return UserModel(
      id: row['id'] as String,
      email: row['email'] as String,
      displayName: row['display_name'] as String? ?? '',
      bio: row['bio'] as String? ?? '',
      profileImageUrl: row['profile_image_url'] as String?,
      phoneNumber: row['phone_number'] as String?,
      location: row['location'] != null
          ? jsonDecode(row['location'] as String) as Map<String, dynamic>
          : null,
      interests: (row['interests'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      tradePreferences: (row['trade_preferences'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      kycVerified: row['kyc_verified'] as bool? ?? false,
      barterScore: row['barter_score'] as int? ?? 0,
      badges: (row['badges'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      createdAt: row['created_at'] as DateTime,
      updatedAt: row['updated_at'] as DateTime,
    );
  }
}