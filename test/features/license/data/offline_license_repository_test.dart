import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/core/constants/preference_keys.dart';
import 'package:pondera/features/license/data/offline_license_file_store.dart';
import 'package:pondera/features/license/data/offline_license_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'migra la licencia anterior y elimina la copia de preferencias',
    () async {
      SharedPreferences.setMockInitialValues({
        PreferenceKeys.signedLicense: 'LICENCIA-ANTERIOR',
      });
      final preferences = await SharedPreferences.getInstance();
      final store = _MemoryLicenseFileStore();
      final repository = OfflineLicenseRepository(store, preferences);

      expect(await repository.load(), 'LICENCIA-ANTERIOR');
      expect(await store.read(), 'LICENCIA-ANTERIOR');
      expect(preferences.getString(PreferenceKeys.signedLicense), isNull);
    },
  );

  test('no elimina la licencia anterior si falla la escritura nueva', () async {
    SharedPreferences.setMockInitialValues({
      PreferenceKeys.signedLicense: 'LICENCIA-ANTERIOR',
    });
    final preferences = await SharedPreferences.getInstance();
    final store = _MemoryLicenseFileStore()..discardWrites = true;
    final repository = OfflineLicenseRepository(store, preferences);

    await expectLater(repository.load(), throwsStateError);
    expect(
      preferences.getString(PreferenceKeys.signedLicense),
      'LICENCIA-ANTERIOR',
    );
  });

  test('calcula el hash de los bytes exactos de la licencia', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = _MemoryLicenseFileStore()..value = 'LICENCIA-1';
    final repository = OfflineLicenseRepository(store, preferences);

    expect(
      await repository.loadSha256(),
      'sha256:ddeffd686db09d20888fa89be192658415031e48fa604d1c4d76415badf5073a',
    );
  });

  test('reemplaza el archivo de licencia y limpia temporales', () async {
    final directory = await Directory.systemTemp.createTemp(
      'pondera-license-store-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final licenseFile = File('${directory.path}/active.pondera-license');
    final store = ApplicationSupportLicenseFileStore(licenseFile);

    await store.write('LICENCIA-1');
    await store.write('LICENCIA-2');

    expect(await store.read(), 'LICENCIA-2');
    expect(await File('${licenseFile.path}.tmp').exists(), isFalse);
    expect(await File('${licenseFile.path}.bak').exists(), isFalse);
  });

  test('recupera el respaldo si falta el archivo principal', () async {
    final directory = await Directory.systemTemp.createTemp(
      'pondera-license-store-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final licenseFile = File('${directory.path}/active.pondera-license');
    await File('${licenseFile.path}.bak').writeAsString('LICENCIA-RESPALDO');
    final store = ApplicationSupportLicenseFileStore(licenseFile);

    expect(await store.read(), 'LICENCIA-RESPALDO');
    expect(await licenseFile.exists(), isTrue);
  });
}

class _MemoryLicenseFileStore implements OfflineLicenseFileStore {
  String? value;
  bool discardWrites = false;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    if (!discardWrites) {
      this.value = value;
    }
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}
