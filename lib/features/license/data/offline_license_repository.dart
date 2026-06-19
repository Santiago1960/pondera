import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/preference_keys.dart';

class OfflineLicenseRepository {
  const OfflineLicenseRepository(this._preferences);

  final SharedPreferences _preferences;

  static Future<OfflineLicenseRepository> create() async {
    return OfflineLicenseRepository(await SharedPreferences.getInstance());
  }

  String? load() => _preferences.getString(PreferenceKeys.signedLicense);

  Future<void> save(String encodedLicense) async {
    await _preferences.setString(PreferenceKeys.signedLicense, encodedLicense);
  }

  DateTime? loadLastValidation() {
    final source = _preferences.getString(
      PreferenceKeys.offlineLicenseLastValidation,
    );
    if (source == null) {
      return null;
    }
    final value = DateTime.tryParse(source);
    if (value == null) {
      throw const FormatException(
        'La fecha de validación almacenada no es válida.',
      );
    }
    return value.toUtc();
  }

  Future<void> saveLastValidation(DateTime value) async {
    await _preferences.setString(
      PreferenceKeys.offlineLicenseLastValidation,
      value.toUtc().toIso8601String(),
    );
  }

  Future<void> clear() async {
    await _preferences.remove(PreferenceKeys.signedLicense);
    await _preferences.remove(PreferenceKeys.offlineLicenseLastValidation);
  }
}
