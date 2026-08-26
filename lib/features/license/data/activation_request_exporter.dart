import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import '../domain/license_activation_request.dart';

class ActivationRequestExporter {
  const ActivationRequestExporter();

  Future<String?> export(LicenseActivationRequest request) async {
    final fileName = suggestedFileName(request);
    final location = await getSaveLocation(suggestedName: fileName);
    if (location == null) {
      return null;
    }

    final file = XFile.fromData(
      Uint8List.fromList(utf8.encode(request.encode())),
      mimeType: 'application/json',
      name: fileName,
    );
    await file.saveTo(location.path);
    return location.path;
  }

  static String suggestedFileName(LicenseActivationRequest request) {
    final components = [
      request.customerName,
      request.city,
      request.deviceLabel,
      request.requestId,
    ].map(_fileSafeComponent).where((value) => value.isNotEmpty);
    return '${components.join('-')}.bitgenial-request';
  }
}

String _fileSafeComponent(String value) {
  const replacements = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ñ': 'n',
    'Á': 'A',
    'É': 'E',
    'Í': 'I',
    'Ó': 'O',
    'Ú': 'U',
    'Ñ': 'N',
  };
  var normalized = value.trim();
  for (final replacement in replacements.entries) {
    normalized = normalized.replaceAll(replacement.key, replacement.value);
  }
  return normalized
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '')
      .replaceAll(RegExp(r'-+'), '-');
}
