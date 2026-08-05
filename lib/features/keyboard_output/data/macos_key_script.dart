String buildMacosKeyScript(String input) {
  final script = StringBuffer();
  final tokens = RegExp(
    r'(\{ENTER\}|\{TAB\}|\{SPACE\}| |[^{ ]+)',
  ).allMatches(input);

  for (final match in tokens) {
    final token = match.group(0) ?? '';
    final keyCode = switch (token) {
      '{TAB}' => 48,
      '{ENTER}' => 36,
      '{SPACE}' || ' ' => 49,
      _ => null,
    };

    if (keyCode != null) {
      script.writeln('  key code $keyCode');
    } else {
      final escaped = token.replaceAll('\\', '\\\\').replaceAll('"', r'\"');
      script.writeln('  keystroke "$escaped"');
    }
    script.writeln('  delay 0.05');
  }

  return script.toString();
}
