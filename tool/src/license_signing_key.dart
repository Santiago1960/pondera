import 'dart:convert';

class LicenseSigningKey {
  const LicenseSigningKey({required this.keyId, required this.seedBytes});

  static const schemaVersion = 1;
  static const algorithm = 'Ed25519';

  final String keyId;
  final List<int> seedBytes;

  factory LicenseSigningKey.decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('La clave debe ser un objeto JSON.');
    }
    if (decoded['schema_version'] != schemaVersion) {
      throw const FormatException('Versión de clave no soportada.');
    }
    if (decoded['algorithm'] != algorithm) {
      throw const FormatException('Algoritmo de clave no soportado.');
    }

    final keyId = _requiredString(decoded, 'key_id');
    final encodedSeed = _requiredString(decoded, 'private_seed');
    final seedBytes = _decodeBase64Url(encodedSeed);
    if (seedBytes.length != 32) {
      throw const FormatException(
        'La semilla privada Ed25519 debe contener exactamente 32 bytes.',
      );
    }

    return LicenseSigningKey(
      keyId: keyId,
      seedBytes: List<int>.unmodifiable(seedBytes),
    );
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('El campo $key es obligatorio.');
  }
  return value.trim();
}

List<int> _decodeBase64Url(String value) {
  try {
    final missingPadding = (4 - value.length % 4) % 4;
    return base64Url.decode(value.padRight(value.length + missingPadding, '='));
  } on FormatException {
    throw const FormatException('El campo private_seed no es Base64 válido.');
  }
}
