import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/features/recipe/domain/recipe_transport_policy.dart';

void main() {
  test('conserva la receta ante errores temporales del servicio', () {
    expect(isRecipeServiceUnavailableStatus(500), isTrue);
    expect(isRecipeServiceUnavailableStatus(503), isTrue);
    expect(isRecipeServiceUnavailableStatus(599), isTrue);
    expect(isRecipeServiceUnavailableStatus(429), isFalse);
    expect(recipeServiceUnavailableMessage, contains('no fue modificada'));
  });
}
