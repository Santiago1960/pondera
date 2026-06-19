import 'license_payload.dart';

enum LicenseVerificationStatus {
  active,
  gracePeriod,
  missing,
  malformed,
  unsupportedKey,
  invalidSignature,
  wrongProduct,
  wrongInstallation,
  notYetValid,
  expired,
  clockTampered,
}

class LicenseVerificationResult {
  const LicenseVerificationResult({
    required this.status,
    required this.message,
    this.payload,
  });

  final LicenseVerificationStatus status;
  final String message;
  final LicensePayload? payload;

  bool get isUsable =>
      status == LicenseVerificationStatus.active ||
      status == LicenseVerificationStatus.gracePeriod;
}
