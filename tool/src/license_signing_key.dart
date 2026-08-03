import 'dart:convert';

import 'package:pondera/features/license/domain/license_serialization.dart';

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

    final keyId = LicenseSerialization.requiredString(decoded, 'key_id');
    final encodedSeed = LicenseSerialization.requiredString(
      decoded,
      'private_seed',
    );
    final List<int> seedBytes;
    try {
      seedBytes = LicenseSerialization.decodeBase64Url(encodedSeed);
    } on FormatException {
      throw const FormatException('El campo private_seed no es Base64 válido.');
    }
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
