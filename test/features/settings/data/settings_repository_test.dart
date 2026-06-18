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
    expect(settings.recipePattern, isEmpty);
    expect(settings.expectedValue, isEmpty);
  });

  test('carga valores persistidos', () async {
    SharedPreferences.setMockInitialValues({
      PreferenceKeys.connectionType: 'serial',
      PreferenceKeys.ip: '10.0.0.8',
      PreferenceKeys.port: 4001,
      PreferenceKeys.expectedValue: ' 0,130 ',
      PreferenceKeys.inputUnit: 'lb',
      PreferenceKeys.outputUnit: 'g',
    });
    final preferences = await SharedPreferences.getInstance();
    final settings = SettingsRepository(preferences).load();

    expect(settings.connectionType, 'serial');
    expect(settings.deviceIp, '10.0.0.8');
    expect(settings.devicePort, 4001);
    expect(settings.expectedValue, '0,130');
    expect(settings.inputUnit, 'lb');
    expect(settings.outputUnit, 'g');
  });

  test('guarda configuración y receta', () async {
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences);

    await repository.saveNetwork(ip: '10.0.0.9', port: 5000);
    await repository.saveUnits(inputUnit: 'kg', outputUnit: 'mg');
    await repository.saveRecipe(pattern: r'\d+[.,]\d+', expectedValue: '0.130');

    expect(preferences.getString(PreferenceKeys.ip), '10.0.0.9');
    expect(preferences.getInt(PreferenceKeys.port), 5000);
    expect(preferences.getString(PreferenceKeys.outputUnit), 'mg');
    expect(preferences.getString(PreferenceKeys.recipe), r'\d+[.,]\d+');
    expect(preferences.getString(PreferenceKeys.expectedValue), '0.130');
  });
}
