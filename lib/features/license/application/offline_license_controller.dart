import '../data/installation_identity_repository.dart';
import '../data/license_verifier.dart';
import '../data/license_status_verifier.dart';
import '../data/offline_license_repository.dart';
import '../domain/license_verification_result.dart';
import '../domain/signed_license.dart';

class OfflineLicenseController {
  const OfflineLicenseController(
    this._identityRepository,
    this._licenseRepository,
    this._licenseVerifier,
    this._licenseStatusVerifier,
  );

  final InstallationIdentityRepository _identityRepository;
  final OfflineLicenseRepository _licenseRepository;
  final LicenseVerifier _licenseVerifier;
  final LicenseStatusVerifier _licenseStatusVerifier;

  static const _clockRollbackTolerance = Duration(minutes: 5);

  Future<LicenseVerificationResult> validateStored({DateTime? now}) async {
    final encodedLicense = await _licenseRepository.load();
    if (encodedLicense == null || encodedLicense.trim().isEmpty) {
      return _applyRemoteStatus(
        const LicenseVerificationResult(
          status: LicenseVerificationStatus.missing,
          message: 'No hay una licencia offline instalada.',
        ),
      );
    }
    return _verify(encodedLicense, now: now);
  }

  Future<LicenseVerificationResult> acceptRemoteStatus(
    String encodedStatus, {
    required String expectedRequestId,
    DateTime? now,
  }) async {
    final current = await validateStored(now: now);
    final installationId = await _identityRepository.getOrCreate();
    final status = await _licenseStatusVerifier.verify(
      encodedStatus,
      expectedInstallationId: installationId,
      expectedRequestId: expectedRequestId,
      expectedLicenseId: current.payload?.licenseId,
      checkLicenseId: true,
    );
    if (!status.isAllow && !status.isDefinitiveBlock) return current;
    final stored = _licenseRepository.loadSignedStatus();
    if (stored != null) {
      try {
        final previous = await _licenseStatusVerifier.verify(
          stored,
          expectedInstallationId: installationId,
        );
        if (status.serverTime.isBefore(previous.serverTime)) {
          return current;
        }
      } on FormatException {
        // Una respuesta nueva y válida recupera un estado local dañado.
      }
    }
    await _licenseRepository.saveSignedStatus(encodedStatus);
    return validateStored(now: now);
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
      return _applyRemoteStatus(result);
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

  Future<LicenseVerificationResult> _applyRemoteStatus(
    LicenseVerificationResult local,
  ) async {
    final stored = _licenseRepository.loadSignedStatus();
    if (stored == null) return local;
    try {
      final status = await _licenseStatusVerifier.verify(
        stored,
        expectedInstallationId: await _identityRepository.getOrCreate(),
      );
      if (status.blocksInstallation) {
        return LicenseVerificationResult(
          status: LicenseVerificationStatus.blocked,
          message: status.message,
          payload: local.payload,
        );
      }
      if (status.revokesLicense &&
          status.licenseId == local.payload?.licenseId) {
        return LicenseVerificationResult(
          status: LicenseVerificationStatus.revoked,
          message: status.message,
          payload: local.payload,
        );
      }
      return local;
    } on FormatException catch (error) {
      return LicenseVerificationResult(
        status: LicenseVerificationStatus.malformed,
        message: 'No se pudo validar el último estado remoto: ${error.message}',
        payload: local.payload,
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
