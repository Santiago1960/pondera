import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/app/app_theme.dart';

void main() {
  test('recupera los modos de tema persistidos', () {
    expect(themeModeFromPreference('system'), ThemeMode.system);
    expect(themeModeFromPreference('light'), ThemeMode.light);
    expect(themeModeFromPreference('dark'), ThemeMode.dark);
  });

  test('usa el tema del sistema ante un valor desconocido', () {
    expect(themeModeFromPreference('desconocido'), ThemeMode.system);
  });

  test('construye temas claro y oscuro con IBM Plex Sans', () {
    final lightTheme = buildPonderaTheme(Brightness.light);
    final darkTheme = buildPonderaTheme(Brightness.dark);

    expect(lightTheme.brightness, Brightness.light);
    expect(darkTheme.brightness, Brightness.dark);
    expect(lightTheme.textTheme.bodyMedium?.fontFamily, 'IBMPlexSans');
    expect(darkTheme.textTheme.bodyMedium?.fontFamily, 'IBMPlexSans');
  });
}
