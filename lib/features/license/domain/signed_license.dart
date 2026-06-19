import 'dart:convert';

import 'license_payload.dart';

class SignedLicense {
  const SignedLicense({
    required this.keyId,
    required this.payload,
    required this.signature,
  });

  static const schemaVersion = 1;
  static const algorithm = 'Ed25519';

  final String keyId;
  final String payload;
  final String signature;

  List<int> get payloadBytes => _decodeBase64Url(payload);
  List<int> get signatureBytes => _decodeBase64Url(signature);

  LicensePayload decodePayload() => LicensePayload.decode(payloadBytes);

  Map<String, Object> toJson() {
    return {
      'schema_version': schemaVersion,
      'algorithm': algorithm,
      'key_id': keyId,
      'payload': payload,
      'signature': signature,
    };
  }

  String encode() => jsonEncode(toJson());

  factory SignedLicense.fromBytes({
    required String keyId,
    required List<int> payloadBytes,
    required List<int> signatureBytes,
  }) {
    return SignedLicense(
      keyId: keyId,
      payload: _encodeBase64Url(payloadBytes),
      signature: _encodeBase64Url(signatureBytes),
    );
  }

  factory SignedLicense.decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('La licencia debe ser un objeto JSON.');
    }
    if (decoded['schema_version'] != schemaVersion) {
      throw const FormatException('Versión de sobre no soportada.');
    }
    if (decoded['algorithm'] != algorithm) {
      throw const FormatException('Algoritmo de firma no soportado.');
    }

    final license = SignedLicense(
      keyId: _requiredString(decoded, 'key_id'),
      payload: _requiredString(decoded, 'payload'),
      signature: _requiredString(decoded, 'signature'),
    );
    license.payloadBytes;
    license.signatureBytes;
    return license;
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('El campo $key es obligatorio.');
  }
  return value.trim();
}

String _encodeBase64Url(List<int> bytes) {
  return base64Url.encode(bytes).replaceAll('=', '');
}

List<int> _decodeBase64Url(String value) {
  final missingPadding = (4 - value.length % 4) % 4;
  return base64Url.decode(value.padRight(value.length + missingPadding, '='));
}
