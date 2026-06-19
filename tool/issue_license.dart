import 'dart:io';

import 'package:pondera/features/license/domain/license_activation_request.dart';

import 'src/license_signing_key.dart';
import 'src/offline_license_issuer.dart';

Future<void> main(List<String> arguments) async {
  try {
    final options = _IssueOptions.parse(arguments);
    final requestFile = File(options.requestPath);
    final keyFile = File(options.keyPath);
    final request = LicenseActivationRequest.decode(
      await requestFile.readAsString(),
    );
    final signingKey = LicenseSigningKey.decode(await keyFile.readAsString());
    final expiresAt = _parseExpirationDate(options.expiresOn);

    stdout.writeln('Solicitud: ${request.requestId}');
    stdout.writeln('Cliente: ${request.customerName} (${options.customerId})');
    stdout.writeln('Sucursal: ${request.siteName} (${options.siteId})');
    stdout.writeln('Equipo: ${request.deviceLabel}');
    stdout.writeln('Instalación: ${request.installationId}');
    stdout.writeln('Vencimiento: ${options.expiresOn}');
    stdout.writeln('Gracia: ${options.graceDays} días');
    stdout.writeln('Clave: ${signingKey.keyId}');

    if (!options.confirmed && !_confirmIssuance()) {
      stdout.writeln('Emisión cancelada.');
      return;
    }

    final license = await OfflineLicenseIssuer().issue(
      request: request,
      signingKey: signingKey,
      licenseId: options.licenseId,
      customerId: options.customerId,
      siteId: options.siteId,
      expiresAt: expiresAt,
      graceDays: options.graceDays,
    );
    final outputPath =
        options.outputPath ?? _defaultOutputPath(requestFile.path);
    await File(outputPath).writeAsString(license.encode(), flush: true);
    stdout.writeln('Licencia creada: $outputPath');
  } on _UsageException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln(_usage);
    exitCode = 64;
  } on Object catch (error) {
    stderr.writeln('No se pudo emitir la licencia: $error');
    exitCode = 1;
  }
}

bool _confirmIssuance() {
  stdout.write('¿Emitir esta licencia? [s/N]: ');
  final answer = stdin.readLineSync()?.trim().toLowerCase();
  return answer == 's' || answer == 'si' || answer == 'sí';
}

DateTime _parseExpirationDate(String source) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(source);
  if (match == null) {
    throw const FormatException('La fecha debe tener formato YYYY-MM-DD.');
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final value = DateTime.utc(year, month, day, 23, 59, 59);
  if (value.year != year || value.month != month || value.day != day) {
    throw const FormatException('La fecha de vencimiento no existe.');
  }
  return value;
}

String _defaultOutputPath(String requestPath) {
  const extension = '.pondera-request';
  if (requestPath.endsWith(extension)) {
    return '${requestPath.substring(0, requestPath.length - extension.length)}.pondera-license';
  }
  return '$requestPath.pondera-license';
}

class _IssueOptions {
  const _IssueOptions({
    required this.requestPath,
    required this.keyPath,
    required this.licenseId,
    required this.customerId,
    required this.siteId,
    required this.expiresOn,
    required this.graceDays,
    required this.confirmed,
    this.outputPath,
  });

  final String requestPath;
  final String keyPath;
  final String licenseId;
  final String customerId;
  final String siteId;
  final String expiresOn;
  final int graceDays;
  final bool confirmed;
  final String? outputPath;

  factory _IssueOptions.parse(List<String> arguments) {
    if (arguments.isEmpty || arguments.contains('--help')) {
      throw const _UsageException('Faltan los datos de emisión.');
    }

    final values = <String, String>{};
    var confirmed = false;
    for (var index = 0; index < arguments.length; index++) {
      final argument = arguments[index];
      if (argument == '--yes') {
        confirmed = true;
        continue;
      }
      if (!argument.startsWith('--')) {
        throw _UsageException('Argumento no reconocido: $argument');
      }
      if (index + 1 >= arguments.length ||
          arguments[index + 1].startsWith('--')) {
        throw _UsageException('Falta el valor de $argument.');
      }
      values[argument] = arguments[++index];
    }

    String requiredOption(String name) {
      final value = values[name]?.trim();
      if (value == null || value.isEmpty) {
        throw _UsageException('Falta la opción obligatoria $name.');
      }
      return value;
    }

    final graceDaysSource = values['--grace-days'] ?? '15';
    final graceDays = int.tryParse(graceDaysSource);
    if (graceDays == null || graceDays < 0) {
      throw const _UsageException(
        '--grace-days debe ser un entero no negativo.',
      );
    }

    return _IssueOptions(
      requestPath: requiredOption('--request'),
      keyPath: requiredOption('--key'),
      licenseId: requiredOption('--license-id'),
      customerId: requiredOption('--customer-id'),
      siteId: requiredOption('--site-id'),
      expiresOn: requiredOption('--expires'),
      graceDays: graceDays,
      confirmed: confirmed,
      outputPath: values['--output']?.trim(),
    );
  }
}

class _UsageException implements Exception {
  const _UsageException(this.message);

  final String message;
}

const _usage = '''
Uso:
  dart run tool/issue_license.dart \\
    --request <solicitud.pondera-request> \\
    --key <clave.pondera-private-key> \\
    --license-id <LIC-...> \\
    --customer-id <CLI-...> \\
    --site-id <SITE-...> \\
    --expires <YYYY-MM-DD> \\
    [--grace-days <días>] \\
    [--output <salida.pondera-license>] \\
    [--yes]
''';
