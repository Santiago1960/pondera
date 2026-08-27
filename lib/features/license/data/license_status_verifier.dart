import 'package:cryptography/cryptography.dart';

import '../domain/license_status_response.dart';
import '../domain/signed_license.dart';
import 'license_key_registry.dart';

class LicenseStatusVerifier {
  LicenseStatusVerifier(this._keyRegistry, {Ed25519? algorithm})
    : _algorithm = algorithm ?? Ed25519();

  final LicenseKeyRegistry _keyRegistry;
  final Ed25519 _algorithm;

  Future<LicenseStatusResponse> verify(
    String source, {
    required String expectedInstallationId,
    String? expectedRequestId,
    String? expectedLicenseId,
    bool checkLicenseId = false,
  }) async {
    final document = SignedLicense.decode(source);
    final publicKey = _keyRegistry.find(document.keyId);
    if (publicKey == null) {
      throw const FormatException(
        'El estado fue firmado con una clave desconocida.',
      );
    }
    final valid = await _algorithm.verify(
      document.payloadBytes,
      signature: Signature(document.signatureBytes, publicKey: publicKey),
    );
    if (!valid) {
      throw const FormatException(
        'La firma del estado de licencia no es válida.',
      );
    }
    return LicenseStatusResponse.decode(
      document.payloadBytes,
      expectedInstallationId: expectedInstallationId,
      expectedRequestId: expectedRequestId,
      expectedLicenseId: expectedLicenseId,
      checkLicenseId: checkLicenseId,
    );
  }
}
