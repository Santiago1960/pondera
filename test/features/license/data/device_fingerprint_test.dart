import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/features/license/data/device_fingerprint.dart';

void main() {
  test(
    'genera una huella SHA-256 estable sin exponer el identificador',
    () async {
      final first = await DeviceFingerprint.hashSystemId(
        '01234567-89ab-cdef-0123-456789abcdef',
      );
      final second = await DeviceFingerprint.hashSystemId(
        ' 01234567-89AB-CDEF-0123-456789ABCDEF ',
      );

      expect(first, second);
      expect(first, matches(RegExp(r'^sha256:[0-9a-f]{64}$')));
      expect(first, isNot(contains('01234567')));
    },
  );
}
