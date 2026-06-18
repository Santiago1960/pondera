import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/core/constants/preference_keys.dart';
import 'package:pondera/features/license/application/demo_license_controller.dart';
import 'package:pondera/features/license/domain/demo_license.dart';
import 'package:pondera/features/settings/data/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final expirationDate = DateTime(2026, 7, 16, 23, 59, 59);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('mantiene activa la demo antes de su vencimiento', () async {
    final preferences = await SharedPreferences.getInstance();
    final controller = DemoLicenseController(
      SettingsRepository(preferences),
      expirationDate: expirationDate,
    );
    final now = DateTime(2026, 7, 1, 12);

    final license = await controller.validate(now: now);

    expect(license.status, DemoLicenseStatus.active);
    expect(
      preferences.getString(PreferenceKeys.demoLastRun),
      now.toIso8601String(),
    );
  });

  test('bloquea la demo después de su vencimiento', () async {
    final preferences = await SharedPreferences.getInstance();
    final controller = DemoLicenseController(
      SettingsRepository(preferences),
      expirationDate: expirationDate,
    );

    final license = await controller.validate(now: DateTime(2026, 7, 17));

    expect(license.status, DemoLicenseStatus.expired);
    expect(preferences.getBool(PreferenceKeys.demoLocked), isTrue);
  });

  test('bloquea la demo cuando detecta retroceso del reloj', () async {
    SharedPreferences.setMockInitialValues({
      PreferenceKeys.demoLastRun: DateTime(2026, 7, 10, 12).toIso8601String(),
    });
    final preferences = await SharedPreferences.getInstance();
    final controller = DemoLicenseController(
      SettingsRepository(preferences),
      expirationDate: expirationDate,
    );

    final license = await controller.validate(
      now: DateTime(2026, 7, 10, 11, 54),
    );

    expect(license.status, DemoLicenseStatus.clockTampered);
    expect(preferences.getBool(PreferenceKeys.demoLocked), isTrue);
  });

  test('restablece el bloqueo durante desarrollo', () async {
    SharedPreferences.setMockInitialValues({
      PreferenceKeys.demoLocked: true,
      PreferenceKeys.demoLastRun: DateTime(2026, 7, 10).toIso8601String(),
    });
    final preferences = await SharedPreferences.getInstance();
    final controller = DemoLicenseController(
      SettingsRepository(preferences),
      expirationDate: expirationDate,
    );

    final license = await controller.resetForDevelopment(
      now: DateTime(2026, 7, 1),
    );

    expect(license.status, DemoLicenseStatus.active);
    expect(preferences.getBool(PreferenceKeys.demoLocked), isNull);
    expect(
      preferences.getString(PreferenceKeys.demoLastRun),
      DateTime(2026, 7, 1).toIso8601String(),
    );
  });
}
