import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/core/constants/preference_keys.dart';
import 'package:pondera/features/license/application/offline_license_controller.dart';
import 'package:pondera/features/license/data/installation_identity_repository.dart';
import 'package:pondera/features/license/data/license_key_registry.dart';
import 'package:pondera/features/license/data/offline_license_file_store.dart';
import 'package:pondera/features/license/data/license_verifier.dart';
import 'package:pondera/features/license/data/offline_license_repository.dart';
import 'package:pondera/features/license/domain/license_payload.dart';
import 'package:pondera/features/license/domain/license_key_ids.dart';
import 'package:pondera/features/license/domain/license_verification_result.dart';
import 'package:pondera/features/license/domain/signed_license.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _seedHex =
    '9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('importa y persiste una licencia firmada válida', () async {
    final preferences = await SharedPreferences.getInstance();
    final controller = _buildController(preferences, 'INSTALL-TEST');
    final license = await _signedLicense(
      installationId: 'INSTALL-TEST',
      expiresAt: DateTime.utc(2026, 8, 1),
      graceUntil: DateTime.utc(2026, 8, 15),
    );

    final result = await controller.import(
      license.encode(),
      now: DateTime.utc(2026, 7, 1),
    );
    final reloaded = await controller.validateStored(
      now: DateTime.utc(2026, 7, 1),
    );

    expect(result.status, LicenseVerificationStatus.active);
    expect(result.payload?.customerName, 'SIGMA ALIMENTOS');
    expect(reloaded.status, LicenseVerificationStatus.active);
    expect(preferences.getString(PreferenceKeys.signedLicense), isNull);
  });

  test('rechaza una licencia emitida para otra instalación', () async {
    final preferences = await SharedPreferences.getInstance();
    final controller = _buildController(preferences, 'INSTALL-LOCAL');
    final license = await _signedLicense(
      installationId: 'INSTALL-OTHER',
      expiresAt: DateTime.utc(2026, 8, 1),
    );

    final result = await controller.import(
      license.encode(),
      now: DateTime.utc(2026, 7, 1),
    );

    expect(result.status, LicenseVerificationStatus.wrongInstallation);
    expect(preferences.getString(PreferenceKeys.signedLicense), isNull);
  });

  test('rechaza una firma alterada', () async {
    final preferences = await SharedPreferences.getInstance();
    final controller = _buildController(preferences, 'INSTALL-TEST');
    final license = await _signedLicense(
      installationId: 'INSTALL-TEST',
      expiresAt: DateTime.utc(2026, 8, 1),
    );
    final alteredSignature = [...license.signatureBytes]..[0] ^= 0xff;
    final alteredLicense = SignedLicense.fromBytes(
      keyId: license.keyId,
      payloadBytes: license.payloadBytes,
      signatureBytes: alteredSignature,
    );

    final result = await controller.import(
      alteredLicense.encode(),
      now: DateTime.utc(2026, 7, 1),
    );

    expect(result.status, LicenseVerificationStatus.invalidSignature);
  });

  test('distingue período de gracia y vencimiento definitivo', () async {
    final preferences = await SharedPreferences.getInstance();
    final controller = _buildController(preferences, 'INSTALL-TEST');
    final license = await _signedLicense(
      installationId: 'INSTALL-TEST',
      expiresAt: DateTime.utc(2026, 7, 1),
      graceUntil: DateTime.utc(2026, 7, 15),
    );

    final graceResult = await controller.import(
      license.encode(),
      now: DateTime.utc(2026, 7, 10),
    );
    final expiredResult = await controller.import(
      license.encode(),
      now: DateTime.utc(2026, 7, 16),
    );

    expect(graceResult.status, LicenseVerificationStatus.gracePeriod);
    expect(expiredResult.status, LicenseVerificationStatus.expired);
  });

  test(
    'trata vencimiento y fin de gracia como instantes UTC exclusivos',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final controller = _buildController(preferences, 'INSTALL-TEST');
      final license = await _signedLicense(
        installationId: 'INSTALL-TEST',
        expiresAt: DateTime.utc(2026, 8, 1),
        graceUntil: DateTime.utc(2026, 8, 15),
      );
      await controller.import(
        license.encode(),
        now: DateTime.utc(2026, 7, 31, 23, 59, 59),
      );

      final atExpiration = await controller.validateStored(
        now: DateTime.utc(2026, 8, 1),
      );
      final atGraceEnd = await controller.validateStored(
        now: DateTime.utc(2026, 8, 15),
      );

      expect(atExpiration.status, LicenseVerificationStatus.gracePeriod);
      expect(atGraceEnd.status, LicenseVerificationStatus.expired);
    },
  );

  test(
    'bloquea la licencia cuando el reloj retrocede más de cinco minutos',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final controller = _buildController(preferences, 'INSTALL-TEST');
      final license = await _signedLicense(
        installationId: 'INSTALL-TEST',
        expiresAt: DateTime.utc(2026, 8, 1),
      );
      await controller.import(
        license.encode(),
        now: DateTime.utc(2026, 7, 10, 12),
      );

      final result = await controller.validateStored(
        now: DateTime.utc(2026, 7, 10, 11, 54),
      );

      expect(result.status, LicenseVerificationStatus.clockTampered);
      expect(result.isUsable, isFalse);
    },
  );

  test(
    'tolera un ajuste menor del reloj sin retroceder la validación',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final controller = _buildController(preferences, 'INSTALL-TEST');
      final license = await _signedLicense(
        installationId: 'INSTALL-TEST',
        expiresAt: DateTime.utc(2026, 8, 1),
      );
      await controller.import(
        license.encode(),
        now: DateTime.utc(2026, 7, 10, 12),
      );

      final result = await controller.validateStored(
        now: DateTime.utc(2026, 7, 10, 11, 58),
      );

      expect(result.status, LicenseVerificationStatus.active);
      expect(
        preferences.getString(PreferenceKeys.offlineLicenseLastValidation),
        DateTime.utc(2026, 7, 10, 12).toIso8601String(),
      );
    },
  );

  test(
    'no permite recuperar una licencia vencida atrasando el reloj',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final controller = _buildController(preferences, 'INSTALL-TEST');
      final license = await _signedLicense(
        installationId: 'INSTALL-TEST',
        expiresAt: DateTime.utc(2026, 8, 1),
      );
      await controller.import(license.encode(), now: DateTime.utc(2026, 7, 1));
      final expired = await controller.validateStored(
        now: DateTime.utc(2026, 8, 2),
      );

      final rolledBack = await controller.validateStored(
        now: DateTime.utc(2026, 7, 15),
      );

      expect(expired.status, LicenseVerificationStatus.expired);
      expect(rolledBack.status, LicenseVerificationStatus.clockTampered);
    },
  );
}

OfflineLicenseController _buildController(
  SharedPreferences preferences,
  String installationId,
) {
  return OfflineLicenseController(
    InstallationIdentityRepository(_FixedInstallationStore(installationId)),
    OfflineLicenseRepository(_MemoryLicenseFileStore(), preferences),
    LicenseVerifier(LicenseKeyRegistry.forCurrentBuild()),
  );
}

class _MemoryLicenseFileStore implements OfflineLicenseFileStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    this.value = value;
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}

Future<SignedLicense> _signedLicense({
  required String installationId,
  required DateTime expiresAt,
  DateTime? graceUntil,
}) async {
  final payload = LicensePayload(
    licenseId: 'LIC-TEST',
    requestId: 'REQ-TEST',
    product: 'pondera',
    installationId: installationId,
    customerId: 'CLI-0042',
    customerName: 'SIGMA ALIMENTOS',
    siteId: 'SITE-001',
    siteName: 'Planta de embutidos',
    city: 'Cuenca',
    deviceLabel: 'PC-Producción-01',
    licenseType: LicenseType.subscription,
    issuedAt: DateTime.utc(2026, 6, 1),
    notBefore: DateTime.utc(2026, 6, 1),
    expiresAt: expiresAt,
    graceUntil: graceUntil,
    features: const ['tcp', 'serial', 'n8n', 'keyboard_output'],
  );
  final algorithm = Ed25519();
  final keyPair = await algorithm.newKeyPairFromSeed(_decodeHex(_seedHex));
  final payloadBytes = payload.encode();
  final signature = await algorithm.sign(payloadBytes, keyPair: keyPair);
  return SignedLicense.fromBytes(
    keyId: LicenseKeyIds.development,
    payloadBytes: payloadBytes,
    signatureBytes: signature.bytes,
  );
}

class _FixedInstallationStore implements InstallationValueStore {
  _FixedInstallationStore(this.value);

  final String value;

  @override
  Future<String?> read(String key) async => value;

  @override
  Future<void> write(String key, String value) async {}
}

List<int> _decodeHex(String value) {
  return List<int>.generate(
    value.length ~/ 2,
    (index) => int.parse(value.substring(index * 2, index * 2 + 2), radix: 16),
  );
}
