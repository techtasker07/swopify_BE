/// Utility class for input validation
class ValidationUtils {
  /// Validate required fields in a data map
  static String? validateFields(
    Map<String, dynamic> data,
    List<String> requiredFields,
  ) {
    final missingFields = <String>[];

    for (final field in requiredFields) {
      if (!data.containsKey(field) || data[field] == null) {
        missingFields.add(field);
      } else if (data[field] is String && (data[field] as String).trim().isEmpty) {
        missingFields.add(field);
      }
    }

    if (missingFields.isNotEmpty) {
      return 'Missing required fields: ${missingFields.join(', ')}';
    }

    return null;
  }

  /// Validate email format
  static bool isValidEmail(String email) {
    final emailRegExp = RegExp(
      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
    );
    return emailRegExp.hasMatch(email);
  }

  /// Validate password strength
  static bool isValidPassword(String password) {
    // At least 6 characters
    return password.length >= 6;
  }

  /// Validate numeric value
  static bool isNumeric(String value) {
    return double.tryParse(value) != null;
  }

  /// Validate integer value
  static bool isInteger(String value) {
    return int.tryParse(value) != null;
  }

  /// Validate URL format
  static bool isValidUrl(String url) {
    final urlRegExp = RegExp(
      r'^(http|https)://[\w-]+(\.[\w-]+)+([\w.,@?^=%&:/~+#-]*[\w@?^=%&/~+#-])?$',
    );
    return urlRegExp.hasMatch(url);
  }

  /// Validate date format (YYYY-MM-DD)
  static bool isValidDate(String date) {
    final dateRegExp = RegExp(
      r'^\d{4}-\d{2}-\d{2}$',
    );
    if (!dateRegExp.hasMatch(date)) {
      return false;
    }

    try {
      DateTime.parse(date);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Validate phone number format
  static bool isValidPhoneNumber(String phoneNumber) {
    final phoneRegExp = RegExp(
      r'^\+?[0-9]{10,15}$',
    );
    return phoneRegExp.hasMatch(phoneNumber);
  }
}