import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

const MethodChannel _windowsKeyboardChannel = MethodChannel('pondera/windows_keyboard');

enum ConnectionType { ethernet, serial }

const Map<ConnectionType, String> _connectionTypeLabels = {
  ConnectionType.ethernet: 'Ethernet',
  ConnectionType.serial: 'RS-232',
};

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
  static final DateTime _demoExpirationDate = DateTime(2026, 7, 16, 23, 59, 59);

  ConnectionType _selectedConnectionType = ConnectionType.ethernet;
  String _deviceIp = '192.168.100.134';
  int _devicePort = 3004;
  final String _n8nUrl = 'https://n8n.bitgenial.com/webhook-test/pondera-recipe';
  final String _expectedValue = '0.130';
  final bool _allowUntrustedN8nCertificateFallback = true;

  Socket? _socket;
  SerialPort? _serialPort;
  SerialPortReader? _serialReader;
  StreamSubscription<Uint8List>? _serialSubscription;
  Timer? _pollingTimer;
  Timer? _reconnectTimer;
  Timer? _demoTimer;
  bool _isConnected = false;
  bool _isTyping = false;
  bool _manualDisconnectRequested = false;

  DateTime? _lastTypedTime;
  final List<String> _receivedDataLog = [];

  String _savedRegex = '';
  String _cleanWeightDisplay = '---';
  String _uiStatusMessage = 'Desconectado';
  String _networkAccumulator = '';
  String _networkDiagnostics = 'Sin actividad de red.';
  String _n8nDiagnostics = 'n8n: sin petición enviada.';
  int _pollRequestsSent = 0;
  int _bytesReceived = 0;
  int _serialIgnoredBytes = 0;
  bool _isPollingIndicator = false;
  bool _lastN8nRequestUsedUntrustedCertificate = false;
  bool _isDemoExpired = false;
  String _demoStatusMessage = '';

  String _serialPortName = '';
  int _serialBaudRate = 9600;
  int _serialDataBits = 8;
  int _serialStopBits = 1;
  String _serialParity = 'none';
  String _serialFlowControl = 'none';
  List<String> _availableSerialPorts = [];

  String _selectedInputUnit = 'kg';
  String _selectedOutputUnit = 'kg';
  final List<String> _inputUnits = ['kg', 'lb'];
  final List<String> _outputUnits = ['kg', 'lb', 'g', 'mg', 'oz', 't', 'qq', '@'];
  final List<int> _baudRates = [1200, 2400, 4800, 9600, 19200, 38400, 57600, 115200];
  final List<int> _dataBitsOptions = [7, 8];
  final List<int> _stopBitsOptions = [1, 2];
  final Map<String, String> _parityLabels = {
    'none': 'Ninguna',
    'even': 'Par',
    'odd': 'Impar',
    'mark': 'Mark',
    'space': 'Space',
  };
  final Map<String, String> _flowControlLabels = {
    'none': 'Ninguno',
    'rtsCts': 'RTS/CTS',
    'dtrDsr': 'DTR/DSR',
    'xonXoff': 'XON/XOFF',
  };

  final Map<String, String> _unitLabels = {
    'kg': 'Kg.',
    'lb': 'Lb.',
    'g': 'g.',
    'mg': 'mg.',
    'oz': 'Oz.',
    't': 'T.',
    'qq': 'Qq.',
    '@': '@',
  };
  late SharedPreferences _prefs;

  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _serialPortController = TextEditingController();
  final TextEditingController _prefixController = TextEditingController();
  final TextEditingController _suffixController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initSharedPreferences();
  }

  @override
  void dispose() {
    _demoTimer?.cancel();
    _disconnect();
    _ipController.dispose();
    _portController.dispose();
    _serialPortController.dispose();
    _prefixController.dispose();
    _suffixController.dispose();
    super.dispose();
  }

  void _initSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    await _validateDemoLicense();
    final availablePorts = _listSerialPortsSafely();
    setState(() {
      final savedConnectionType = _prefs.getString('pondera_connection_type') ?? 'ethernet';
      _selectedConnectionType = savedConnectionType == 'serial' ? ConnectionType.serial : ConnectionType.ethernet;

      _deviceIp = _prefs.getString('pondera_ip') ?? '192.168.100.134';
      _devicePort = _prefs.getInt('pondera_port') ?? 3004;
      _ipController.text = _deviceIp;
      _portController.text = _devicePort.toString();

      _availableSerialPorts = availablePorts;
      _serialPortName = _prefs.getString('pondera_serial_port') ?? '';
      if (_serialPortName.isEmpty && _availableSerialPorts.isNotEmpty) {
        _serialPortName = _availableSerialPorts.first;
      }
      _serialPortController.text = _serialPortName;
      _serialBaudRate = _prefs.getInt('pondera_serial_baud_rate') ?? 9600;
      _serialDataBits = _prefs.getInt('pondera_serial_data_bits') ?? 8;
      _serialStopBits = _prefs.getInt('pondera_serial_stop_bits') ?? 1;
      _serialParity = _prefs.getString('pondera_serial_parity') ?? 'none';
      _serialFlowControl = _prefs.getString('pondera_serial_flow_control') ?? 'none';

      _savedRegex = _prefs.getString('pondera_recipe') ?? '';
      _prefixController.text = _prefs.getString('pondera_prefix') ?? '';
      _suffixController.text = _prefs.getString('pondera_suffix') ?? '';
      _selectedInputUnit = _prefs.getString('pondera_unit_in') ?? 'kg';
      _selectedOutputUnit = _prefs.getString('pondera_unit_out') ?? 'kg';

      if (_isDemoExpired) {
        _cleanWeightDisplay = 'Demo vencida';
        _uiStatusMessage = _demoStatusMessage;
      } else if (_savedRegex.isNotEmpty) {
        _cleanWeightDisplay = '---';
        _uiStatusMessage = 'Listo para conectar a la balanza.';
      } else {
        _cleanWeightDisplay = 'Sin receta';
      }
    });
    _demoTimer?.cancel();
    _demoTimer = Timer.periodic(const Duration(minutes: 1), (_) => _checkDemoDuringRuntime());
  }

  Future<void> _validateDemoLicense() async {
    final now = DateTime.now();
    final locked = _prefs.getBool('pondera_demo_locked') ?? false;
    final lastRunValue = _prefs.getString('pondera_demo_last_run');
    final lastRun = lastRunValue == null ? null : DateTime.tryParse(lastRunValue)?.toLocal();
    final clockTampered = lastRun != null && now.isBefore(lastRun.subtract(const Duration(minutes: 5)));
    final expired = locked || now.isAfter(_demoExpirationDate) || clockTampered;

    _isDemoExpired = expired;
    if (expired) {
      await _prefs.setBool('pondera_demo_locked', true);
      _demoStatusMessage = clockTampered
          ? 'Demo bloqueada: se detectó retroceso de fecha del sistema.'
          : 'Demo vencida el ${_formatDate(_demoExpirationDate)}.';
      return;
    }

    await _prefs.setString('pondera_demo_last_run', now.toIso8601String());
    _demoStatusMessage = 'Demo vigente hasta el ${_formatDate(_demoExpirationDate)}.';
  }

  void _checkDemoDuringRuntime() async {
    if (_isDemoExpired || DateTime.now().isBefore(_demoExpirationDate)) {
      return;
    }

    await _prefs.setBool('pondera_demo_locked', true);
    _isDemoExpired = true;
    _demoStatusMessage = 'Demo vencida el ${_formatDate(_demoExpirationDate)}.';
    _disconnect();
    if (mounted) {
      setState(() {
        _cleanWeightDisplay = 'Demo vencida';
        _uiStatusMessage = _demoStatusMessage;
        _networkDiagnostics = 'La demo está bloqueada. No se abrirá conexión.';
      });
    }
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day/$month/$year';
  }

  List<String> _listSerialPortsSafely() {
    try {
      return SerialPort.availablePorts;
    } catch (e) {
      debugPrint('No se pudieron listar puertos seriales: $e');
      return [];
    }
  }

  void _refreshSerialPorts() {
    final ports = _listSerialPortsSafely();
    setState(() {
      _availableSerialPorts = ports;
      if (_serialPortName.isEmpty && ports.isNotEmpty) {
        _serialPortName = ports.first;
        _serialPortController.text = _serialPortName;
      }
    });
  }

  void _saveConnectionType(ConnectionType connectionType) async {
    if (_isConnected) {
      _disconnect();
    }
    setState(() {
      _selectedConnectionType = connectionType;
      _networkDiagnostics = connectionType == ConnectionType.ethernet
          ? 'Modo Ethernet seleccionado.'
          : 'Modo RS-232 seleccionado.';
    });
    await _prefs.setString('pondera_connection_type', connectionType.name);
  }

  void _saveNetworkConfig() async {
    final int? parsedPort = int.tryParse(_portController.text);
    if (parsedPort == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Puerto inválido')),
      );
      return;
    }

    setState(() {
      _deviceIp = _ipController.text.trim();
      _devicePort = parsedPort;
    });

    await _prefs.setString('pondera_ip', _deviceIp);
    await _prefs.setInt('pondera_port', _devicePort);

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuración de red guardada'), duration: Duration(milliseconds: 800)),
      );
    }
  }

  void _saveSerialConfig() async {
    final serialPortName = _serialPortController.text.trim();
    setState(() {
      if (serialPortName.isNotEmpty) {
        _serialPortName = serialPortName;
      }
    });

    await _prefs.setString('pondera_serial_port', _serialPortName);
    await _prefs.setInt('pondera_serial_baud_rate', _serialBaudRate);
    await _prefs.setInt('pondera_serial_data_bits', _serialDataBits);
    await _prefs.setInt('pondera_serial_stop_bits', _serialStopBits);
    await _prefs.setString('pondera_serial_parity', _serialParity);
    await _prefs.setString('pondera_serial_flow_control', _serialFlowControl);

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuración RS-232 guardada'), duration: Duration(milliseconds: 800)),
      );
    }
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

  void _saveUnitsConfig() async {
    await _prefs.setString('pondera_unit_in', _selectedInputUnit);
    await _prefs.setString('pondera_unit_out', _selectedOutputUnit);
  }

  bool _isCertificateTrustError(Object error) {
    final message = error.toString();
    return message.contains('CERTIFICATE_VERIFY_FAILED') ||
        message.contains('unable to get local issuer certificate');
  }

  Future<http.Response> _postToN8n(String rawData) async {
    final uri = Uri.parse(_n8nUrl);
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({'trama': rawData, 'valor_esperado': _expectedValue});
    _lastN8nRequestUsedUntrustedCertificate = false;

    try {
      return await http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 12));
    } on HandshakeException catch (e) {
      if (!_allowUntrustedN8nCertificateFallback || !_isCertificateTrustError(e)) {
        rethrow;
      }

      if (mounted) {
        setState(() {
          _n8nDiagnostics = 'n8n: certificado no confiable detectado. Reintentando solo para ${uri.host}...';
        });
      }

      final expectedPort = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
      final httpClient = HttpClient()
        ..connectionTimeout = const Duration(seconds: 12)
        ..badCertificateCallback = (certificate, host, port) {
          return host == uri.host && port == expectedPort;
        };
      final client = IOClient(httpClient);
      try {
        final response = await client.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 12));
        _lastN8nRequestUsedUntrustedCertificate = true;
        return response;
      } finally {
        client.close();
      }
    }
  }

  void _sendToN8nIa() async {
    if (_isDemoExpired) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_demoStatusMessage)));
      return;
    }
    if (_receivedDataLog.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Primero captura una trama.')));
      return;
    }
    String rawData = _receivedDataLog.last;
    
    if (mounted) {
      setState(() {
        _uiStatusMessage = 'Enviando muestra a n8n...';
        _n8nDiagnostics = 'n8n: enviando POST a $_n8nUrl';
      });
    }

    try {
      final response = await _postToN8n(rawData);

      final String responsePreview = response.body.length > 180
          ? '${response.body.substring(0, 180)}...'
          : response.body;

      if (mounted) {
        setState(() {
          final certNote = _lastN8nRequestUsedUntrustedCertificate ? ' usando certificado no confiable aceptado' : '';
          _n8nDiagnostics = 'n8n: HTTP ${response.statusCode}$certNote. Respuesta: $responsePreview';
        });
      }

      if (response.statusCode == 200) {
        dynamic responseData;
        try {
          responseData = jsonDecode(response.body);
        } catch (e) {
          if (mounted) {
            setState(() {
              _uiStatusMessage = 'n8n respondió 200, pero no envió JSON válido.';
              _n8nDiagnostics = 'n8n: JSON inválido. Respuesta: $responsePreview';
            });
          }
          return;
        }
        if (responseData is! Map<String, dynamic>) {
          if (mounted) {
            setState(() {
              _uiStatusMessage = 'n8n respondió 200, pero el JSON no es un objeto.';
              _n8nDiagnostics = 'n8n: estructura inesperada. Respuesta: $responsePreview';
            });
          }
          return;
        }
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
        } else if (mounted) {
          setState(() {
            _uiStatusMessage = 'n8n respondió 200, pero no devolvió regex_pattern.';
          });
        }
      } else if (mounted) {
        setState(() {
          _uiStatusMessage = 'n8n respondió HTTP ${response.statusCode}.';
        });
      }
    } catch (e) {
      debugPrint('Error de conexión con n8n: $e');
      if (mounted) {
        setState(() {
          _uiStatusMessage = 'Error de conexión con n8n.';
          _n8nDiagnostics = 'n8n: error enviando POST: $e';
        });
      }
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
    return '"${value.replaceAll('\\', '\\\\').replaceAll('"', r'\"')}"';
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

  double _convertWeight(double inputWeight, String fromUnit, String toUnit) {
    if (fromUnit == toUnit) return inputWeight;
    double weightInKg = 0.0;
    if (fromUnit == 'kg') {
      weightInKg = inputWeight;
    } else if (fromUnit == 'lb') {
      weightInKg = inputWeight * 0.45359237;
    }

    switch (toUnit) {
      case 'kg':
        return weightInKg;
      case 'lb':
        return weightInKg / 0.45359237;
      case 'g':
        return weightInKg * 1000.0;
      case 'mg':
        return weightInKg * 1000000.0;
      case 'oz':
        return weightInKg * 35.27396195;
      case 't':
        return weightInKg / 1000.0;
      case 'qq': 
        return (weightInKg / 0.45359237) / 100.0;
      case '@':  
        return (weightInKg / 0.45359237) / 25.0;
      default:
        return weightInKg;
    }
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
        scriptBuffer.writeln('  delay 0.05');
      } else if (token == '{ENTER}') {
        scriptBuffer.writeln('  key code 36');
        scriptBuffer.writeln('  delay 0.05');
      } else if (token == '{SPACE}') {
        scriptBuffer.writeln('  key code 49');
        scriptBuffer.writeln('  delay 0.05');
      } else {
        scriptBuffer.writeln('  keystroke ${_appleScriptStringLiteral(token)}');
        scriptBuffer.writeln('  delay 0.05');
      }
    }
    return scriptBuffer.toString();
  }

  String _getCurrentTimestamp() {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');
    return '$year-$month-$day{SPACE}$hour:$minute:$second';
  }

  int _serialParityValue(String parity) {
    switch (parity) {
      case 'even':
        return SerialPortParity.even;
      case 'odd':
        return SerialPortParity.odd;
      case 'mark':
        return SerialPortParity.mark;
      case 'space':
        return SerialPortParity.space;
      case 'none':
      default:
        return SerialPortParity.none;
    }
  }

  int _serialFlowControlValue(String flowControl) {
    switch (flowControl) {
      case 'rtsCts':
        return SerialPortFlowControl.rtsCts;
      case 'dtrDsr':
        return SerialPortFlowControl.dtrDsr;
      case 'xonXoff':
        return SerialPortFlowControl.xonXoff;
      case 'none':
      default:
        return SerialPortFlowControl.none;
    }
  }

  ({String text, int ignoredBytes}) _cleanSerialChunk(List<int> data) {
    final buffer = StringBuffer();
    var ignoredBytes = 0;

    for (final byte in data) {
      final isLineSeparator = byte == 10 || byte == 13;
      final isTab = byte == 9;
      final isPrintableAscii = byte >= 32 && byte <= 126;
      final isUtf8TextByte = byte >= 128;

      if (isLineSeparator || isTab || isPrintableAscii || isUtf8TextByte) {
        buffer.writeCharCode(byte);
      } else {
        ignoredBytes++;
      }
    }

    final text = buffer.toString();
    if (text.trim().isEmpty && _networkAccumulator.trim().isEmpty) {
      ignoredBytes += data.length - ignoredBytes;
      return (text: '', ignoredBytes: ignoredBytes);
    }

    return (text: text, ignoredBytes: ignoredBytes);
  }

  void _appendIncomingChunk(String chunk, int byteCount, {required String sourceLabel}) {
    if (chunk.isEmpty) {
      return;
    }

    _networkAccumulator += chunk;
    _bytesReceived += byteCount;

    if (mounted) {
      setState(() {
        final ignoredNote = _serialIgnoredBytes > 0 ? ' | Bytes ignorados: $_serialIgnoredBytes' : '';
        _networkDiagnostics = 'Polling enviados: $_pollRequestsSent | Bytes útiles recibidos: $_bytesReceived | Último bloque $sourceLabel: $byteCount bytes$ignoredNote';
      });
    }

    _processAccumulatedData();
  }

  String _activeDeviceLabel() {
    if (_selectedConnectionType == ConnectionType.ethernet) {
      return 'Ethernet $_deviceIp:$_devicePort';
    }
    final portName = _serialPortName.isEmpty ? 'sin puerto' : _serialPortName;
    final parity = _parityLabels[_serialParity] ?? _serialParity;
    final flowControl = _flowControlLabels[_serialFlowControl] ?? _serialFlowControl;
    return 'RS-232 $portName | $_serialBaudRate $_serialDataBits-$parity-$_serialStopBits | Flujo: $flowControl';
  }

  Future<void> _writeWeightToCursor(String weightToType) async {
    if (_isDemoExpired) {
      return;
    }

    final String timestampCurrent = _getCurrentTimestamp();
    
    final String currentPrefix = _prefixController.text.replaceAll('{AHORA}', timestampCurrent); 
    final String currentSuffix = _suffixController.text.replaceAll('{AHORA}', timestampCurrent); 

    if (Platform.isMacOS) {
      try {
        await Clipboard.setData(ClipboardData(text: weightToType));
        final String prefixScript = _parseKeysToAppleScript(currentPrefix);
        final String suffixScript = _parseKeysToAppleScript(currentSuffix);
        final process = await Process.start('osascript', []);
        final String fullScript = '''
tell application "System Events"
$prefixScript
  delay 0.1
  keystroke "v" using {command down}
  delay 0.1
$suffixScript
end tell
''';
        process.stdin.write(fullScript);
        await process.stdin.close();
        await process.exitCode.timeout(const Duration(seconds: 2));
      } catch (e) {
        debugPrint('Error en Mac keystroke: $e');
      }
    }

    if (Platform.isWindows) {
      try {
        await Clipboard.setData(ClipboardData(text: weightToType));
        await _windowsKeyboardChannel.invokeMethod<void>(
          'sendPasteSequence',
          <String, String>{
            'prefix': currentPrefix,
            'suffix': currentSuffix,
          },
        ).timeout(const Duration(seconds: 2));

        debugPrint('Inyección nativa de Windows completada con éxito.');
      } catch (e) {
        debugPrint('Error en inyección nativa de Windows: $e');
      }
    }
  }

  void _connect() async {
    if (_isDemoExpired) {
      setState(() {
        _uiStatusMessage = _demoStatusMessage;
        _networkDiagnostics = 'La demo está bloqueada. No se abrirá conexión.';
      });
      return;
    }

    _reconnectTimer?.cancel();
    if (_isConnected) {
      return;
    }
    _manualDisconnectRequested = false;

    if (_selectedConnectionType == ConnectionType.serial) {
      _connectSerial();
      return;
    }

    _connectEthernet();
  }

  void _connectEthernet() async {
    if (mounted) {
      setState(() {
        _uiStatusMessage = 'Conectando a $_deviceIp:$_devicePort...';
        _networkDiagnostics = 'Intentando abrir socket TCP...';
      });
    }

    try {
      _socket = await Socket.connect(_deviceIp, _devicePort, timeout: const Duration(seconds: 4));
      _isConnected = true;
      _networkAccumulator = '';
      _pollRequestsSent = 0;
      _bytesReceived = 0;
      _serialIgnoredBytes = 0;

      if (mounted) {
        setState(() {
          _uiStatusMessage = 'Conectado. Controlando flujo activamente.';
          _networkDiagnostics = 'Socket conectado. Esperando respuesta del indicador...';
        });
      }

      _pollingTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
        if (_isConnected && !_isTyping && !_isPollingIndicator) {
          _isPollingIndicator = true;
          try {
            _socket?.write('P\r\n');
            await _socket?.flush();
            _pollRequestsSent++;
            if (mounted) {
              setState(() {
                _networkDiagnostics = 'Polling enviados: $_pollRequestsSent | Bytes recibidos: $_bytesReceived';
              });
            }
          } catch (e) {
            debugPrint('Error enviando polling: $e');
            _handleDisconnect('Error enviando polling: $e');
          } finally {
            _isPollingIndicator = false;
          }
        }
      });

      _socket!.listen(
        (List<int> data) {
          final String chunk = utf8.decode(data, allowMalformed: true);
          _appendIncomingChunk(chunk, data.length, sourceLabel: 'TCP');
        },
        onError: (error) {
          debugPrint('Error de Socket: $error');
          _handleDisconnect('Error de Socket: $error');
        },
        onDone: () {
          _handleDisconnect('Conexión cerrada por el indicador.');
        },
        cancelOnError: true,
      );
    } catch (e) {
      _handleDisconnect('No se pudo conectar: $e');
    }
  }

  void _connectSerial() async {
    if (_serialPortName.isEmpty) {
      _handleDisconnect('Seleccione un puerto RS-232 antes de conectar.', false);
      return;
    }

    if (mounted) {
      setState(() {
        _uiStatusMessage = 'Conectando a $_serialPortName...';
        _networkDiagnostics = 'Intentando abrir puerto serial RS-232...';
      });
    }

    try {
      final port = SerialPort(_serialPortName);
      if (!port.openReadWrite()) {
        final error = SerialPort.lastError;
        port.dispose();
        _handleDisconnect('No se pudo abrir $_serialPortName: ${error?.message ?? 'error desconocido'}', false);
        return;
      }

      final config = SerialPortConfig()
        ..baudRate = _serialBaudRate
        ..bits = _serialDataBits
        ..parity = _serialParityValue(_serialParity)
        ..stopBits = _serialStopBits
        ..setFlowControl(_serialFlowControlValue(_serialFlowControl));
      port.config = config;

      _serialPort = port;
      _serialReader = SerialPortReader(port);
      _isConnected = true;
      _networkAccumulator = '';
      _pollRequestsSent = 0;
      _bytesReceived = 0;
      _serialIgnoredBytes = 0;

      if (mounted) {
        setState(() {
          _uiStatusMessage = 'RS-232 conectado. Esperando datos del indicador.';
          _networkDiagnostics = 'Puerto serial abierto. Esperando datos del indicador...';
        });
      }

      _serialSubscription = _serialReader!.stream.listen(
        (Uint8List data) {
          final cleanedChunk = _cleanSerialChunk(data);
          if (cleanedChunk.ignoredBytes > 0) {
            _serialIgnoredBytes += cleanedChunk.ignoredBytes;
          }

          if (cleanedChunk.text.isEmpty) {
            if (mounted) {
              setState(() {
                _networkDiagnostics = 'RS-232 escuchando | Bytes útiles recibidos: $_bytesReceived | Bytes ignorados: $_serialIgnoredBytes';
              });
            }
            return;
          }

          if (cleanedChunk.ignoredBytes > 0 && mounted) {
            setState(() {
              _networkDiagnostics = 'RS-232 escuchando | Bytes útiles recibidos: $_bytesReceived | Bytes ignorados: $_serialIgnoredBytes';
            });
          }

          _appendIncomingChunk(cleanedChunk.text, data.length - cleanedChunk.ignoredBytes, sourceLabel: 'RS-232');
        },
        onError: (error) {
          debugPrint('Error de puerto serial: $error');
          _handleDisconnect('Error de puerto serial: $error');
        },
        onDone: () {
          _handleDisconnect('Puerto serial cerrado por el sistema.');
        },
        cancelOnError: true,
      );
    } catch (e) {
      _handleDisconnect('No se pudo conectar por RS-232: $e');
    }
  }

  void _processAccumulatedData() async {
    if (_networkAccumulator.isEmpty || _isTyping) {
      return;
    }

    if (mounted) {
      setState(() {
        _receivedDataLog.add(_networkAccumulator);
        if (_receivedDataLog.length > 25) {
          _receivedDataLog.removeAt(0);
        }
      });
    }

    if (_savedRegex.isNotEmpty) {
      final regExp = RegExp(_savedRegex);
      final match = regExp.firstMatch(_networkAccumulator);
      if (match != null) {
        final nuevoPesoOriginal = _formatWeightForOutput(match.group(0));
        _networkAccumulator = ''; 

        final String numericalCheck = nuevoPesoOriginal.replaceAll(RegExp(r'[^0-9.,]'), '').replaceAll(',', '.');
        final double? parsedWeight = double.tryParse(numericalCheck);

        if (parsedWeight != null && parsedWeight == 0.0) {
          if (mounted) {
            setState(() {
              String labelIn = _unitLabels[_selectedInputUnit] ?? _selectedInputUnit;
              _cleanWeightDisplay = '$nuevoPesoOriginal $labelIn'; 
            });
          }
          return;
        }

        String pesoFinalAInyectar = nuevoPesoOriginal;
        if (parsedWeight != null) {
          final double valorConvertido = _convertWeight(parsedWeight, _selectedInputUnit, _selectedOutputUnit);
          final int decimalesOrigen = numericalCheck.contains('.') ? numericalCheck.split('.')[1].length : 2;
          String valorString = valorConvertido.toStringAsFixed(decimalesOrigen);
          pesoFinalAInyectar = _formatWeightForOutput(valorString);
        }

        final now = DateTime.now();
        if (_lastTypedTime == null || now.difference(_lastTypedTime!) > const Duration(milliseconds: 1500)) {
          _isTyping = true;
          _lastTypedTime = now;

          if (mounted) {
            setState(() { 
              String labelOut = _unitLabels[_selectedOutputUnit] ?? _selectedOutputUnit;
              _cleanWeightDisplay = '$pesoFinalAInyectar $labelOut'; 
            });
          }

          await _writeWeightToCursor(pesoFinalAInyectar);
          _isTyping = false;
        }
      }
    } else {
      _networkAccumulator = '';
    }
  }

  void _handleDisconnect([String reason = 'Fuera de línea. Reintentando...', bool shouldReconnect = true]) {
    final allowReconnect = shouldReconnect && !_manualDisconnectRequested && !_isDemoExpired;
    _pollingTimer?.cancel();
    _isConnected = false;
    _isPollingIndicator = false;
    _socket?.destroy();
    _socket = null;
    _serialSubscription?.cancel();
    _serialSubscription = null;
    _serialReader?.close();
    _serialReader = null;
    _serialPort?.close();
    _serialPort?.dispose();
    _serialPort = null;
    
    if (mounted) {
      setState(() {
        _uiStatusMessage = reason;
        _networkDiagnostics = 'Desconectado. $reason | Polling enviados: $_pollRequestsSent | Bytes recibidos: $_bytesReceived';
      });
    }

    _reconnectTimer?.cancel();
    if (!allowReconnect) {
      return;
    }
    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      _connect();
    });
  }

  void _disconnect() {
    _manualDisconnectRequested = true;
    _pollingTimer?.cancel();
    _reconnectTimer?.cancel();
    _socket?.destroy();
    _socket = null;
    _serialSubscription?.cancel();
    _serialSubscription = null;
    _serialReader?.close();
    _serialReader = null;
    _serialPort?.close();
    _serialPort?.dispose();
    _serialPort = null;
    _isConnected = false;
    if (mounted) {
      setState(() {
        _uiStatusMessage = 'Desconectado';
        _cleanWeightDisplay = '---';
        _networkDiagnostics = 'Sin actividad de enlace.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool showingConnected = _isConnected;
    return Scaffold(
      appBar: AppBar(title: const Text('Pondera - Control Activo por Polling')),
      body: SingleChildScrollView(
        child: Padding(
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
                    const Text('PESO FILTRADO Y CONVERTIDO EN PONDERA', style: TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
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
                    const Text('Configuración de Enlace (Balanza Industrial)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<ConnectionType>(
                      initialValue: _selectedConnectionType,
                      decoration: const InputDecoration(labelText: 'Tipo de conexión', border: OutlineInputBorder(), isDense: true),
                      items: ConnectionType.values.map((type) {
                        return DropdownMenuItem(value: type, child: Text(_connectionTypeLabels[type] ?? type.name));
                      }).toList(),
                      onChanged: showingConnected
                          ? null
                          : (value) {
                              if (value != null) {
                                _saveConnectionType(value);
                              }
                            },
                    ),
                    const SizedBox(height: 10),
                    if (_selectedConnectionType == ConnectionType.ethernet)
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: _ipController,
                              decoration: const InputDecoration(labelText: 'Dirección IP', border: OutlineInputBorder(), isDense: true),
                              style: const TextStyle(fontSize: 13, fontFamily: 'Courier'),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _portController,
                              decoration: const InputDecoration(labelText: 'Puerto TCP', border: OutlineInputBorder(), isDense: true),
                              style: const TextStyle(fontSize: 13, fontFamily: 'Courier'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: _saveNetworkConfig,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey.shade700, padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12)),
                            child: const Icon(Icons.save_sharp, size: 18),
                          ),
                        ],
                      ),
                    if (_selectedConnectionType == ConnectionType.serial)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: _serialPortController,
                                  decoration: InputDecoration(
                                    labelText: Platform.isWindows ? 'Puerto serial (ej. COM3)' : 'Puerto serial',
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  style: const TextStyle(fontSize: 13, fontFamily: 'Courier'),
                                  onChanged: (value) => _serialPortName = value.trim(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  initialValue: _availableSerialPorts.contains(_serialPortName) ? _serialPortName : null,
                                  decoration: const InputDecoration(labelText: 'Detectados', border: OutlineInputBorder(), isDense: true),
                                  items: _availableSerialPorts.map((port) {
                                    return DropdownMenuItem(value: port, child: Text(port));
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value == null) {
                                      return;
                                    }
                                    setState(() {
                                      _serialPortName = value;
                                      _serialPortController.text = value;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              IconButton(
                                onPressed: _refreshSerialPorts,
                                tooltip: 'Actualizar puertos',
                                icon: const Icon(Icons.refresh),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  initialValue: _baudRates.contains(_serialBaudRate) ? _serialBaudRate : 9600,
                                  decoration: const InputDecoration(labelText: 'Baud rate', border: OutlineInputBorder(), isDense: true),
                                  items: _baudRates.map((rate) => DropdownMenuItem(value: rate, child: Text(rate.toString()))).toList(),
                                  onChanged: (value) => setState(() => _serialBaudRate = value ?? 9600),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  initialValue: _dataBitsOptions.contains(_serialDataBits) ? _serialDataBits : 8,
                                  decoration: const InputDecoration(labelText: 'Data bits', border: OutlineInputBorder(), isDense: true),
                                  items: _dataBitsOptions.map((bits) => DropdownMenuItem(value: bits, child: Text(bits.toString()))).toList(),
                                  onChanged: (value) => setState(() => _serialDataBits = value ?? 8),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _parityLabels.containsKey(_serialParity) ? _serialParity : 'none',
                                  decoration: const InputDecoration(labelText: 'Paridad', border: OutlineInputBorder(), isDense: true),
                                  items: _parityLabels.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
                                  onChanged: (value) => setState(() => _serialParity = value ?? 'none'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  initialValue: _stopBitsOptions.contains(_serialStopBits) ? _serialStopBits : 1,
                                  decoration: const InputDecoration(labelText: 'Stop bits', border: OutlineInputBorder(), isDense: true),
                                  items: _stopBitsOptions.map((bits) => DropdownMenuItem(value: bits, child: Text(bits.toString()))).toList(),
                                  onChanged: (value) => setState(() => _serialStopBits = value ?? 1),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _flowControlLabels.containsKey(_serialFlowControl) ? _serialFlowControl : 'none',
                                  decoration: const InputDecoration(labelText: 'Flow control', border: OutlineInputBorder(), isDense: true),
                                  items: _flowControlLabels.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
                                  onChanged: (value) => setState(() => _serialFlowControl = value ?? 'none'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              onPressed: _saveSerialConfig,
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey.shade700, padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12)),
                              child: const Icon(Icons.save_sharp, size: 18),
                            ),
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
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Configuración de Unidades de Medida', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedInputUnit,
                            decoration: const InputDecoration(labelText: 'Origen Balanza', border: OutlineInputBorder(), isDense: true),
                            items: _inputUnits.map((unit) {
                              return DropdownMenuItem(value: unit, child: Text(_unitLabels[unit] ?? unit));
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedInputUnit = val ?? 'kg';
                                _saveUnitsConfig();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedOutputUnit,
                            decoration: const InputDecoration(labelText: 'Destino Escritura', border: OutlineInputBorder(), isDense: true),
                            items: _outputUnits.map((unit) {
                              return DropdownMenuItem(value: unit, child: Text(_unitLabels[unit] ?? unit));
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedOutputUnit = val ?? 'kg';
                                _saveUnitsConfig();
                              });
                            },
                          ),
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
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Comandos de Teclado (Ej: {TAB}, {ENTER}, {SPACE}, {AHORA})', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
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
                    Text('Dispositivo de destino activo: ${_activeDeviceLabel()}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70)),
                    const SizedBox(height: 5),
                    Text(_demoStatusMessage, style: TextStyle(fontSize: 12, color: _isDemoExpired ? Colors.redAccent : Colors.lightGreenAccent)),
                    const SizedBox(height: 5),
                    Text('Estado: $_uiStatusMessage', style: TextStyle(color: showingConnected ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Text(_networkDiagnostics, style: const TextStyle(fontSize: 12, color: Colors.white60)),
                    const SizedBox(height: 5),
                    Text(_n8nDiagnostics, style: const TextStyle(fontSize: 12, color: Colors.white60)),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: _isDemoExpired ? null : (showingConnected ? _disconnect : _connect),
                          style: ElevatedButton.styleFrom(backgroundColor: showingConnected ? Colors.red.shade700 : Colors.blue.shade700),
                          child: Text(showingConnected ? 'Desconectar' : 'Conectar Indicador'),
                        ),
                        ElevatedButton(
                          onPressed: _isDemoExpired ? null : _sendToN8nIa,
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
            SizedBox(
              height: 260,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(5), border: Border.all(color: Colors.grey.shade800)),
                child: _receivedDataLog.isEmpty
                    ? const Center(
                        child: Text('Esperando datos de la balanza...', style: TextStyle(color: Colors.white54, fontSize: 13)),
                      )
                    : ListView.builder(
                        itemCount: _receivedDataLog.length,
                        reverse: true,
                        itemBuilder: (context, index) {
                          final logEntry = _receivedDataLog[_receivedDataLog.length - 1 - index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Text(
                              logEntry.replaceAll('\r', '\\r').replaceAll('\n', '\\n'),
                              style: const TextStyle(color: Colors.green, fontFamily: 'Courier', fontSize: 12),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}
