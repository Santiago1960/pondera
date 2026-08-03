import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/license_output_path.dart';

void main() {
  test('reemplaza la extensión de una solicitud', () {
    expect(
      defaultLicenseOutputPath('customer.pondera-request'),
      'customer.pondera-license',
    );
  });

  test('agrega la extensión cuando la ruta no es una solicitud', () {
    expect(
      defaultLicenseOutputPath('customer.json'),
      'customer.json.pondera-license',
    );
  });
}
