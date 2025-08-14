import 'dart:convert';
import 'package:shelf/shelf.dart';

/// Utility class for creating standardized API responses
class ResponseUtils {
  /// Create a successful response with data
  static Response success(dynamic data, {int statusCode = 200}) {
    return Response(
      statusCode,
      body: jsonEncode({
        'success': true,
        'data': data,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Create an error response
  static Response error(String message, {int statusCode = 400}) {
    return Response(
      statusCode,
      body: jsonEncode({
        'success': false,
        'message': message,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Create a not found response
  static Response notFound(String message) {
    return error(message, statusCode: 404);
  }

  /// Create an unauthorized response
  static Response unauthorized(String message) {
    return error(message, statusCode: 401);
  }

  /// Create a forbidden response
  static Response forbidden(String message) {
    return error(message, statusCode: 403);
  }

  /// Create a server error response
  static Response serverError(String message) {
    return error(message, statusCode: 500);
  }

  /// Create a paginated response
  static Response paginated({
    required List<dynamic> items,
    required int totalItems,
    required int currentPage,
    required int totalPages,
    required String resourceName,
  }) {
    return success({
      resourceName: items,
      'pagination': {
        'totalItems': totalItems,
        'currentPage': currentPage,
        'totalPages': totalPages,
        'hasNextPage': currentPage < totalPages,
        'hasPreviousPage': currentPage > 1,
      },
    });
  }
}