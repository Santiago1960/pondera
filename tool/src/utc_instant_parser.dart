DateTime parseUtcInstant(String source) {
  final normalized = source.trim();
  if (!normalized.endsWith('Z')) {
    throw const FormatException(
      'El vencimiento debe indicar UTC explícitamente y terminar en Z.',
    );
  }
  final value = DateTime.tryParse(normalized);
  if (value == null || !value.isUtc) {
    throw const FormatException(
      'El vencimiento debe ser una fecha ISO 8601 UTC válida.',
    );
  }
  return value;
}
