import 'dart:convert';

abstract final class LicenseSerialization {
  static String requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('El campo $key es obligatorio.');
    }
    return value.trim();
  }

  static String? optionalString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) {
      return null;
    }
    if (value is! String) {
      throw FormatException('El campo $key debe ser texto.');
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static DateTime requiredUtcDateTime(Map<String, dynamic> json, String key) {
    final value = requiredString(json, key);
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw FormatException('El campo $key debe ser una fecha ISO 8601.');
    }
    return parsed.toUtc();
  }

  static DateTime? optionalUtcDateTime(Map<String, dynamic> json, String key) {
    if (json[key] == null) {
      return null;
    }
    return requiredUtcDateTime(json, key);
  }

  static String encodeBase64Url(List<int> bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static List<int> decodeBase64Url(String value) {
    final missingPadding = (4 - value.length % 4) % 4;
    return base64Url.decode(value.padRight(value.length + missingPadding, '='));
  }

  static List<int> decodeHex(String value) {
    return List<int>.generate(
      value.length ~/ 2,
      (index) =>
          int.parse(value.substring(index * 2, index * 2 + 2), radix: 16),
    );
  }
}
