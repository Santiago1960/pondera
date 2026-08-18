import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/core/constants/preference_keys.dart';
import 'package:pondera/features/settings/data/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('carga los valores predeterminados', () async {
    final preferences = await SharedPreferences.getInstance();
    final settings = SettingsRepository(preferences).load();

    expect(settings.connectionType, 'ethernet');
    expect(settings.deviceIp, '192.168.100.134');
    expect(settings.devicePort, 3004);
    expect(settings.serialBaudRate, 9600);
    expect(settings.inputUnit, 'kg');
    expect(settings.outputUnit, 'kg');
    expect(settings.captureMode, 'indicatorPrint');
    expect(settings.captureStableMilliseconds, 1000);
    expect(settings.captureRangeEnabled, isFalse);
    expect(settings.captureMinimumWeight, isNull);
    expect(settings.captureMaximumWeight, isNull);
    expect(settings.captureRangeUnit, 'kg');
    expect(settings.recipePattern, isEmpty);
    expect(settings.expectedValue, isEmpty);
    expect(SettingsRepository(preferences).loadThemeMode(), 'system');
  });

  test('carga valores persistidos', () async {
    SharedPreferences.setMockInitialValues({
      PreferenceKeys.connectionType: 'serial',
      PreferenceKeys.ip: '10.0.0.8',
      PreferenceKeys.port: 4001,
      PreferenceKeys.expectedValue: ' 0,130 ',
      PreferenceKeys.inputUnit: 'lb',
      PreferenceKeys.outputUnit: 'g',
      PreferenceKeys.captureMode: 'automaticStable',
      PreferenceKeys.captureStableMilliseconds: 1500,
      PreferenceKeys.captureRangeEnabled: true,
      PreferenceKeys.captureMinimumWeight: 0.150,
      PreferenceKeys.captureMaximumWeight: 0.250,
      PreferenceKeys.captureRangeUnit: 'kg',
      PreferenceKeys.themeMode: 'dark',
    });
    final preferences = await SharedPreferences.getInstance();
    final settings = SettingsRepository(preferences).load();

    expect(settings.connectionType, 'serial');
    expect(settings.deviceIp, '10.0.0.8');
    expect(settings.devicePort, 4001);
    expect(settings.expectedValue, '0,130');
    expect(settings.inputUnit, 'lb');
    expect(settings.outputUnit, 'g');
    expect(settings.captureMode, 'automaticStable');
    expect(settings.captureStableMilliseconds, 1500);
    expect(settings.captureRangeEnabled, isTrue);
    expect(settings.captureMinimumWeight, 0.150);
    expect(settings.captureMaximumWeight, 0.250);
    expect(settings.captureRangeUnit, 'kg');
    expect(SettingsRepository(preferences).loadThemeMode(), 'dark');
  });

  test('guarda configuración y receta', () async {
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences);

    await repository.saveNetwork(ip: '10.0.0.9', port: 5000);
    await repository.saveUnits(inputUnit: 'kg', outputUnit: 'mg');
    await repository.saveWeightCapture(
      mode: 'indicatorPrint',
      stableMilliseconds: 1000,
      rangeEnabled: true,
      minimumWeight: 0.150,
      maximumWeight: 0.250,
      rangeUnit: 'kg',
    );
    await repository.saveRecipe(pattern: r'\d+[.,]\d+', expectedValue: '0.130');
    await repository.saveThemeMode('light');
    await repository.saveDemoStartedAt(DateTime(2026, 7, 1, 12));
    await repository.saveDemoLastRun(DateTime(2026, 7, 2, 8));

    expect(preferences.getString(PreferenceKeys.ip), '10.0.0.9');
    expect(preferences.getInt(PreferenceKeys.port), 5000);
    expect(preferences.getString(PreferenceKeys.outputUnit), 'mg');
    expect(preferences.getString(PreferenceKeys.captureMode), 'indicatorPrint');
    expect(preferences.getInt(PreferenceKeys.captureStableMilliseconds), 1000);
    expect(preferences.getBool(PreferenceKeys.captureRangeEnabled), isTrue);
    expect(preferences.getDouble(PreferenceKeys.captureMinimumWeight), 0.150);
    expect(preferences.getDouble(PreferenceKeys.captureMaximumWeight), 0.250);
    expect(preferences.getString(PreferenceKeys.captureRangeUnit), 'kg');
    await repository.saveCaptureMode('keyboardF12');
    expect(preferences.getString(PreferenceKeys.captureMode), 'keyboardF12');
    expect(preferences.getString(PreferenceKeys.recipe), r'\d+[.,]\d+');
    expect(preferences.getString(PreferenceKeys.expectedValue), '0.130');
    expect(preferences.getString(PreferenceKeys.themeMode), 'light');
    expect(
      preferences.getString(PreferenceKeys.demoStartedAt),
      DateTime(2026, 7, 1, 12).toIso8601String(),
    );
    expect(
      preferences.getString(PreferenceKeys.demoLastRun),
      DateTime(2026, 7, 2, 8).toIso8601String(),
    );
  });

  test('restablece el estado de demo', () async {
    SharedPreferences.setMockInitialValues({
      PreferenceKeys.demoLocked: true,
      PreferenceKeys.demoStartedAt: DateTime(2026, 7, 1, 12).toIso8601String(),
      PreferenceKeys.demoLastRun: DateTime(2026, 7, 2, 8).toIso8601String(),
    });
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences);

    await repository.resetDemo();

    expect(preferences.getBool(PreferenceKeys.demoLocked), isNull);
    expect(preferences.getString(PreferenceKeys.demoStartedAt), isNull);
    expect(preferences.getString(PreferenceKeys.demoLastRun), isNull);
  });

  test('elimina patrón y valor esperado de la receta', () async {
    SharedPreferences.setMockInitialValues({
      PreferenceKeys.recipe: r'([0-9]+)',
      PreferenceKeys.expectedValue: '0.16',
    });
    final preferences = await SharedPreferences.getInstance();

    await SettingsRepository(preferences).clearRecipe();

    expect(preferences.getString(PreferenceKeys.recipe), isNull);
    expect(preferences.getString(PreferenceKeys.expectedValue), isNull);
  });

  test('conserva y actualiza la receta entre reinicios sin red', () async {
    final preferences = await SharedPreferences.getInstance();
    await SettingsRepository(
      preferences,
    ).saveRecipe(pattern: r'([0-9]+)', expectedValue: '16');
    await SettingsRepository(
      preferences,
    ).saveRecipe(pattern: r'([0-9]+[.,][0-9]+)', expectedValue: '0.16');

    final reloaded = SettingsRepository(preferences).load();

    expect(reloaded.recipePattern, r'([0-9]+[.,][0-9]+)');
    expect(reloaded.expectedValue, '0.16');
  });

  test('guarda fechas online sin modificar la demo local', () async {
    final localStartedAt = DateTime(2026, 8, 1, 12);
    SharedPreferences.setMockInitialValues({
      PreferenceKeys.demoStartedAt: localStartedAt.toIso8601String(),
    });
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences);

    await repository.saveRecipeAccessDates(
      trialStartedAt: DateTime.parse('2026-08-11T17:00:00-05:00'),
      trialExpiresAt: DateTime.parse('2026-08-26T17:00:00-05:00'),
    );

    expect(
      preferences.getString(PreferenceKeys.recipeAccessTrialStartedAt),
      '2026-08-11T22:00:00.000Z',
    );
    expect(
      preferences.getString(PreferenceKeys.recipeAccessTrialExpiresAt),
      '2026-08-26T22:00:00.000Z',
    );
    expect(
      preferences.getString(PreferenceKeys.demoStartedAt),
      localStartedAt.toIso8601String(),
    );
  });
}
