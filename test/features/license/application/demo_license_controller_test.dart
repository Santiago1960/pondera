import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/core/constants/preference_keys.dart';
import 'package:pondera/features/license/application/demo_license_controller.dart';
import 'package:pondera/features/license/domain/demo_license.dart';
import 'package:pondera/features/settings/data/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const demoDuration = Duration(days: 15);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('inicia la demo en el primer arranque y guarda su vigencia', () async {
    final preferences = await SharedPreferences.getInstance();
    final controller = DemoLicenseController(
      SettingsRepository(preferences),
      demoDuration: demoDuration,
    );
    final now = DateTime(2026, 7, 1, 12);

    final license = await controller.validate(now: now);

    expect(license.status, DemoLicenseStatus.active);
    expect(
      preferences.getString(PreferenceKeys.demoStartedAt),
      now.toIso8601String(),
    );
    expect(
      preferences.getString(PreferenceKeys.demoLastRun),
      now.toIso8601String(),
    );
    expect(license.expirationDate, now.add(demoDuration));
  });

  test('mantiene la fecha original de inicio en arranques posteriores', () async {
    final startedAt = DateTime(2026, 7, 1, 12);
    SharedPreferences.setMockInitialValues({
      PreferenceKeys.demoStartedAt: startedAt.toIso8601String(),
    });
    final preferences = await SharedPreferences.getInstance();
    final controller = DemoLicenseController(
      SettingsRepository(preferences),
      demoDuration: demoDuration,
    );

    final license = await controller.validate(now: DateTime(2026, 7, 5, 8));

    expect(license.status, DemoLicenseStatus.active);
    expect(
      preferences.getString(PreferenceKeys.demoStartedAt),
      startedAt.toIso8601String(),
    );
    expect(license.expirationDate, startedAt.add(demoDuration));
  });

  test('bloquea la demo al completar los 15 días', () async {
    final startedAt = DateTime(2026, 7, 1, 12);
    SharedPreferences.setMockInitialValues({
      PreferenceKeys.demoStartedAt: startedAt.toIso8601String(),
    });
    final preferences = await SharedPreferences.getInstance();
    final controller = DemoLicenseController(
      SettingsRepository(preferences),
      demoDuration: demoDuration,
    );

    final license = await controller.validate(
      now: startedAt.add(demoDuration),
    );

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
      demoDuration: demoDuration,
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
      demoDuration: demoDuration,
    );

    final license = await controller.resetForDevelopment(
      now: DateTime(2026, 7, 1),
    );

    expect(license.status, DemoLicenseStatus.active);
    expect(preferences.getBool(PreferenceKeys.demoLocked), isNull);
    expect(
      preferences.getString(PreferenceKeys.demoStartedAt),
      DateTime(2026, 7, 1).toIso8601String(),
    );
    expect(
      preferences.getString(PreferenceKeys.demoLastRun),
      DateTime(2026, 7, 1).toIso8601String(),
    );
  });
}
