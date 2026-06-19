import 'package:cryptography/cryptography.dart';

import '../domain/license_verification_result.dart';
import '../domain/signed_license.dart';
import 'license_key_registry.dart';

class LicenseVerifier {
  LicenseVerifier(this._keyRegistry, {Ed25519? algorithm})
    : _algorithm = algorithm ?? Ed25519();

  final LicenseKeyRegistry _keyRegistry;
  final Ed25519 _algorithm;

  Future<LicenseVerificationResult> verify(
    SignedLicense license, {
    required String installationId,
    DateTime? now,
  }) async {
    final publicKey = _keyRegistry.find(license.keyId);
    if (publicKey == null) {
      return const LicenseVerificationResult(
        status: LicenseVerificationStatus.unsupportedKey,
        message: 'La licencia fue emitida con una clave no reconocida.',
      );
    }

    try {
      final signatureIsValid = await _algorithm.verify(
        license.payloadBytes,
        signature: Signature(license.signatureBytes, publicKey: publicKey),
      );
      if (!signatureIsValid) {
        return const LicenseVerificationResult(
          status: LicenseVerificationStatus.invalidSignature,
          message: 'La firma digital de la licencia no es válida.',
        );
      }

      final payload = license.decodePayload();
      if (payload.product != 'pondera') {
        return LicenseVerificationResult(
          status: LicenseVerificationStatus.wrongProduct,
          message: 'La licencia no corresponde a Pondera.',
          payload: payload,
        );
      }
      if (payload.installationId != installationId) {
        return LicenseVerificationResult(
          status: LicenseVerificationStatus.wrongInstallation,
          message:
              'La licencia corresponde a otro equipo (${payload.deviceLabel}).',
          payload: payload,
        );
      }

      final currentTime = (now ?? DateTime.now()).toUtc();
      if (currentTime.isBefore(payload.notBefore)) {
        return LicenseVerificationResult(
          status: LicenseVerificationStatus.notYetValid,
          message: 'La licencia todavía no está vigente.',
          payload: payload,
        );
      }

      final expiresAt = payload.expiresAt;
      if (expiresAt != null && currentTime.isAfter(expiresAt)) {
        final graceUntil = payload.graceUntil;
        if (graceUntil != null && !currentTime.isAfter(graceUntil)) {
          return LicenseVerificationResult(
            status: LicenseVerificationStatus.gracePeriod,
            message:
                'Licencia en período de gracia hasta ${_formatDate(graceUntil)}.',
            payload: payload,
          );
        }
        return LicenseVerificationResult(
          status: LicenseVerificationStatus.expired,
          message: 'Licencia vencida el ${_formatDate(expiresAt)}.',
          payload: payload,
        );
      }

      final expirationMessage = expiresAt == null
          ? 'Licencia perpetua activa.'
          : 'Licencia activa hasta ${_formatDate(expiresAt)}.';
      return LicenseVerificationResult(
        status: LicenseVerificationStatus.active,
        message: expirationMessage,
        payload: payload,
      );
    } on FormatException catch (error) {
      return LicenseVerificationResult(
        status: LicenseVerificationStatus.malformed,
        message: 'La licencia tiene un formato inválido: ${error.message}',
      );
    } catch (_) {
      return const LicenseVerificationResult(
        status: LicenseVerificationStatus.malformed,
        message: 'No se pudo interpretar la licencia.',
      );
    }
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}
