import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/offline_recipe_request.dart';

class RecipeStateRepository {
  const RecipeStateRepository(this._preferences);
  final SharedPreferences _preferences;
  static const storageKey = 'pondera_protected_recipe_state_v1';

  Map<String, dynamic> load() {
    final source = _preferences.getString(storageKey);
    if (source == null) return {'pending': null, 'active': null};
    final state = RecipeProtocol.object(source);
    RecipeProtocol.fields(state, const {'pending', 'active'});
    for (final value in state.values) {
      if (value != null && value is! Map<String, dynamic>) {
        throw const FormatException('El estado de la receta está dañado.');
      }
    }
    return state;
  }

  Future<void> save(Map<String, dynamic> state) async {
    final encoded = jsonEncode(state);
    if (!await _preferences.setString(storageKey, encoded)) {
      throw StateError('No se pudo guardar la receta protegida.');
    }
  }

  Future<void> clear() async {
    if (!await _preferences.remove(storageKey)) {
      throw StateError('No se pudo eliminar la receta protegida.');
    }
  }
}
