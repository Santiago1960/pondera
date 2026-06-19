import 'dart:io';

import 'src/signing_key_generator.dart';

Future<void> main(List<String> arguments) async {
  try {
    final options = _KeyGenerationOptions.parse(arguments);
    final privateFile = File(options.privateOutputPath);
    final publicFile = File(options.publicOutputPath);
    await SigningKeyGenerator().generate(
      keyId: options.keyId,
      privateFile: privateFile,
      publicFile: publicFile,
    );

    stdout.writeln('Par de claves creado correctamente.');
    stdout.writeln('Clave privada: ${privateFile.path}');
    stdout.writeln('Clave pública: ${publicFile.path}');
    stdout.writeln('Identificador: ${options.keyId}');
  } on _UsageException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln(_usage);
    exitCode = 64;
  } on Object catch (error) {
    stderr.writeln('No se pudo generar el par de claves: $error');
    exitCode = 1;
  }
}

class _KeyGenerationOptions {
  const _KeyGenerationOptions({
    required this.keyId,
    required this.privateOutputPath,
    required this.publicOutputPath,
  });

  final String keyId;
  final String privateOutputPath;
  final String publicOutputPath;

  factory _KeyGenerationOptions.parse(List<String> arguments) {
    if (arguments.isEmpty || arguments.contains('--help')) {
      throw const _UsageException('Faltan los datos para generar las claves.');
    }

    final values = <String, String>{};
    for (var index = 0; index < arguments.length; index++) {
      final argument = arguments[index];
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

    final keyId = requiredOption('--key-id');
    if (!RegExp(r'^pondera-prod-\d{4}-\d{2}$').hasMatch(keyId)) {
      throw const _UsageException(
        '--key-id debe usar el formato pondera-prod-YYYY-NN.',
      );
    }

    return _KeyGenerationOptions(
      keyId: keyId,
      privateOutputPath: requiredOption('--private-output'),
      publicOutputPath: requiredOption('--public-output'),
    );
  }
}

class _UsageException implements Exception {
  const _UsageException(this.message);

  final String message;
}

const _usage = '''
Uso:
  dart run tool/generate_signing_key.dart \\
    --key-id <pondera-prod-YYYY-NN> \\
    --private-output <archivo.pondera-private-key> \\
    --public-output <archivo.pondera-public-key>
''';
