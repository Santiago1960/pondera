import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/preference_keys.dart';
import '../domain/app_settings.dart';

class SettingsRepository {
  const SettingsRepository(this._preferences);

  static Future<SettingsRepository> create() async {
    return SettingsRepository(await SharedPreferences.getInstance());
  }

  final SharedPreferences _preferences;

  bool get isDemoLocked =>
      _preferences.getBool(PreferenceKeys.demoLocked) ?? false;

  String? get demoLastRun => _preferences.getString(PreferenceKeys.demoLastRun);

  AppSettings load() {
    return AppSettings(
      connectionType:
          _preferences.getString(PreferenceKeys.connectionType) ?? 'ethernet',
      deviceIp: _preferences.getString(PreferenceKeys.ip) ?? '192.168.100.134',
      devicePort: _preferences.getInt(PreferenceKeys.port) ?? 3004,
      serialPortName: _preferences.getString(PreferenceKeys.serialPort) ?? '',
      serialBaudRate:
          _preferences.getInt(PreferenceKeys.serialBaudRate) ?? 9600,
      serialDataBits: _preferences.getInt(PreferenceKeys.serialDataBits) ?? 8,
      serialStopBits: _preferences.getInt(PreferenceKeys.serialStopBits) ?? 1,
      serialParity:
          _preferences.getString(PreferenceKeys.serialParity) ?? 'none',
      serialFlowControl:
          _preferences.getString(PreferenceKeys.serialFlowControl) ?? 'none',
      recipePattern: _preferences.getString(PreferenceKeys.recipe) ?? '',
      expectedValue:
          _preferences.getString(PreferenceKeys.expectedValue)?.trim() ?? '',
      keyboardPrefix: _preferences.getString(PreferenceKeys.prefix) ?? '',
      keyboardSuffix: _preferences.getString(PreferenceKeys.suffix) ?? '',
      inputUnit: _preferences.getString(PreferenceKeys.inputUnit) ?? 'kg',
      outputUnit: _preferences.getString(PreferenceKeys.outputUnit) ?? 'kg',
    );
  }

  Future<void> saveConnectionType(String connectionType) async {
    await _preferences.setString(PreferenceKeys.connectionType, connectionType);
  }

  Future<void> saveNetwork({required String ip, required int port}) async {
    await _preferences.setString(PreferenceKeys.ip, ip);
    await _preferences.setInt(PreferenceKeys.port, port);
  }

  Future<void> saveSerial({
    required String portName,
    required int baudRate,
    required int dataBits,
    required int stopBits,
    required String parity,
    required String flowControl,
  }) async {
    await _preferences.setString(PreferenceKeys.serialPort, portName);
    await _preferences.setInt(PreferenceKeys.serialBaudRate, baudRate);
    await _preferences.setInt(PreferenceKeys.serialDataBits, dataBits);
    await _preferences.setInt(PreferenceKeys.serialStopBits, stopBits);
    await _preferences.setString(PreferenceKeys.serialParity, parity);
    await _preferences.setString(PreferenceKeys.serialFlowControl, flowControl);
  }

  Future<void> saveKeyboardCommands({
    required String prefix,
    required String suffix,
  }) async {
    await _preferences.setString(PreferenceKeys.prefix, prefix);
    await _preferences.setString(PreferenceKeys.suffix, suffix);
  }

  Future<void> saveUnits({
    required String inputUnit,
    required String outputUnit,
  }) async {
    await _preferences.setString(PreferenceKeys.inputUnit, inputUnit);
    await _preferences.setString(PreferenceKeys.outputUnit, outputUnit);
  }

  Future<void> saveRecipe({
    required String pattern,
    required String expectedValue,
  }) async {
    await _preferences.setString(PreferenceKeys.recipe, pattern);
    await _preferences.setString(PreferenceKeys.expectedValue, expectedValue);
  }

  Future<void> clearRecipe() async {
    await _preferences.remove(PreferenceKeys.recipe);
  }

  Future<void> lockDemo() async {
    await _preferences.setBool(PreferenceKeys.demoLocked, true);
  }

  Future<void> saveDemoLastRun(DateTime value) async {
    await _preferences.setString(
      PreferenceKeys.demoLastRun,
      value.toIso8601String(),
    );
  }

  Future<void> resetDemo() async {
    await _preferences.remove(PreferenceKeys.demoLocked);
    await _preferences.remove(PreferenceKeys.demoLastRun);
  }
}
