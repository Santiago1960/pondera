import 'dart:math';

class LicenseIdentifierGenerator {
  LicenseIdentifierGenerator({Random? random})
    : _random = random ?? Random.secure();

  final Random _random;

  String createInstallationId() => 'INSTALL-${_uuid()}';

  String createRecipeAccessRequestId() => 'RAC-${_uuid()}';

  String createRequestId() => 'REQ-${_uuid()}';

  String _uuid() {
    final bytes = _bytes(16);
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  List<int> _bytes(int length) {
    return List<int>.generate(length, (_) => _random.nextInt(256));
  }
}
