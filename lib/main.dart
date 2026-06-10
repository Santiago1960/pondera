import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

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
  final String _deviceIp = '192.168.100.134';
  final int _devicePort = 3004;

  final String _n8nUrl = 'https://n8n.bitgenial.com/webhook-test/pondera-recipe';
  final String _expectedValue = '0.130';

  Socket? _socket;
  Timer? _pollingTimer;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  bool _isTyping = false;

  int _totalPesajesExitosos = 0;
  DateTime? _lastTypedTime;
  final List<String> _receivedDataLog = [];

  String _savedRegex = '';
  String _cleanWeightDisplay = '---';
  String _uiStatusMessage = 'Desconectado';
  String _networkAccumulator = '';

  late SharedPreferences _prefs;

  final TextEditingController _prefixController = TextEditingController();
  final TextEditingController _suffixController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initSharedPreferences();
  }

  @override
  void dispose() {
    _disconnect();
    _prefixController.dispose();
    _suffixController.dispose();
    super.dispose();
  }

  void _initSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedRegex = _prefs.getString('pondera_recipe') ?? '';
      _prefixController.text = _prefs.getString('pondera_prefix') ?? '';
      _suffixController.text = _prefs.getString('pondera_suffix') ?? '';
      if (_savedRegex.isNotEmpty) {
        _cleanWeightDisplay = '---';
        _uiStatusMessage = 'Listo para conectar a la balanza.';
      } else {
        _cleanWeightDisplay = 'Sin receta';
      }
    });
  }

  void _saveKeyModifiers() async {
    await _prefs.setString('pondera_prefix', _prefixController.text);
    await _prefs.setString('pondera_suffix', _suffixController.text);
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comandos de teclado guardados'), duration: Duration(milliseconds: 800)),
      );
    }
  }

  void _sendToN8nIa() async {
    if (_receivedDataLog.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Primero captura una trama.')));
      return;
    }
    String rawData = _receivedDataLog.last;
    
    if (mounted) {
      setState(() { _uiStatusMessage = 'Enviando muestra a n8n...'; });
    }

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
          if (mounted) {
            setState(() {
              _savedRegex = newRegex;
              _uiStatusMessage = '¡Receta Regex guardada con éxito!';
              final regExp = RegExp(_savedRegex);
              final match = regExp.firstMatch(rawData);
              if (match != null) {
                _cleanWeightDisplay = _formatWeightForOutput(match.group(0));
              }
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error de conexión con n8n: $e');
    }
  }

  void _clearRecipe() async {
    await _prefs.remove('pondera_recipe');
    setState(() {
      _savedRegex = '';
      _cleanWeightDisplay = 'Sin receta';
      _uiStatusMessage = 'Receta eliminada.';
    });
  }

  String _appleScriptStringLiteral(String value) {
    return '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
  }

  String _powershellStringLiteral(String value) {
    return value.replaceAll('`', '``').replaceAll('"', '`"').replaceAll('\$', '`\$');
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
    return value.replaceAll(thousandsSeparator, '').replaceAll(sourceDecimalSeparator, expectedDecimalSeparator);
  }

  String _parseKeysToAppleScript(String input) {
    if (input.isEmpty) {
      return '';
    }
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

  String _parseKeysToWindowsSendKeys(String input) {
    if (input.isEmpty) {
      return '';
    }
    final StringBuffer buffer = StringBuffer();
    final RegExp keyRegex = RegExp(r'(\{ENTER\}|\{TAB\}|\{SPACE\}|[^{]+)');
    final matches = keyRegex.allMatches(input);
    for (final match in matches) {
      final token = match.group(0) ?? '';
      if (token == '{TAB}') {
        buffer.write('{TAB}');
      } else if (token == '{ENTER}') {
        buffer.write('{ENTER}');
      } else if (token == '{SPACE}') {
        buffer.write(' ');
      } else {
        buffer.write(token.replaceAll('~', '{~}').replaceAll('+', '{+}').replaceAll('^', '{^}').replaceAll('%', '{%}').replaceAll('(', '{(}').replaceAll(')', '{(}'));
      }
    }
    return buffer.toString();
  }

  String _getCurrentTimestamp() {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute:$second';
  }

  Future<void> _writeWeightToCursor(String weightToType) async {
    final String timestampCurrent = _getCurrentTimestamp();
    
    final String currentPrefix = _prefixController.text.replaceAll('{AHORA}', timestampCurrent); 
    final String currentSuffix = _suffixController.text.replaceAll('{AHORA}', timestampCurrent); 

    if (Platform.isMacOS) {
      try {
        await Clipboard.setData(ClipboardData(text: weightToType));
        final String prefixScript = _parseKeysToAppleScript(currentPrefix);
        final String suffixScript = _parseKeysToAppleScript(currentSuffix);
        final script = '''
delay 0.01
tell application "System Events"
$prefixScript
  keystroke "v" using {command down}
$suffixScript
end tell
''';
        await Process.run('osascript', ['-e', script]).timeout(const Duration(seconds: 2));
      } catch (e) {
        debugPrint('Error en Mac keystroke: $e');
      }
    }

    if (Platform.isWindows) {
      try {
        final escapedWeight = _powershellStringLiteral(weightToType);
        final winPrefix = _parseKeysToWindowsSendKeys(currentPrefix);
        final winSuffix = _parseKeysToWindowsSendKeys(currentSuffix);
        final escapedSequence = _powershellStringLiteral('$winPrefix^v$winSuffix');
        final psScript = '''
Add-Type -AssemblyName System.Windows.Forms;
Set-Clipboard -Value "$escapedWeight";
Start-Sleep -Milliseconds 50;
[System.Windows.Forms.SendKeys]::SendWait("$escapedSequence");
''';
        await Process.run('powershell', ['-Command', psScript]).timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('Error en Windows SendKeys: $e');
      }
    }
  }

  void _connect() async {
    _reconnectTimer?.cancel();
    if (_isConnected) {
      return;
    }

    if (mounted) {
      setState(() { _uiStatusMessage = 'Conectando a $_deviceIp:$_devicePort...'; });
    }

    try {
      _socket = await Socket.connect(_deviceIp, _devicePort, timeout: const Duration(seconds: 4));
      _isConnected = true;
      _networkAccumulator = '';

      if (mounted) {
        setState(() { _uiStatusMessage = 'Conectado. Controlando flujo activamente.'; });
      }

      _pollingTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
        if (_isConnected && !_isTyping) {
          _socket?.write('P\r\n');
        }
      });

      _socket!.listen(
        (List<int> data) {
          final String chunk = utf8.decode(data, allowMalformed: true);
          _networkAccumulator += chunk;

          _processAccumulatedData();
        },
        onError: (error) {
          debugPrint('Error de Socket: $error');
          _handleDisconnect();
        },
        onDone: () {
          _handleDisconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      _handleDisconnect();
    }
  }

  void _processAccumulatedData() async {
    if (_networkAccumulator.isEmpty || _isTyping) {
      return;
    }

    if (_savedRegex.isNotEmpty) {
      final regExp = RegExp(_savedRegex);
      final match = regExp.firstMatch(_networkAccumulator);

      if (match != null) {
        final nuevoPeso = _formatWeightForOutput(match.group(0));
        
        _receivedDataLog.add(_networkAccumulator);
        if (_receivedDataLog.length > 15) {
          _receivedDataLog.removeAt(0);
        }
        _networkAccumulator = ''; 

        final String numericalCheck = nuevoPeso.replaceAll(RegExp(r'[^0-9.,]'), '').replaceAll(',', '.');
        final double? parsedWeight = double.tryParse(numericalCheck);

        if (parsedWeight != null && parsedWeight == 0.0) {
          debugPrint('[FILTRO INDUSTRIAL] Lectura en cero detectada ($nuevoPeso). Se omite la inyección en Excel.');
          if (mounted) {
            setState(() {
              _cleanWeightDisplay = nuevoPeso; 
            });
          }
          return; 
        }

        final now = DateTime.now();
        if (_lastTypedTime == null || now.difference(_lastTypedTime!) > const Duration(milliseconds: 1500)) {
          _isTyping = true;
          _lastTypedTime = now;

          if (mounted) {
            setState(() { _cleanWeightDisplay = nuevoPeso; });
          }

          await _writeWeightToCursor(nuevoPeso);
          _totalPesajesExitosos++;
          debugPrint('[POLLING EXITOSO] Muestra capturada (#$_totalPesajesExitosos): $nuevoPeso');
          _isTyping = false;
        }
      }
    } else {
      _receivedDataLog.add(_networkAccumulator);
      if (_receivedDataLog.length > 15) {
        _receivedDataLog.removeAt(0);
      }
      _networkAccumulator = '';
    }
  }

  void _handleDisconnect() {
    _pollingTimer?.cancel();
    _isConnected = false;
    _socket?.destroy();
    _socket = null;
    
    if (mounted) {
      setState(() { _uiStatusMessage = 'Fuera de línea. Reintentando...'; });
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      _connect();
    });
  }

  void _disconnect() {
    _pollingTimer?.cancel();
    _reconnectTimer?.cancel();
    _socket?.destroy();
    _socket = null;
    _isConnected = false;
    if (mounted) {
      setState(() {
        _uiStatusMessage = 'Desconectado';
        _cleanWeightDisplay = '---';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool showingConnected = _isConnected;

    return Scaffold(
      appBar: AppBar(title: const Text('Pondera - Control Activo por Polling')),
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
                    const Text('PESO LIMPIO FILTRADO LOCALMENTE', style: TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Text(_cleanWeightDisplay, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
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
                    const Text('Comandos de Teclado (Ej: {TAB}, {ENTER}, {AHORA})', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _prefixController,
                            decoration: const InputDecoration(labelText: 'Prefijo', border: OutlineInputBorder(), isDense: true),
                            style: const TextStyle(fontSize: 13, fontFamily: 'Courier'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _suffixController,
                            decoration: const InputDecoration(labelText: 'Sufijo', border: OutlineInputBorder(), isDense: true),
                            style: const TextStyle(fontSize: 13, fontFamily: 'Courier'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: _saveKeyModifiers,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey.shade700, padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12)),
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
                    Text('Dispositivo: $_deviceIp:$_devicePort', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Text('Estado: $_uiStatusMessage', style: TextStyle(color: showingConnected ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: showingConnected ? _disconnect : _connect,
                          style: ElevatedButton.styleFrom(backgroundColor: showingConnected ? Colors.red.shade700 : Colors.blue.shade700),
                          child: Text(showingConnected ? 'Desconectar' : 'Conectar Indicador'),
                        ),
                        ElevatedButton(
                          onPressed: _sendToN8nIa,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade700),
                          child: const Text('Enviar Trama a n8n'),
                        ),
                        if (_savedRegex.isNotEmpty)
                          TextButton(onPressed: _clearRecipe, child: const Text('Limpiar Receta', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text('Receta Regex activa: $_savedRegex', style: const TextStyle(color: Colors.greenAccent, fontStyle: FontStyle.italic, fontSize: 12)),
            const SizedBox(height: 15),
            const Text('Tramas recibidas en bruto (Data Log):', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(5), border: Border.all(color: Colors.grey.shade800)),
                child: const Center(
                  child: Text('Log de tramas ocultado para estabilidad absoluta del flujo.', style: TextStyle(color: Colors.white54)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}