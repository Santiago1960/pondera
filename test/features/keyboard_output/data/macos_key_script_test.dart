import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/features/keyboard_output/data/macos_key_script.dart';

void main() {
  test('envía espacios literales y comandos como teclas reales', () {
    final script = buildMacosKeyScript(
      'Prueba de peso manual{TAB}{ENTER}{SPACE}',
    );

    expect(RegExp(r'key code 49').allMatches(script), hasLength(4));
    expect(script, contains('key code 48'));
    expect(script, contains('key code 36'));
    expect(script, isNot(contains('keystroke "Prueba de peso manual"')));
  });
}
