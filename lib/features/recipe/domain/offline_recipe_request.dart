import 'dart:convert';

import '../../scale_reading/domain/reading_parser.dart';

abstract final class RecipeProtocol {
  static const requestType = 'bitgenial.pondera.recipe-request';
  static const responseType = 'bitgenial.pondera.recipe-response';
  static const cipher = 'X25519-HKDF-SHA256-A256GCM';
  static const signatureContext = 'bitgenial:pondera:recipe-response:v1\u0000';
  static const encryptionContext = 'bitgenial:pondera:recipe-encryption:v1';
  static const localContext = 'bitgenial:pondera:recipe-storage:v1';
  static const maxFileBytes = 131072;

  static Map<String, dynamic> object(String source) {
    if (utf8.encode(source).length > maxFileBytes) {
      throw const FormatException('El archivo de receta es demasiado grande.');
    }
    final value = jsonDecode(source);
    if (value is! Map<String, dynamic>) {
      throw const FormatException(
        'El archivo de receta no tiene un formato válido.',
      );
    }
    return value;
  }

  static String text(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Falta el campo $key de la receta.');
    }
    return value;
  }

  static DateTime utc(Map<String, dynamic> map, String key) {
    final source = text(map, key);
    final date = DateTime.tryParse(source);
    if (date == null || !date.isUtc || !source.endsWith('Z')) {
      throw FormatException('El campo $key debe estar en UTC.');
    }
    return date;
  }

  static void fields(Map<String, dynamic> map, Set<String> fields) {
    if (map.keys.toSet().difference(fields).isNotEmpty ||
        fields.difference(map.keys.toSet()).isNotEmpty) {
      throw const FormatException('El archivo contiene campos incompatibles.');
    }
  }
}

class RecipeAuthorizationContext {
  const RecipeAuthorizationContext({
    required this.installationId,
    required this.deviceFingerprintHash,
    required this.isUsable,
    this.licenseId,
    this.licenseSha256,
    this.licenseDocument,
    this.validUntil,
  });

  final String installationId;
  final String deviceFingerprintHash;
  final bool isUsable;
  final String? licenseId;
  final String? licenseSha256;
  final String? licenseDocument;
  final DateTime? validUntil;

  void requireLicensed() {
    if (!isUsable ||
        licenseId == null ||
        licenseSha256 == null ||
        licenseDocument == null) {
      throw const FormatException(
        'Las recetas sin internet requieren una licencia importada vigente.',
      );
    }
  }

  bool matches(Map<String, dynamic> map) =>
      isUsable &&
      map['installation_id'] == installationId &&
      map['device_fingerprint_hash'] == deviceFingerprintHash &&
      map['license_id'] == licenseId &&
      map['license_file_sha256'] == licenseSha256;
}

class ActiveRecipe {
  const ActiveRecipe({
    required this.pattern,
    required this.expectedValue,
    this.validUntil,
  });
  final String pattern;
  final String expectedValue;
  final DateTime? validUntil;
}

class OfflineRecipeRequest {
  OfflineRecipeRequest(Map<String, dynamic> values)
    : data = Map.unmodifiable(values) {
    RecipeProtocol.fields(data, const {
      'schema_version',
      'type',
      'product',
      'request_id',
      'installation_id',
      'device_fingerprint_hash',
      'license_id',
      'license_file_sha256',
      'license_document',
      'recipient_public_key',
      'cipher',
      'platform',
      'app_version',
      'created_at',
      'trama',
      'valor_esperado',
    });
    if (data['schema_version'] != 1 ||
        data['type'] != RecipeProtocol.requestType ||
        data['product'] != 'pondera' ||
        data['cipher'] != RecipeProtocol.cipher) {
      throw const FormatException('La solicitud de receta es incompatible.');
    }
    for (final key in data.keys.where((key) => key != 'schema_version')) {
      RecipeProtocol.text(data, key);
    }
    if (rawData.length > 8192 ||
        !ReadingParser.isValidExpectedValue(expectedValue) ||
        !(double.tryParse(expectedValue.replaceAll(',', '.'))?.isFinite ??
            false)) {
      throw const FormatException(
        'La muestra o el peso esperado no son válidos.',
      );
    }
    RecipeProtocol.utc(data, 'created_at');
    final encodedKey = data['recipient_public_key'] as String;
    final publicKey = base64Url.decode(base64Url.normalize(encodedKey));
    if (publicKey.length != 32 ||
        base64Url.encode(publicKey).replaceAll('=', '') != encodedKey) {
      throw const FormatException(
        'La clave pública de la solicitud no es válida.',
      );
    }
  }

  final Map<String, dynamic> data;
  String get requestId => data['request_id'] as String;
  String get rawData => data['trama'] as String;
  String get expectedValue => data['valor_esperado'] as String;
  String get publicKey => data['recipient_public_key'] as String;
  String encode() => jsonEncode(data);
  factory OfflineRecipeRequest.decode(String source) =>
      OfflineRecipeRequest(RecipeProtocol.object(source));
}
