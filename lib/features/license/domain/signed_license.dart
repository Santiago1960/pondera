import 'dart:convert';

import 'license_payload.dart';
import 'license_serialization.dart';

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

  List<int> get payloadBytes => LicenseSerialization.decodeBase64Url(payload);
  List<int> get signatureBytes =>
      LicenseSerialization.decodeBase64Url(signature);

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
      payload: LicenseSerialization.encodeBase64Url(payloadBytes),
      signature: LicenseSerialization.encodeBase64Url(signatureBytes),
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
      keyId: LicenseSerialization.requiredString(decoded, 'key_id'),
      payload: LicenseSerialization.requiredString(decoded, 'payload'),
      signature: LicenseSerialization.requiredString(decoded, 'signature'),
    );
    license.payloadBytes;
    license.signatureBytes;
    return license;
  }
}
