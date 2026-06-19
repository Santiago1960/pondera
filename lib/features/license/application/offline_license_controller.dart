import '../data/installation_identity_repository.dart';
import '../data/license_verifier.dart';
import '../data/offline_license_repository.dart';
import '../domain/license_verification_result.dart';
import '../domain/signed_license.dart';

class OfflineLicenseController {
  const OfflineLicenseController(
    this._identityRepository,
    this._licenseRepository,
    this._licenseVerifier,
  );

  final InstallationIdentityRepository _identityRepository;
  final OfflineLicenseRepository _licenseRepository;
  final LicenseVerifier _licenseVerifier;

  static const _clockRollbackTolerance = Duration(minutes: 5);

  Future<LicenseVerificationResult> validateStored({DateTime? now}) async {
    final encodedLicense = _licenseRepository.load();
    if (encodedLicense == null || encodedLicense.trim().isEmpty) {
      return const LicenseVerificationResult(
        status: LicenseVerificationStatus.missing,
        message: 'No hay una licencia offline instalada.',
      );
    }
    return _verify(encodedLicense, now: now);
  }

  Future<LicenseVerificationResult> import(
    String encodedLicense, {
    DateTime? now,
  }) async {
    final result = await _verify(encodedLicense, now: now);
    if (result.isUsable) {
      await _licenseRepository.save(encodedLicense);
    }
    return result;
  }

  Future<LicenseVerificationResult> _verify(
    String encodedLicense, {
    DateTime? now,
  }) async {
    try {
      final license = SignedLicense.decode(encodedLicense);
      final currentTime = (now ?? DateTime.now()).toUtc();
      final DateTime? lastValidation;
      try {
        lastValidation = _licenseRepository.loadLastValidation();
      } on FormatException catch (error) {
        return LicenseVerificationResult(
          status: LicenseVerificationStatus.clockTampered,
          message: 'No se pudo validar el historial local: ${error.message}',
        );
      }
      if (lastValidation != null &&
          currentTime.isBefore(
            lastValidation.subtract(_clockRollbackTolerance),
          )) {
        return const LicenseVerificationResult(
          status: LicenseVerificationStatus.clockTampered,
          message:
              'Licencia bloqueada: se detectó un retroceso en la fecha del sistema.',
        );
      }

      final effectiveTime =
          lastValidation != null && currentTime.isBefore(lastValidation)
          ? lastValidation
          : currentTime;
      final result = await _licenseVerifier.verify(
        license,
        installationId: await _identityRepository.getOrCreate(),
        now: effectiveTime,
      );
      if (_recordsValidationTime(result.status) &&
          (lastValidation == null || effectiveTime.isAfter(lastValidation))) {
        await _licenseRepository.saveLastValidation(effectiveTime);
      }
      return result;
    } on FormatException catch (error) {
      return LicenseVerificationResult(
        status: LicenseVerificationStatus.malformed,
        message: 'Archivo de licencia inválido: ${error.message}',
      );
    } catch (_) {
      return const LicenseVerificationResult(
        status: LicenseVerificationStatus.malformed,
        message: 'No se pudo leer el archivo de licencia.',
      );
    }
  }
}

bool _recordsValidationTime(LicenseVerificationStatus status) {
  return status == LicenseVerificationStatus.active ||
      status == LicenseVerificationStatus.gracePeriod ||
      status == LicenseVerificationStatus.notYetValid ||
      status == LicenseVerificationStatus.expired;
}
