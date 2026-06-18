import '../../settings/data/settings_repository.dart';
import '../domain/demo_license.dart';

class DemoLicenseController {
  DemoLicenseController(this._settingsRepository, {DateTime? expirationDate})
    : expirationDate = expirationDate ?? DateTime(2026, 7, 16, 23, 59, 59);

  final SettingsRepository _settingsRepository;
  final DateTime expirationDate;

  Future<DemoLicense> validate({DateTime? now}) async {
    final currentTime = now ?? DateTime.now();
    final lastRunValue = _settingsRepository.demoLastRun;
    final lastRun = lastRunValue == null
        ? null
        : DateTime.tryParse(lastRunValue)?.toLocal();
    final license = DemoLicense.evaluate(
      now: currentTime,
      expirationDate: expirationDate,
      locked: _settingsRepository.isDemoLocked,
      lastRun: lastRun,
    );

    if (license.isExpired) {
      await _settingsRepository.lockDemo();
    } else {
      await _settingsRepository.saveDemoLastRun(currentTime);
    }
    return license;
  }

  Future<DemoLicense?> checkDuringRuntime({
    required DemoLicense currentLicense,
    DateTime? now,
  }) async {
    final currentTime = now ?? DateTime.now();
    if (currentLicense.isExpired || currentTime.isBefore(expirationDate)) {
      return null;
    }

    await _settingsRepository.lockDemo();
    return DemoLicense(
      expirationDate: expirationDate,
      status: DemoLicenseStatus.expired,
    );
  }

  Future<DemoLicense> resetForDevelopment({DateTime? now}) async {
    await _settingsRepository.resetDemo();
    return validate(now: now);
  }
}
