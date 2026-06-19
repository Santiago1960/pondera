import 'dart:io';

abstract interface class OfflineLicenseFileStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

class ApplicationSupportLicenseFileStore implements OfflineLicenseFileStore {
  const ApplicationSupportLicenseFileStore(this._file);

  final File _file;

  File get _temporaryFile => File('${_file.path}.tmp');
  File get _backupFile => File('${_file.path}.bak');

  @override
  Future<String?> read() async {
    if (!await _file.exists()) {
      if (!await _backupFile.exists()) {
        return null;
      }
      await _backupFile.rename(_file.path);
    }
    return _file.readAsString();
  }

  @override
  Future<void> write(String value) async {
    await _file.parent.create(recursive: true);
    if (await _temporaryFile.exists()) {
      await _temporaryFile.delete();
    }
    await _temporaryFile.writeAsString(value, flush: true);

    if (await _backupFile.exists()) {
      await _backupFile.delete();
    }
    if (await _file.exists()) {
      await _file.rename(_backupFile.path);
    }

    try {
      await _temporaryFile.rename(_file.path);
    } on Object {
      if (!await _file.exists() && await _backupFile.exists()) {
        await _backupFile.rename(_file.path);
      }
      rethrow;
    }

    if (await _backupFile.exists()) {
      await _backupFile.delete();
    }
  }

  @override
  Future<void> delete() async {
    for (final file in [_file, _temporaryFile, _backupFile]) {
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}
