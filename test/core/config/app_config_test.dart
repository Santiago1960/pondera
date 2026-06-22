import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/core/config/app_config.dart';

void main() {
  test('n8n permite esperar respuestas de modelos de IA', () {
    expect(AppConfig.n8nRequestTimeout, const Duration(seconds: 45));
  });

  test('limita el acumulador para evitar crecimiento indefinido', () {
    expect(AppConfig.maxScaleAccumulatorCharacters, 8192);
  });
}
