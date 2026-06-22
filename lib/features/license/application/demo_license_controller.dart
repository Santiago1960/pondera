import '../../settings/data/settings_repository.dart';
import '../domain/demo_license.dart';

class DemoLicenseController {
  DemoLicenseController(this._settingsRepository, {Duration? demoDuration})
    : demoDuration = demoDuration ?? const Duration(days: 15);

  final SettingsRepository _settingsRepository;
  final Duration demoDuration;

  Future<DemoLicense> validate({DateTime? now}) async {
    final currentTime = now ?? DateTime.now();
    final startedAt = _loadDemoStartedAt() ?? currentTime;
    final expirationDate = startedAt.add(demoDuration);
    final lastRunValue = _settingsRepository.demoLastRun;
    final lastRun = lastRunValue == null
        ? null
        : DateTime.tryParse(lastRunValue)?.toLocal();

    if (_settingsRepository.demoStartedAt == null) {
      await _settingsRepository.saveDemoStartedAt(startedAt);
    }

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
    if (currentLicense.isExpired ||
        currentTime.isBefore(currentLicense.expirationDate)) {
      return null;
    }

    await _settingsRepository.lockDemo();
    return DemoLicense(
      expirationDate: currentLicense.expirationDate,
      status: DemoLicenseStatus.expired,
    );
  }

  Future<DemoLicense> resetForDevelopment({DateTime? now}) async {
    await _settingsRepository.resetDemo();
    return validate(now: now);
  }

  DateTime? _loadDemoStartedAt() {
    final startedAtValue = _settingsRepository.demoStartedAt;
    return startedAtValue == null
        ? null
        : DateTime.tryParse(startedAtValue)?.toLocal();
  }
}
