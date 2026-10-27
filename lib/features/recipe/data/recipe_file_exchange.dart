import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import '../domain/offline_recipe_request.dart';

class RecipeFileExchange {
  const RecipeFileExchange();

  Future<String?> exportRequest(OfflineRecipeRequest request) async {
    final name = '${request.requestId}.bitgenial-recipe-request';
    final location = await getSaveLocation(suggestedName: name);
    if (location == null) return null;
    await XFile.fromData(
      Uint8List.fromList(utf8.encode(request.encode())),
      mimeType: 'application/json',
      name: name,
    ).saveTo(location.path);
    return location.path;
  }

  Future<String?> importResponse() async {
    const typeGroup = XTypeGroup(
      label: 'Receta autorizada de Bitgenial',
      extensions: ['bitgenial-recipe'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return null;
    if (await file.length() > RecipeProtocol.maxFileBytes) {
      throw const FormatException('El archivo de receta es demasiado grande.');
    }
    final content = await file.readAsBytes();
    if (content.length > RecipeProtocol.maxFileBytes) {
      throw const FormatException('El archivo de receta es demasiado grande.');
    }
    return utf8.decode(content);
  }
}
