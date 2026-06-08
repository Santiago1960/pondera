import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pondera Piloto',
      theme: ThemeData(brightness: Brightness.dark, primarySwatch: Colors.blue),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // Configuración de red del indicador GI-410
  final String _ipAddress = '192.168.100.134';
  final int _port = 3004;

  // URL del Webhook de test en n8n
  final String _n8nUrl =
      'https://n8n.bitgenial.com/webhook-test/pondera-recipe';
  final String _expectedValue = '0.130';

  Socket? _socket;
  StreamSubscription<List<int>>? _socketSubscription;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  bool _isReconnecting = false;
  bool _manualDisconnect = false;
  bool _macOsAutomationBlocked = false;
  int _reconnectAttempt = 0;
  String _statusMessage = 'Desconectado';

  // Control de tiempo para evitar dobles ejecuciones accidentales
  DateTime? _lastTypedTime;

  // Lista para acumular las últimas tramas de texto recibidas
  final List<String> _receivedDataLog = [];

  // Variables para persistencia y limpieza de tramas
  String _savedRegex = '';
  String _cleanWeightDisplay = 'Sin receta';
  late SharedPreferences _prefs;

  // Controladores para los prefijos y sufijos de teclado
  final TextEditingController _prefixController = TextEditingController();
  final TextEditingController _suffixController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initSharedPreferences();
  }

  @override
  void dispose() {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _socketSubscription?.cancel();
    _socket?.destroy();
    _prefixController.dispose();
    _suffixController.dispose();
    super.dispose();
  }

  // Inicializa el almacenamiento local de la Mac y recupera los comandos
  void _initSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedRegex = _prefs.getString('pondera_recipe') ?? '';
      _prefixController.text = _prefs.getString('pondera_prefix') ?? '';
      _suffixController.text = _prefs.getString('pondera_suffix') ?? '';
      if (_savedRegex.isNotEmpty) {
        _cleanWeightDisplay = '---';
      }
    });
  }

  // Guarda los prefijos y sufijos manualmente (Aislado de eventos reactivos)
  void _saveKeyModifiers() async {
    await _prefs.setString('pondera_prefix', _prefixController.text);
    await _prefs.setString('pondera_suffix', _suffixController.text);
    
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comandos de teclado guardados'),
          duration: Duration(milliseconds: 800), // Duración muy corta para no bloquear
        ),
      );
    }
  }

  // Envía la última trama capturada a tu servidor n8n
  void _sendToN8nIa() async {
    if (_receivedDataLog.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero captura al menos una trama en bruto del indicador.'),
        ),
      );
      return;
    }

    String rawData = _receivedDataLog.last;

    setState(() {
      _statusMessage = 'Enviando muestra a n8n...';
    });

    try {
      final response = await http.post(
        Uri.parse(_n8nUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'trama': rawData, 'valor_esperado': _expectedValue}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        String newRegex = responseData['regex_pattern'] ?? '';

        if (newRegex.isNotEmpty) {
          await _prefs.setString('pondera_recipe', newRegex);

          setState(() {
            _savedRegex = newRegex;
            _statusMessage = '¡Receta Regex guardada con éxito!';

            final regExp = RegExp(_savedRegex);
            final match = regExp.firstMatch(rawData);
            if (match != null) {
              _cleanWeightDisplay = _formatWeightForOutput(match.group(0));
            } else {
              _cleanWeightDisplay = '---';
            }
          });
        } else {
          setState(() {
            _statusMessage = 'n8n respondió pero no envió la llave regex_pattern';
          });
        }
      } else {
        setState(() {
          _statusMessage = 'Error en n8n. Estado: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error de conexión con n8n: $e';
      });
    }
  }

  // Borra la receta de la memoria local
  void _clearRecipe() async {
    await _prefs.remove('pondera_recipe');
    setState(() {
      _savedRegex = '';
      _cleanWeightDisplay = 'Sin receta';
      _statusMessage = 'Receta eliminada.';
    });
  }

  String _appleScriptStringLiteral(String value) {
    return '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
  }

  String? _decimalSeparatorFor(String value) {
    final dotIndex = value.lastIndexOf('.');
    final commaIndex = value.lastIndexOf(',');

    if (dotIndex == -1 && commaIndex == -1) {
      return null;
    }

    return dotIndex > commaIndex ? '.' : ',';
  }

  String _formatWeightForOutput(String? rawWeight) {
    final value = rawWeight?.trim() ?? '';
    if (value.isEmpty || value == '---') {
      return '---';
    }

    final expectedDecimalSeparator = _decimalSeparatorFor(_expectedValue);
    if (expectedDecimalSeparator == null) {
      return value;
    }

    final dotIndex = value.lastIndexOf('.');
    final commaIndex = value.lastIndexOf(',');
    if (dotIndex == -1 && commaIndex == -1) {
      return value;
    }

    final sourceDecimalSeparator = dotIndex > commaIndex ? '.' : ',';
    final thousandsSeparator = sourceDecimalSeparator == '.' ? ',' : '.';

    return value
        .replaceAll(thousandsSeparator, '')
        .replaceAll(sourceDecimalSeparator, expectedDecimalSeparator);
  }

  // Traduce bloques especiales como {TAB} o {ENTER} a comandos nativos de AppleScript
  String _parseKeysToAppleScript(String input) {
    if (input.isEmpty) return '';
    
    final StringBuffer scriptBuffer = StringBuffer();
    final RegExp keyRegex = RegExp(r'(\{ENTER\}|\{TAB\}|\{SPACE\}|[^{]+)');
    final matches = keyRegex.allMatches(input);

    for (final match in matches) {
      final token = match.group(0) ?? '';
      if (token == '{TAB}') {
        scriptBuffer.writeln('  key code 48');
      } else if (token == '{ENTER}') {
        scriptBuffer.writeln('  key code 36');
      } else if (token == '{SPACE}') {
        scriptBuffer.writeln('  key code 49');
      } else {
        scriptBuffer.writeln('  keystroke ${_appleScriptStringLiteral(token)}');
      }
    }
    return scriptBuffer.toString();
  }

  // Pega el peso en la app que tenga el foco usando la automatización de macOS.
  Future<void> _writeWeightToCursor([String? weight]) async {
    final weightToType = (weight ?? _cleanWeightDisplay).trim();

    if (weightToType.isEmpty ||
        weightToType == '---' ||
        weightToType == 'Sin receta') {
      return;
    }

    if (!Platform.isMacOS) {
      return;
    }

    final now = DateTime.now();
    if (_lastTypedTime != null &&
        now.difference(_lastTypedTime!) < const Duration(milliseconds: 1500)) {
      return;
    }
    _lastTypedTime = now;

    // CAPA DE SEGURIDAD CRÍTICA: Quitamos el foco de cualquier campo de la app de Flutter
    // para que la inyección de teclas nativas no altere el estado interno si la app está al frente.
    if (mounted) {
      FocusScope.of(context).unfocus();
    }

    // Capturamos el texto de los modificadores en variables locales estables antes del hilo asíncrono
    final String currentPrefix = _prefixController.text;
    final String currentSuffix = _suffixController.text;

    try {
      // 1. Intento de copia al portapapeles
      final copyResult = await Process.run('osascript', [
        '-e',
        'set the clipboard to ${_appleScriptStringLiteral(weightToType)}',
      ]).timeout(const Duration(seconds: 1));

      if (copyResult.exitCode != 0) {
        final copyError = copyResult.stderr.toString().trim();
        debugPrint('Error copiando peso al portapapeles: $copyError');
        if (mounted) {
          setState(() {
            _statusMessage = 'Error de portapapeles: $copyError';
          });
        }
        return; 
      }

      debugPrint('Peso copiado al portapapeles: $weightToType');

      if (_macOsAutomationBlocked) {
        return;
      }

      // 2. Traducción y construcción dinámica del flujo completo de pulsaciones
      final String prefixScript = _parseKeysToAppleScript(currentPrefix);
      final String suffixScript = _parseKeysToAppleScript(currentSuffix);

      final script = '''
delay 0.15
tell application "System Events"
$prefixScript
  keystroke "v" using {command down}
$suffixScript
end tell
''';

      final result = await Process.run('osascript', ['-e', script])
          .timeout(const Duration(seconds: 1));

      final stderr = result.stderr.toString().trim();

      if (result.exitCode == 0) {
        debugPrint('Peso pegado en macOS: $weightToType');
        if (mounted) {
          setState(() {
            _statusMessage = 'Peso escrito: $weightToType';
          });
        }
        return;
      }

      final message = stderr.isEmpty ? 'Código ${result.exitCode}' : stderr;
      final isPrivilegeError =
          message.contains('-10004') ||
          message.toLowerCase().contains('privilegios') ||
          message.toLowerCase().contains('not allowed assistive access');

      debugPrint('Error de inyección en macOS: $message');
      if (mounted) {
        setState(() {
          if (isPrivilegeError) {
            _macOsAutomationBlocked = true;
            _statusMessage =
                'Permiso macOS requerido: habilita Accesibilidad para Pondera y reinicia la app.';
          } else {
            _statusMessage = 'No se pudo escribir el peso: $message';
          }
        });
      }
    } on TimeoutException {
      debugPrint('Timeout en osascript: macOS tardó demasiado en responder.');
      if (mounted) {
        setState(() {
          _statusMessage = 'Error: Tiempo de espera agotado en automatización Mac';
        });
      }
    } catch (e) {
      debugPrint('Error ejecutando osascript: $e');
      if (mounted) {
        setState(() {
          _statusMessage = 'No se pudo ejecutar osascript: $e';
        });
      }
    }
  }

  // Procesamiento directo optimizado para tramas estables únicas
  void _processIncomingData(List<int> data) {
    try {
      String incomingText = utf8.decode(data, allowMalformed: true).trim();
      if (incomingText.isEmpty) return;

      String? weightToWrite;

      setState(() {
        _receivedDataLog.add(incomingText);
        if (_receivedDataLog.length > 15) {
          _receivedDataLog.removeAt(0);
        }

        if (_savedRegex.isNotEmpty) {
          final regExp = RegExp(_savedRegex);
          final match = regExp.firstMatch(incomingText);

          if (match != null) {
            _cleanWeightDisplay = _formatWeightForOutput(match.group(0));
            weightToWrite = _cleanWeightDisplay;
            _statusMessage = 'Peso recibido: $_cleanWeightDisplay';
          } else {
            _statusMessage = 'Trama recibida sin coincidencia Regex';
          }
        } else {
          _cleanWeightDisplay = 'Sin receta';
        }
      });

      if (weightToWrite != null) {
        _writeWeightToCursor(weightToWrite);
      }
    } catch (e) {
      debugPrint('Error al decodificar: $e');
    }
  }

  void _scheduleReconnect(String reason, {int? delaySeconds}) {
    if (_manualDisconnect || !mounted) return;
    if (_reconnectTimer?.isActive ?? false) return;

    _socketSubscription?.cancel();
    _socketSubscription = null;
    _socket?.destroy();
    _socket = null;

    _reconnectAttempt += 1;
    final reconnectDelaySeconds =
        delaySeconds ?? (_reconnectAttempt < 4 ? 2 : 5);

    setState(() {
      _isConnected = false;
      _isReconnecting = true;
      _statusMessage = '$reason. Reintentando en ${reconnectDelaySeconds}s...';
    });

    _reconnectTimer = Timer(Duration(seconds: reconnectDelaySeconds), () {
      _connectToIndicator(isRetry: true);
    });
  }

  // Conexión TCP y escucha activa del puerto
  void _connectToIndicator({bool isRetry = false}) async {
    if (_isConnected) return;
    if (_isReconnecting && !isRetry) return;

    _manualDisconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    setState(() {
      _isReconnecting = true;
      _statusMessage = isRetry
          ? 'Reconectando a $_ipAddress:$_port...'
          : 'Conectando a $_ipAddress:$_port...';
    });

    try {
      await _socketSubscription?.cancel();
      _socketSubscription = null;
      _socket?.destroy();
      _socket = null;

      final socket = await Socket.connect(
        _ipAddress,
        _port,
        timeout: const Duration(seconds: 4),
      );

      socket.setOption(SocketOption.tcpNoDelay, true);
      try {
        socket.setRawOption(RawSocketOption.fromInt(0xFFFF, 0x0004, 1));
      } catch (e) {
        debugPrint('No se pudo activar TCP keepalive: $e');
      }

      _socket = socket;
      _reconnectAttempt = 0;

      setState(() {
        _isConnected = true;
        _isReconnecting = false;
        _statusMessage = 'Conectado. Esperando datos del indicador...';
      });

      _socketSubscription = socket.listen(
        _processIncomingData,
        onError: (error) {
          _scheduleReconnect('Error de señal: $error');
        },
        onDone: () {
          _scheduleReconnect('Puerto cerrado por el indicador');
        },
        cancelOnError: true,
      );
    } catch (e) {
      _scheduleReconnect('No se pudo conectar: $e');
    }
  }

  void _disconnect(String message) {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _socket?.destroy();
    _socket = null;
    setState(() {
      _isConnected = false;
      _isReconnecting = false;
      _statusMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pondera - Piloto de Red + n8n')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.blueGrey.shade900,
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Column(
                  children: [
                    const Text(
                      'PESO LIMPIO FILTRADO LOCALMENTE',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _cleanWeightDisplay,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.amberAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Comandos de Teclado (Ej: {TAB}, {ENTER}, {SPACE}, o texto directo)',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _prefixController,
                            onSubmitted: (_) => _saveKeyModifiers(),
                            decoration: const InputDecoration(
                              labelText: 'Prefijo (Antes del peso)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            style: const TextStyle(fontSize: 13, fontFamily: 'Courier'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _suffixController,
                            onSubmitted: (_) => _saveKeyModifiers(),
                            decoration: const InputDecoration(
                              labelText: 'Sufijo (Después del peso)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            style: const TextStyle(fontSize: 13, fontFamily: 'Courier'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: _saveKeyModifiers,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                          ),
                          child: const Icon(Icons.save, size: 18),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Column(
                  children: [
                    Text(
                      'Dispositivo: $_ipAddress:$_port',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Estado: $_statusMessage',
                      style: TextStyle(
                        color: _isConnected ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: _isConnected
                              ? () => _disconnect('Desconectado')
                              : _connectToIndicator,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isConnected
                                ? Colors.red.shade700
                                : Colors.blue.shade700,
                          ),
                          child: Text(
                            _isConnected ? 'Desconectar' : 'Conectar GI-400',
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _sendToN8nIa,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple.shade700,
                          ),
                          child: const Text('Enviar Trama a n8n'),
                        ),
                        if (_savedRegex.isNotEmpty)
                          TextButton(
                            onPressed: _clearRecipe,
                            child: const Text(
                              'Limpiar Receta',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _savedRegex.isEmpty
                  ? 'Receta Regex activa: Ninguna'
                  : 'Receta Regex activa: $_savedRegex',
              style: TextStyle(
                color: _savedRegex.isEmpty ? Colors.redAccent : Colors.greenAccent,
                fontStyle: FontStyle.italic,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              'Tramas recibidas en bruto (Data Log):',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: Colors.grey.shade800),
                ),
                child: _receivedDataLog.isEmpty
                    ? const Center(
                        child: Text('Esperando datos de la balanza...'),
                      )
                    : ListView.builder(
                        reverse: true,
                        itemCount: _receivedDataLog.length,
                        itemBuilder: (context, index) {
                          final text = _receivedDataLog[_receivedDataLog.length - 1 - index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Text(
                              text.replaceAll('\r', '\\r').replaceAll('\n', '\\n'),
                              style: const TextStyle(
                                fontFamily: 'Courier',
                                color: Colors.greenAccent,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}