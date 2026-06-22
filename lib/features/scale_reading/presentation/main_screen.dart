import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/pondera_header.dart';
import '../../../core/config/app_config.dart';
import '../../connection/domain/connection_type.dart';
import '../../connection/presentation/connection_diagnostics_panel.dart';
import '../../connection/presentation/connection_settings_panel.dart';
import '../../connection/presentation/connection_status_panel.dart';
import '../../keyboard_output/presentation/keyboard_settings_panel.dart';
import '../../license/application/activation_request_service.dart';
import '../../license/application/demo_license_controller.dart';
import '../../license/application/offline_license_controller.dart';
import '../../license/data/activation_request_exporter.dart';
import '../../license/data/installation_identity_repository.dart';
import '../../license/data/license_file_importer.dart';
import '../../license/data/license_key_registry.dart';
import '../../license/data/license_verifier.dart';
import '../../license/data/offline_license_repository.dart';
import '../../license/domain/demo_license.dart';
import '../../license/domain/license_verification_result.dart';
import '../../license/presentation/activation_request_dialog.dart';
import '../../license/presentation/license_status_panel.dart';
import '../../recipe/presentation/recipe_actions_panel.dart';
import '../../settings/data/settings_repository.dart';
import '../domain/reading_parser.dart';
import '../domain/weight_converter.dart';
import '../domain/weight_unit.dart';
import 'current_weight_panel.dart';
import 'raw_data_log_panel.dart';
import 'units_settings_panel.dart';

const MethodChannel _windowsKeyboardChannel = MethodChannel(
  'pondera/windows_keyboard',
);

class MainScreen extends StatefulWidget {
  const MainScreen({
    required this.themeMode,
    required this.onThemeModeChanged,
    super.key,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const _userManualAssetPath = 'assets/help/pondera_manual_usuario.pdf';

  ConnectionType _selectedConnectionType = ConnectionType.ethernet;
  String _deviceIp = '192.168.100.134';
  int _devicePort = 3004;
  final String _n8nUrl = 'https://n8n.bitgenial.com/webhook/pondera-recipe';
  String _expectedValue = '';
  final bool _allowUntrustedN8nCertificateFallback = true;

  Socket? _socket;
  SerialPort? _serialPort;
  SerialPortReader? _serialReader;
  StreamSubscription<Uint8List>? _serialSubscription;
  Timer? _pollingTimer;
  Timer? _reconnectTimer;
  Timer? _demoTimer;
  Timer? _telemetryRefreshTimer;
  bool _isConnected = false;
  bool _isTyping = false;
  bool _manualDisconnectRequested = false;

  DateTime? _lastTypedTime;
  final List<RawDataLogEntry> _receivedDataLog = [];
  int _receptionSequence = 0;

  String _savedRegex = '';
  String _cleanWeightDisplay = '---';
  String _uiStatusMessage = 'Desconectado';
  String _networkAccumulator = '';
  String _networkDiagnostics = 'Sin actividad de red.';
  int _pollRequestsSent = 0;
  int _bytesReceived = 0;
  int _serialIgnoredBytes = 0;
  bool _isPollingIndicator = false;
  bool _isSendingToN8n = false;
  bool _isDemoExpired = false;
  String _demoStatusMessage = '';
  String _installationId = '';
  String _appVersion = '';

  String _serialPortName = '';
  int _serialBaudRate = 9600;
  int _serialDataBits = 8;
  int _serialStopBits = 1;
  String _serialParity = 'none';
  String _serialFlowControl = 'none';
  List<String> _availableSerialPorts = [];

  WeightUnit _selectedInputUnit = WeightUnit.kilogram;
  WeightUnit _selectedOutputUnit = WeightUnit.kilogram;
  final List<WeightUnit> _inputUnits = [WeightUnit.kilogram, WeightUnit.pound];
  final List<WeightUnit> _outputUnits = WeightUnit.values;
  final List<int> _baudRates = [
    1200,
    2400,
    4800,
    9600,
    19200,
    38400,
    57600,
    115200,
  ];
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

  late SettingsRepository _settingsRepository;
  late DemoLicenseController _demoLicenseController;
  ActivationRequestService? _activationRequestService;
  OfflineLicenseController? _offlineLicenseController;
  final ActivationRequestExporter _activationRequestExporter =
      const ActivationRequestExporter();
  final LicenseFileImporter _licenseFileImporter = const LicenseFileImporter();
  DemoLicense? _demoLicense;
  LicenseVerificationResult? _offlineLicenseResult;

  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _serialPortController = TextEditingController();
  final TextEditingController _prefixController = TextEditingController();
  final TextEditingController _suffixController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _demoTimer?.cancel();
    _telemetryRefreshTimer?.cancel();
    _disconnect();
    _ipController.dispose();
    _portController.dispose();
    _serialPortController.dispose();
    _prefixController.dispose();
    _suffixController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    _settingsRepository = await SettingsRepository.create();
    final identityRepository = await InstallationIdentityRepository.create();
    _installationId = await identityRepository.getOrCreate();
    final packageInfo = await PackageInfo.fromPlatform();
    _appVersion = packageInfo.buildNumber.isEmpty
        ? packageInfo.version
        : '${packageInfo.version}+${packageInfo.buildNumber}';
    _activationRequestService = ActivationRequestService(identityRepository);
    _offlineLicenseController = OfflineLicenseController(
      identityRepository,
      await OfflineLicenseRepository.create(),
      LicenseVerifier(LicenseKeyRegistry.forCurrentBuild()),
    );
    _demoLicenseController = DemoLicenseController(_settingsRepository);
    final offlineLicense = await _offlineLicenseController!.validateStored();
    final demoLicense =
        offlineLicense.status == LicenseVerificationStatus.missing
        ? await _demoLicenseController.validate()
        : null;
    final shouldClearRecipe = _shouldClearRecipeForLicenseState(
      offlineLicense: offlineLicense,
      demoLicense: demoLicense,
    );
    if (shouldClearRecipe) {
      await _clearRecipeStorage();
    }
    final settings = _settingsRepository.load();
    final availablePorts = _listSerialPortsSafely();
    if (!mounted) {
      return;
    }
    setState(() {
      _offlineLicenseResult = offlineLicense;
      _demoLicense = demoLicense;
      if (offlineLicense.status != LicenseVerificationStatus.missing) {
        _isDemoExpired = !offlineLicense.isUsable;
        _demoStatusMessage = offlineLicense.message;
      } else {
        _isDemoExpired = demoLicense!.isExpired;
        _demoStatusMessage = demoLicense.statusMessage;
      }
      _selectedConnectionType = settings.connectionType == 'serial'
          ? ConnectionType.serial
          : ConnectionType.ethernet;

      _deviceIp = settings.deviceIp;
      _devicePort = settings.devicePort;
      _ipController.text = _deviceIp;
      _portController.text = _devicePort.toString();

      _availableSerialPorts = availablePorts;
      _serialPortName = settings.serialPortName;
      if (_serialPortName.isEmpty && _availableSerialPorts.isNotEmpty) {
        _serialPortName = _availableSerialPorts.first;
      }
      _serialPortController.text = _serialPortName;
      _serialBaudRate = settings.serialBaudRate;
      _serialDataBits = settings.serialDataBits;
      _serialStopBits = settings.serialStopBits;
      _serialParity = settings.serialParity;
      _serialFlowControl = settings.serialFlowControl;

      _savedRegex = settings.recipePattern;
      _expectedValue = settings.expectedValue;
      _prefixController.text = settings.keyboardPrefix;
      _suffixController.text = settings.keyboardSuffix;
      _selectedInputUnit =
          WeightUnit.fromCode(settings.inputUnit) ?? WeightUnit.kilogram;
      _selectedOutputUnit =
          WeightUnit.fromCode(settings.outputUnit) ?? WeightUnit.kilogram;

      if (_isDemoExpired) {
        _cleanWeightDisplay =
            offlineLicense.status == LicenseVerificationStatus.missing
            ? 'Demo vencida'
            : 'Licencia inválida';
        _uiStatusMessage = _demoStatusMessage;
      } else if (_savedRegex.isNotEmpty) {
        _cleanWeightDisplay = '---';
        _uiStatusMessage = 'Listo para conectar a la balanza.';
      } else {
        _cleanWeightDisplay = 'Sin receta';
      }
    });
    _demoTimer?.cancel();
    _demoTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkLicenseDuringRuntime(),
    );
  }

  Future<void> _checkLicenseDuringRuntime() async {
    final offlineLicense = _offlineLicenseResult;
    if (offlineLicense != null &&
        offlineLicense.status != LicenseVerificationStatus.missing) {
      final updatedLicense = await _offlineLicenseController!.validateStored();
      if (!mounted) {
        return;
      }
      _offlineLicenseResult = updatedLicense;
      _isDemoExpired = !updatedLicense.isUsable;
      _demoStatusMessage = updatedLicense.message;
      if (_isDemoExpired) {
        if (_shouldClearRecipeForOfflineLicense(updatedLicense)) {
          await _clearRecipeStorage();
        }
        _disconnect();
      }
      setState(() {
        if (_isDemoExpired) {
          _savedRegex = '';
          _expectedValue = '';
          _cleanWeightDisplay = 'Licencia vencida';
          _uiStatusMessage = updatedLicense.message;
          _networkDiagnostics =
              'La licencia está bloqueada. No se abrirá conexión.';
        }
      });
      return;
    }

    final currentLicense = _demoLicense;
    if (currentLicense == null) {
      return;
    }

    final updatedLicense = await _demoLicenseController.checkDuringRuntime(
      currentLicense: currentLicense,
    );
    if (updatedLicense == null || !mounted) {
      return;
    }

    _demoLicense = updatedLicense;
    _isDemoExpired = updatedLicense.isExpired;
    _demoStatusMessage = updatedLicense.statusMessage;
    await _clearRecipeStorage();
    _disconnect();
    setState(() {
      _savedRegex = '';
      _expectedValue = '';
      _cleanWeightDisplay = 'Demo vencida';
      _uiStatusMessage = _demoStatusMessage;
      _networkDiagnostics = 'La demo está bloqueada. No se abrirá conexión.';
    });
  }

  Future<void> _resetDemoForDevelopment() async {
    final license = await _demoLicenseController.resetForDevelopment();
    if (!mounted) {
      return;
    }

    setState(() {
      _demoLicense = license;
      _isDemoExpired = license.isExpired;
      _demoStatusMessage = license.statusMessage;
      _cleanWeightDisplay = license.isExpired
          ? 'Demo vencida'
          : (_savedRegex.isEmpty ? 'Sin receta' : '---');
      _uiStatusMessage = license.isExpired
          ? license.statusMessage
          : 'Demo restablecida. Lista para continuar.';
      _networkDiagnostics = license.isExpired
          ? 'La fecha de vencimiento configurada ya pasó.'
          : 'Bloqueo de demo eliminado en modo desarrollo.';
    });
  }

  Future<void> _generateActivationRequest() async {
    final formData = await showActivationRequestDialog(
      context,
      suggestedDeviceLabel: Platform.localHostname,
    );
    if (formData == null || !mounted) {
      return;
    }

    try {
      final activationRequestService = _activationRequestService;
      if (activationRequestService == null) {
        throw StateError('Pondera todavía se está inicializando.');
      }
      final packageInfo = await PackageInfo.fromPlatform();
      final appVersion = packageInfo.buildNumber.isEmpty
          ? packageInfo.version
          : '${packageInfo.version}+${packageInfo.buildNumber}';
      final request = await activationRequestService.create(
        platform: Platform.operatingSystem,
        appVersion: appVersion,
        customerName: formData.customerName,
        siteName: formData.siteName,
        city: formData.city,
        deviceLabel: formData.deviceLabel,
        assetTag: formData.assetTag,
      );
      final savedPath = await _activationRequestExporter.export(request);
      if (savedPath == null || !mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Solicitud guardada en $savedPath'),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (error) {
      debugPrint('No se pudo generar la solicitud de activación: $error');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar la solicitud: $error')),
      );
    }
  }

  Future<void> _importOfflineLicense() async {
    try {
      final encodedLicense = await _licenseFileImporter.selectAndRead();
      if (encodedLicense == null || !mounted) {
        return;
      }
      final controller = _offlineLicenseController;
      if (controller == null) {
        throw StateError('Pondera todavía se está inicializando.');
      }

      final result = await controller.import(encodedLicense);
      if (!mounted) {
        return;
      }
      if (!result.isUsable) {
        if (_shouldClearRecipeForOfflineLicense(result)) {
          await _clearRecipeStorage();
          if (!mounted) {
            return;
          }
          setState(() {
            _savedRegex = '';
            _expectedValue = '';
            _cleanWeightDisplay = 'Licencia vencida';
            _uiStatusMessage = result.message;
          });
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.message)));
        return;
      }

      setState(() {
        _offlineLicenseResult = result;
        _demoLicense = null;
        _isDemoExpired = false;
        _demoStatusMessage = result.message;
        _cleanWeightDisplay = _savedRegex.isEmpty ? 'Sin receta' : '---';
        _uiStatusMessage = 'Licencia activada. Lista para continuar.';
        _networkDiagnostics =
            'Licencia ${result.payload!.licenseId} verificada correctamente.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Licencia activada para ${result.payload!.customerName} · '
            '${result.payload!.deviceLabel}.',
          ),
        ),
      );
    } catch (error) {
      debugPrint('No se pudo importar la licencia: $error');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo importar la licencia: $error')),
      );
    }
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
    await _settingsRepository.saveConnectionType(connectionType.name);
  }

  void _saveNetworkConfig() async {
    final int? parsedPort = int.tryParse(_portController.text);
    if (parsedPort == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Puerto inválido')));
      return;
    }

    setState(() {
      _deviceIp = _ipController.text.trim();
      _devicePort = parsedPort;
    });

    await _settingsRepository.saveNetwork(ip: _deviceIp, port: _devicePort);

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuración de red guardada'),
          duration: Duration(milliseconds: 800),
        ),
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

    await _settingsRepository.saveSerial(
      portName: _serialPortName,
      baudRate: _serialBaudRate,
      dataBits: _serialDataBits,
      stopBits: _serialStopBits,
      parity: _serialParity,
      flowControl: _serialFlowControl,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuración RS-232 guardada'),
          duration: Duration(milliseconds: 800),
        ),
      );
    }
  }

  void _saveKeyModifiers() async {
    await _settingsRepository.saveKeyboardCommands(
      prefix: _prefixController.text,
      suffix: _suffixController.text,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comandos de teclado guardados'),
          duration: Duration(milliseconds: 800),
        ),
      );
    }
  }

  void _saveUnitsConfig() async {
    await _settingsRepository.saveUnits(
      inputUnit: _selectedInputUnit.code,
      outputUnit: _selectedOutputUnit.code,
    );
  }

  bool _isCertificateTrustError(Object error) {
    final message = error.toString();
    return message.contains('CERTIFICATE_VERIFY_FAILED') ||
        message.contains('unable to get local issuer certificate');
  }

  Future<void> _openUserManual() async {
    try {
      final bytes = await rootBundle.load(_userManualAssetPath);
      final supportDirectory = await getApplicationSupportDirectory();
      final manualDirectory = Directory(
        '${supportDirectory.path}${Platform.pathSeparator}help',
      );
      if (!await manualDirectory.exists()) {
        await manualDirectory.create(recursive: true);
      }
      final manualFile = File(
        '${manualDirectory.path}${Platform.pathSeparator}pondera_manual_usuario.pdf',
      );
      await manualFile.writeAsBytes(
        bytes.buffer.asUint8List(),
        flush: true,
      );

      if (Platform.isMacOS) {
        await Process.run('open', [manualFile.path]);
      } else if (Platform.isWindows) {
        await Process.run('explorer.exe', [manualFile.path]);
      } else {
        throw UnsupportedError('Plataforma no soportada para abrir el manual.');
      }
    } catch (error) {
      debugPrint('No se pudo abrir el manual de usuario: $error');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el manual: $error')),
      );
    }
  }

  Future<http.Response> _postToN8n(String rawData, String expectedValue) async {
    final uri = Uri.parse(_n8nUrl);
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'trama': rawData,
      'valor_esperado': expectedValue,
      'metadata': _buildN8nMetadata(),
    });
    try {
      return await http
          .post(uri, headers: headers, body: body)
          .timeout(AppConfig.n8nRequestTimeout);
    } on HandshakeException catch (e) {
      if (!_allowUntrustedN8nCertificateFallback ||
          !_isCertificateTrustError(e)) {
        rethrow;
      }

      final expectedPort = uri.hasPort
          ? uri.port
          : (uri.scheme == 'https' ? 443 : 80);
      final httpClient = HttpClient()
        ..connectionTimeout = AppConfig.n8nRequestTimeout
        ..badCertificateCallback = (certificate, host, port) {
          return host == uri.host && port == expectedPort;
        };
      final client = IOClient(httpClient);
      try {
        final response = await client
            .post(uri, headers: headers, body: body)
            .timeout(AppConfig.n8nRequestTimeout);
        return response;
      } finally {
        client.close();
      }
    }
  }

  Map<String, Object?> _buildN8nMetadata() {
    final offlineLicense = _offlineLicenseResult;
    final licensePayload = offlineLicense?.payload;
    final demoLicense = _demoLicense;

    return {
      'installation_id': _installationId,
      'app_version': _appVersion,
      'platform': Platform.operatingSystem,
      'license_mode': _resolveLicenseMode(),
      'license_status': offlineLicense?.status.name,
      'license_id': licensePayload?.licenseId,
      'customer_id': licensePayload?.customerId,
      'customer_name': licensePayload?.customerName,
      'site_id': licensePayload?.siteId,
      'site_name': licensePayload?.siteName,
      'device_label': licensePayload?.deviceLabel,
      'demo_expires_at': demoLicense?.expirationDate.toUtc().toIso8601String(),
      'demo_status': demoLicense?.status.name,
    };
  }

  String _resolveLicenseMode() {
    final offlineLicense = _offlineLicenseResult;
    if (offlineLicense != null &&
        offlineLicense.status != LicenseVerificationStatus.missing) {
      return offlineLicense.isUsable ? 'licensed' : 'license_blocked';
    }
    if (_demoLicense == null) {
      return 'uninitialized';
    }
    return _demoLicense!.isExpired ? 'demo_expired' : 'demo';
  }

  Future<String?> _requestExpectedValue() async {
    final formKey = GlobalKey<FormState>();
    var enteredValue = _expectedValue;
    final expectedValue = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        void submit() {
          if (formKey.currentState?.validate() ?? false) {
            Navigator.of(dialogContext).pop(enteredValue.trim());
          }
        }

        return AlertDialog(
          title: const Text('Valor esperado'),
          content: Form(
            key: formKey,
            child: TextFormField(
              initialValue: enteredValue,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Peso correspondiente a la trama',
                hintText: 'Ej.: 0.130 o 0,130',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (!ReadingParser.isValidExpectedValue(value ?? '')) {
                  return 'Ingrese un valor válido, por ejemplo 0.130 o 0,130.';
                }
                return null;
              },
              onChanged: (value) => enteredValue = value,
              onFieldSubmitted: (_) => submit(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(onPressed: submit, child: const Text('Enviar')),
          ],
        );
      },
    );
    return expectedValue;
  }

  Future<void> _sendToN8nIa() async {
    if (_isSendingToN8n) {
      return;
    }
    if (_isDemoExpired) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_demoStatusMessage)));
      return;
    }
    if (_receivedDataLog.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero captura una trama.')),
      );
      return;
    }
    final rawData = _receivedDataLog.last.rawData;
    final expectedValue = await _requestExpectedValue();
    if (expectedValue == null || !mounted) {
      return;
    }

    if (mounted) {
      setState(() {
        _isSendingToN8n = true;
        _uiStatusMessage = 'Enviando muestra a n8n...';
      });
    }

    try {
      final response = await _postToN8n(rawData, expectedValue);

      if (response.statusCode == 200) {
        dynamic responseData;
        try {
          responseData = jsonDecode(response.body);
        } catch (e) {
          if (mounted) {
            setState(() {
              _uiStatusMessage =
                  'n8n respondió 200, pero no envió JSON válido.';
            });
          }
          return;
        }
        if (responseData is! Map<String, dynamic>) {
          if (mounted) {
            setState(() {
              _uiStatusMessage =
                  'n8n respondió 200, pero el JSON no es un objeto.';
            });
          }
          return;
        }
        final regexValue = responseData['regex_pattern'];
        final newRegex = regexValue is String ? regexValue.trim() : '';
        if (newRegex.isNotEmpty) {
          try {
            RegExp(newRegex);
          } on FormatException {
            if (mounted) {
              setState(() {
                _uiStatusMessage = 'n8n devolvió una receta Regex inválida.';
              });
            }
            return;
          }

          await _settingsRepository.saveRecipe(
            pattern: newRegex,
            expectedValue: expectedValue,
          );
          if (mounted) {
            setState(() {
              _savedRegex = newRegex;
              _expectedValue = expectedValue;
              _uiStatusMessage = '¡Receta Regex guardada con éxito!';
            });
          }
        } else if (mounted) {
          setState(() {
            _uiStatusMessage =
                'n8n respondió 200, pero no devolvió regex_pattern.';
          });
        }
      } else if (mounted) {
        setState(() {
          _uiStatusMessage = 'n8n respondió HTTP ${response.statusCode}.';
        });
      }
    } on TimeoutException catch (e) {
      debugPrint('Timeout esperando respuesta de n8n: $e');
      if (mounted) {
        setState(() {
          _uiStatusMessage = 'n8n tardó más de 45 segundos en responder.';
        });
      }
    } catch (e) {
      debugPrint('Error de conexión con n8n: $e');
      if (mounted) {
        setState(() {
          _uiStatusMessage = 'Error de conexión con n8n.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingToN8n = false;
        });
      }
    }
  }

  void _clearRecipe() async {
    await _settingsRepository.clearRecipe();
    setState(() {
      _savedRegex = '';
      _expectedValue = '';
      _cleanWeightDisplay = 'Sin receta';
      _uiStatusMessage = 'Receta eliminada.';
    });
  }

  bool _shouldClearRecipeForLicenseState({
    required LicenseVerificationResult offlineLicense,
    required DemoLicense? demoLicense,
  }) {
    if (_shouldClearRecipeForOfflineLicense(offlineLicense)) {
      return true;
    }
    return offlineLicense.status == LicenseVerificationStatus.missing &&
        (demoLicense?.isExpired ?? false);
  }

  bool _shouldClearRecipeForOfflineLicense(
    LicenseVerificationResult result,
  ) {
    return result.status == LicenseVerificationStatus.expired;
  }

  Future<void> _clearRecipeStorage() async {
    if (_savedRegex.isEmpty && _settingsRepository.load().recipePattern.isEmpty) {
      return;
    }
    await _settingsRepository.clearRecipe();
  }

  String _appleScriptStringLiteral(String value) {
    return '"${value.replaceAll('\\', '\\\\').replaceAll('"', r'\"')}"';
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

  void _appendIncomingChunk(
    String chunk,
    int byteCount, {
    required String sourceLabel,
  }) {
    if (chunk.isEmpty) {
      return;
    }

    _networkAccumulator += chunk;
    if (_networkAccumulator.length > AppConfig.maxScaleAccumulatorCharacters) {
      _networkAccumulator = _networkAccumulator.substring(
        _networkAccumulator.length - AppConfig.maxScaleAccumulatorCharacters,
      );
    }
    _bytesReceived += byteCount;

    final ignoredNote = _serialIgnoredBytes > 0
        ? ' | Bytes ignorados: $_serialIgnoredBytes'
        : '';
    _networkDiagnostics =
        'Polling enviados: $_pollRequestsSent | Bytes útiles recibidos: $_bytesReceived | Último bloque $sourceLabel: $byteCount bytes$ignoredNote';
    _scheduleTelemetryRefresh();

    _processAccumulatedData();
  }

  void _scheduleTelemetryRefresh() {
    if (!mounted || _telemetryRefreshTimer?.isActive == true) {
      return;
    }

    _telemetryRefreshTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() {});
      }
    });
  }

  String _activeDeviceLabel() {
    if (_selectedConnectionType == ConnectionType.ethernet) {
      return 'Ethernet $_deviceIp:$_devicePort';
    }
    final portName = _serialPortName.isEmpty ? 'sin puerto' : _serialPortName;
    final parity = _parityLabels[_serialParity] ?? _serialParity;
    final flowControl =
        _flowControlLabels[_serialFlowControl] ?? _serialFlowControl;
    return 'RS-232 $portName | $_serialBaudRate $_serialDataBits-$parity-$_serialStopBits | Flujo: $flowControl';
  }

  Future<void> _writeWeightToCursor(String weightToType) async {
    if (_isDemoExpired) {
      return;
    }

    final String timestampCurrent = _getCurrentTimestamp();

    final String currentPrefix = _prefixController.text.replaceAll(
      '{AHORA}',
      timestampCurrent,
    );
    final String currentSuffix = _suffixController.text.replaceAll(
      '{AHORA}',
      timestampCurrent,
    );

    if (Platform.isMacOS) {
      try {
        await Clipboard.setData(ClipboardData(text: weightToType));
        final String prefixScript = _parseKeysToAppleScript(currentPrefix);
        final String suffixScript = _parseKeysToAppleScript(currentSuffix);
        final process = await Process.start('osascript', []);
        final String fullScript =
            '''
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
        await _windowsKeyboardChannel
            .invokeMethod<void>('sendPasteSequence', <String, String>{
              'prefix': currentPrefix,
              'suffix': currentSuffix,
            })
            .timeout(const Duration(seconds: 2));

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
      _socket = await Socket.connect(
        _deviceIp,
        _devicePort,
        timeout: const Duration(seconds: 4),
      );
      _isConnected = true;
      _networkAccumulator = '';
      _pollRequestsSent = 0;
      _bytesReceived = 0;
      _serialIgnoredBytes = 0;

      if (mounted) {
        setState(() {
          _uiStatusMessage = 'Conectado. Controlando flujo activamente.';
          _networkDiagnostics =
              'Socket conectado. Esperando respuesta del indicador...';
        });
      }

      _pollingTimer = Timer.periodic(const Duration(milliseconds: 500), (
        timer,
      ) async {
        if (_isConnected && !_isTyping && !_isPollingIndicator) {
          _isPollingIndicator = true;
          try {
            _socket?.write('P\r\n');
            await _socket?.flush();
            _pollRequestsSent++;
            _networkDiagnostics =
                'Polling enviados: $_pollRequestsSent | Bytes recibidos: $_bytesReceived';
            _scheduleTelemetryRefresh();
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
      _handleDisconnect(
        'Seleccione un puerto RS-232 antes de conectar.',
        false,
      );
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
        _handleDisconnect(
          'No se pudo abrir $_serialPortName: ${error?.message ?? 'error desconocido'}',
          false,
        );
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
          _networkDiagnostics =
              'Puerto serial abierto. Esperando datos del indicador...';
        });
      }

      _serialSubscription = _serialReader!.stream.listen(
        (Uint8List data) {
          final cleanedChunk = _cleanSerialChunk(data);
          if (cleanedChunk.ignoredBytes > 0) {
            _serialIgnoredBytes += cleanedChunk.ignoredBytes;
          }

          if (cleanedChunk.text.isEmpty) {
            _networkDiagnostics =
                'RS-232 escuchando | Bytes útiles recibidos: $_bytesReceived | Bytes ignorados: $_serialIgnoredBytes';
            _scheduleTelemetryRefresh();
            return;
          }

          if (cleanedChunk.ignoredBytes > 0) {
            _networkDiagnostics =
                'RS-232 escuchando | Bytes útiles recibidos: $_bytesReceived | Bytes ignorados: $_serialIgnoredBytes';
            _scheduleTelemetryRefresh();
          }

          _appendIncomingChunk(
            cleanedChunk.text,
            data.length - cleanedChunk.ignoredBytes,
            sourceLabel: 'RS-232',
          );
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

    _receivedDataLog.add(
      RawDataLogEntry(rawData: _networkAccumulator, receivedAt: DateTime.now()),
    );
    _receptionSequence++;
    if (_receivedDataLog.length > 3) {
      _receivedDataLog.removeAt(0);
    }
    _scheduleTelemetryRefresh();

    if (_savedRegex.isNotEmpty) {
      final reading = ReadingParser.parse(
        _networkAccumulator,
        pattern: _savedRegex,
        expectedValue: _expectedValue,
      );
      if (reading != null) {
        final nuevoPesoOriginal = reading.formattedWeight;
        _networkAccumulator = '';

        final parsedWeight = reading.numericValue;

        if (parsedWeight != null && parsedWeight == 0.0) {
          _cleanWeightDisplay =
              '$nuevoPesoOriginal ${_selectedInputUnit.label}';
          _scheduleTelemetryRefresh();
          return;
        }

        String pesoFinalAInyectar = nuevoPesoOriginal;
        if (parsedWeight != null) {
          final double valorConvertido = WeightConverter.convert(
            parsedWeight,
            from: _selectedInputUnit,
            to: _selectedOutputUnit,
          );
          final valorString = valorConvertido.toStringAsFixed(
            reading.decimalPlaces,
          );
          pesoFinalAInyectar = ReadingParser.formatWeight(
            valorString,
            expectedValue: _expectedValue,
          );
        }

        final now = DateTime.now();
        if (_lastTypedTime == null ||
            now.difference(_lastTypedTime!) >
                const Duration(milliseconds: 1500)) {
          _isTyping = true;
          _lastTypedTime = now;

          _cleanWeightDisplay =
              '$pesoFinalAInyectar ${_selectedOutputUnit.label}';
          _scheduleTelemetryRefresh();

          await _writeWeightToCursor(pesoFinalAInyectar);
          _isTyping = false;
        }
      }
    } else {
      _networkAccumulator = '';
    }
  }

  void _handleDisconnect([
    String reason = 'Fuera de línea. Reintentando...',
    bool shouldReconnect = true,
  ]) {
    final allowReconnect =
        shouldReconnect && !_manualDisconnectRequested && !_isDemoExpired;
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
        _networkDiagnostics =
            'Desconectado. $reason | Polling enviados: $_pollRequestsSent | Bytes recibidos: $_bytesReceived';
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
    final licensePayload = _offlineLicenseResult?.payload;
    return Scaffold(
      appBar: AppBar(
        title: const PonderaHeader(),
        actions: [
          IconButton(
            tooltip: 'Abrir manual de ayuda',
            onPressed: _openUserManual,
            icon: const Icon(Icons.help_outline),
          ),
          PonderaThemeSelector(
            themeMode: widget.themeMode,
            onChanged: widget.onThemeModeChanged,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CurrentWeightPanel(weightDisplay: _cleanWeightDisplay),
              const SizedBox(height: 10),
              ConnectionStatusPanel(
                activeDeviceLabel: _activeDeviceLabel(),
                uiStatusMessage: _uiStatusMessage,
                isConnected: showingConnected,
                isInteractionBlocked: _isDemoExpired,
                onToggleConnection: showingConnected ? _disconnect : _connect,
              ),
              const SizedBox(height: 10),
              RawDataLogPanel(
                entries: _receivedDataLog,
                receptionSequence: _receptionSequence,
              ),
              const SizedBox(height: 10),
              ConnectionDiagnosticsPanel(
                networkDiagnostics: _networkDiagnostics,
              ),
              const SizedBox(height: 10),
              LicenseStatusPanel(
                statusMessage: _demoStatusMessage,
                isExpired: _isDemoExpired,
                customerDetails: licensePayload == null
                    ? null
                    : '${licensePayload.customerName} · ${licensePayload.siteName} · ${licensePayload.city}',
                deviceDetails: licensePayload == null
                    ? null
                    : '${licensePayload.deviceLabel} · Licencia ${licensePayload.licenseId}',
                showResetDemoAction:
                    kDebugMode &&
                    _isDemoExpired &&
                    _offlineLicenseResult?.status ==
                        LicenseVerificationStatus.missing,
                onResetDemo: _resetDemoForDevelopment,
                onGenerateActivationRequest: _generateActivationRequest,
                onImportLicense: _importOfflineLicense,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(
                    Icons.tune,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Configuración',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ConnectionSettingsPanel(
                selectedConnectionType: _selectedConnectionType,
                isConnected: showingConnected,
                ipController: _ipController,
                portController: _portController,
                serialPortController: _serialPortController,
                serialPortName: _serialPortName,
                availableSerialPorts: _availableSerialPorts,
                serialBaudRate: _serialBaudRate,
                serialDataBits: _serialDataBits,
                serialStopBits: _serialStopBits,
                serialParity: _serialParity,
                serialFlowControl: _serialFlowControl,
                baudRates: _baudRates,
                dataBitsOptions: _dataBitsOptions,
                stopBitsOptions: _stopBitsOptions,
                parityLabels: _parityLabels,
                flowControlLabels: _flowControlLabels,
                onConnectionTypeChanged: _saveConnectionType,
                onSaveNetwork: _saveNetworkConfig,
                onSerialPortNameChanged: (value) {
                  _serialPortName = value.trim();
                },
                onDetectedSerialPortChanged: (value) {
                  setState(() {
                    _serialPortName = value;
                    _serialPortController.text = value;
                  });
                },
                onRefreshSerialPorts: _refreshSerialPorts,
                onSerialBaudRateChanged: (value) {
                  setState(() => _serialBaudRate = value);
                },
                onSerialDataBitsChanged: (value) {
                  setState(() => _serialDataBits = value);
                },
                onSerialStopBitsChanged: (value) {
                  setState(() => _serialStopBits = value);
                },
                onSerialParityChanged: (value) {
                  setState(() => _serialParity = value);
                },
                onSerialFlowControlChanged: (value) {
                  setState(() => _serialFlowControl = value);
                },
                onSaveSerial: _saveSerialConfig,
              ),
              const SizedBox(height: 10),
              UnitsSettingsPanel(
                selectedInputUnit: _selectedInputUnit,
                selectedOutputUnit: _selectedOutputUnit,
                inputUnits: _inputUnits,
                outputUnits: _outputUnits,
                onInputUnitChanged: (unit) {
                  setState(() {
                    _selectedInputUnit = unit;
                    _saveUnitsConfig();
                  });
                },
                onOutputUnitChanged: (unit) {
                  setState(() {
                    _selectedOutputUnit = unit;
                    _saveUnitsConfig();
                  });
                },
              ),
              const SizedBox(height: 10),
              KeyboardSettingsPanel(
                prefixController: _prefixController,
                suffixController: _suffixController,
                onSave: _saveKeyModifiers,
              ),
              const SizedBox(height: 10),
              RecipeActionsPanel(
                savedRegex: _savedRegex,
                isEnabled: !_isDemoExpired,
                isProcessing: _isSendingToN8n,
                onSendToN8n: _sendToN8nIa,
                onClearRecipe: _clearRecipe,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
