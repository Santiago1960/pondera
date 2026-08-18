import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/preference_keys.dart';
import 'offline_license_file_store.dart';

class OfflineLicenseRepository {
  const OfflineLicenseRepository(this._fileStore, this._preferences);

  final OfflineLicenseFileStore _fileStore;
  final SharedPreferences _preferences;

  static Future<OfflineLicenseRepository> create() async {
    final supportDirectory = await getApplicationSupportDirectory();
    return OfflineLicenseRepository(
      ApplicationSupportLicenseFileStore(
        File(
          '${supportDirectory.path}${Platform.pathSeparator}licensing'
          '${Platform.pathSeparator}active.pondera-license',
        ),
      ),
      await SharedPreferences.getInstance(),
    );
  }

  Future<String?> load() async {
    final storedValue = await _fileStore.read();
    if (storedValue != null && storedValue.trim().isNotEmpty) {
      return storedValue;
    }

    final legacyValue = _preferences
        .getString(PreferenceKeys.signedLicense)
        ?.trim();
    if (legacyValue == null || legacyValue.isEmpty) {
      return null;
    }

    await _writeAndVerify(legacyValue);
    await _preferences.remove(PreferenceKeys.signedLicense);
    return legacyValue;
  }

  Future<String?> loadSha256() async {
    final encodedLicense = await load();
    if (encodedLicense == null) {
      return null;
    }
    final digest = await Sha256().hash(utf8.encode(encodedLicense));
    final hex = digest.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'sha256:$hex';
  }

  Future<void> save(String encodedLicense) async {
    await _writeAndVerify(encodedLicense);
    await _preferences.remove(PreferenceKeys.signedLicense);
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
    await _fileStore.delete();
    await _preferences.remove(PreferenceKeys.signedLicense);
    await _preferences.remove(PreferenceKeys.offlineLicenseLastValidation);
  }

  Future<void> _writeAndVerify(String encodedLicense) async {
    await _fileStore.write(encodedLicense);
    final persistedValue = await _fileStore.read();
    if (persistedValue != encodedLicense) {
      throw StateError('No se pudo verificar el archivo local de licencia.');
    }
  }
}
