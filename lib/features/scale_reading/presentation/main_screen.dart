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
import '../../connection/domain/scale_polling_state.dart';
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
import '../domain/weight_capture_controller.dart';
import '../domain/weight_converter.dart';
import '../domain/weight_unit.dart';
import 'current_weight_panel.dart';
import 'raw_data_log_panel.dart';
import 'units_settings_panel.dart';
import 'weight_capture_settings_panel.dart';

const MethodChannel _windowsKeyboardChannel = MethodChannel(
  'pondera/windows_keyboard',
);
const MethodChannel _operatorAlertChannel = MethodChannel(
  'pondera/operator_alert',
);
const MethodChannel _weightCaptureHotkeyChannel = MethodChannel(
  'pondera/weight_capture_hotkey',
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
  static const _briefConfirmationDuration = Duration(milliseconds: 800);

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
  bool _captureStatusIsError = false;

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
  WeightCaptureMode _selectedCaptureMode = WeightCaptureMode.indicatorPrint;
  bool _captureRangeEnabled = false;
  WeightUnit _captureRangeUnit = WeightUnit.kilogram;
  final WeightCaptureController _weightCaptureController =
      WeightCaptureController();
  final ScalePollingState _scalePollingState = ScalePollingState(
    responseTimeout: AppConfig.scaleResponseTimeout,
  );
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
  final TextEditingController _captureMinimumController =
      TextEditingController();
  final TextEditingController _captureMaximumController =
      TextEditingController();
  final TextEditingController _captureStableMillisecondsController =
      TextEditingController(text: '1000');

  @override
  void initState() {
    super.initState();
    _weightCaptureHotkeyChannel.setMethodCallHandler(
      _handleWeightCaptureHotkeyCall,
    );
    _initialize();
  }

  @override
  void dispose() {
    _demoTimer?.cancel();
    _telemetryRefreshTimer?.cancel();
    unawaited(_setF12HotkeyEnabled(false));
    _weightCaptureHotkeyChannel.setMethodCallHandler(null);
    _disconnect();
    _ipController.dispose();
    _portController.dispose();
    _serialPortController.dispose();
    _prefixController.dispose();
    _suffixController.dispose();
    _captureMinimumController.dispose();
    _captureMaximumController.dispose();
    _captureStableMillisecondsController.dispose();
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
      _selectedCaptureMode = _availableCaptureMode(settings.captureMode);
      _captureRangeEnabled = settings.captureRangeEnabled;
      _captureRangeUnit =
          WeightUnit.fromCode(settings.captureRangeUnit) ?? WeightUnit.kilogram;
      _captureMinimumController.text =
          settings.captureMinimumWeight?.toString() ?? '';
      _captureMaximumController.text =
          settings.captureMaximumWeight?.toString() ?? '';
      final stableMilliseconds = settings.captureStableMilliseconds;
      _captureStableMillisecondsController.text =
          stableMilliseconds >= 100 && stableMilliseconds <= 60000
          ? stableMilliseconds.toString()
          : '1000';

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
    _weightCaptureController.updateConfiguration(
      _currentWeightCaptureConfiguration(),
    );
    final hotkeyReady = await _setF12HotkeyEnabled(
      _selectedCaptureMode == WeightCaptureMode.keyboardF12,
    );
    if (!hotkeyReady && mounted) {
      setState(() {
        _uiStatusMessage =
            'No se pudo activar F12. Revise si otra aplicación usa esa tecla.';
        _captureStatusIsError = true;
      });
      unawaited(_showOperatorAlert(message: _uiStatusMessage));
    }
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
        if (_shouldClearRecipeForLicenseState(
          offlineLicense: updatedLicense,
          demoLicense: null,
        )) {
          await _clearRecipeStorage();
        }
        _disconnect();
      }
      setState(() {
        if (_isDemoExpired) {
          _savedRegex = '';
          _expectedValue = '';
          _cleanWeightDisplay =
              updatedLicense.status == LicenseVerificationStatus.expired
              ? 'Licencia vencida'
              : 'Licencia inválida';
          _uiStatusMessage = updatedLicense.message;
          _networkDiagnostics =
              'La licencia está bloqueada. No se abrirá conexión.';
        } else if (_cleanWeightDisplay == 'Licencia vencida' ||
            _cleanWeightDisplay == 'Licencia inválida') {
          _cleanWeightDisplay = _savedRegex.isEmpty ? 'Sin receta' : '---';
          if (!_isConnected) {
            _uiStatusMessage = 'Licencia válida. Lista para continuar.';
          }
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
    _showBriefConfirmation('Configuración de red guardada');
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

    _showBriefConfirmation('Configuración RS-232 guardada');
  }

  void _saveKeyModifiers() async {
    await _settingsRepository.saveKeyboardCommands(
      prefix: _prefixController.text,
      suffix: _suffixController.text,
    );
    _showBriefConfirmation('Comandos de teclado guardados');
  }

  void _saveUnitsConfig() async {
    await _settingsRepository.saveUnits(
      inputUnit: _selectedInputUnit.code,
      outputUnit: _selectedOutputUnit.code,
    );
  }

  WeightCaptureMode _availableCaptureMode(String storedMode) {
    return switch (storedMode) {
      'indicatorPrint' => WeightCaptureMode.indicatorPrint,
      'keyboardF12' => WeightCaptureMode.keyboardF12,
      'automaticStable' => WeightCaptureMode.automaticStable,
      _ => WeightCaptureMode.indicatorPrint,
    };
  }

  double? _parseCaptureWeight(String value) {
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }

  WeightCaptureConfiguration _currentWeightCaptureConfiguration() {
    final stableMilliseconds =
        int.tryParse(_captureStableMillisecondsController.text) ?? 1000;
    final range = _captureRangeEnabled
        ? WeightCaptureRange.restricted(
            minimum: _parseCaptureWeight(_captureMinimumController.text),
            maximum: _parseCaptureWeight(_captureMaximumController.text),
            unit: _captureRangeUnit,
          )
        : const WeightCaptureRange.unrestricted();

    return WeightCaptureConfiguration(
      mode: _selectedCaptureMode,
      stableDuration: Duration(milliseconds: stableMilliseconds),
      range: range,
    );
  }

  void _saveWeightCaptureConfig() async {
    final configuration = _currentWeightCaptureConfiguration();
    final validationError = configuration.validationError;
    if (validationError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }

    if (configuration.mode == WeightCaptureMode.keyboardF12 &&
        !await _setF12HotkeyEnabled(true)) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo activar F12. Revise si otra aplicación usa esa tecla.',
          ),
        ),
      );
      return;
    }

    final minimumWeight = _parseCaptureWeight(_captureMinimumController.text);
    final maximumWeight = _parseCaptureWeight(_captureMaximumController.text);
    _weightCaptureController.updateConfiguration(configuration);
    await _settingsRepository.saveWeightCapture(
      mode: configuration.mode.name,
      stableMilliseconds: configuration.stableDuration.inMilliseconds,
      rangeEnabled: _captureRangeEnabled,
      minimumWeight: minimumWeight,
      maximumWeight: maximumWeight,
      rangeUnit: _captureRangeUnit.code,
    );
    if (configuration.mode != WeightCaptureMode.keyboardF12) {
      await _setF12HotkeyEnabled(false);
    }

    _showBriefConfirmation('Configuración de captura guardada');
  }

  Future<void> _changeWeightCaptureMode(WeightCaptureMode mode) async {
    final activeConfiguration = _weightCaptureController.configuration;
    if (mode == activeConfiguration.mode) {
      return;
    }

    if (mode == WeightCaptureMode.keyboardF12 &&
        !await _setF12HotkeyEnabled(true)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo activar F12. Revise si otra aplicación usa esa tecla.',
            ),
          ),
        );
      }
      return;
    }

    _weightCaptureController.updateConfiguration(
      WeightCaptureConfiguration(
        mode: mode,
        stableDuration: activeConfiguration.stableDuration,
        range: activeConfiguration.range,
      ),
    );
    await _settingsRepository.saveCaptureMode(mode.name);
    if (mode != WeightCaptureMode.keyboardF12) {
      await _setF12HotkeyEnabled(false);
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _selectedCaptureMode = mode;
      _captureStatusIsError = false;
      _uiStatusMessage = switch (mode) {
        WeightCaptureMode.indicatorPrint => 'Modo Print del indicador activo.',
        WeightCaptureMode.keyboardF12 =>
          'Modo F12 activo. Esperando que la balanza pase por cero.',
        WeightCaptureMode.automaticStable =>
          'Modo automático activo. Esperando que la balanza pase por cero.',
      };
    });
    _showBriefConfirmation('Modo de captura actualizado');
  }

  void _showBriefConfirmation(String message) {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message), duration: _briefConfirmationDuration),
    );
  }

  Future<void> _showOperatorAlert({
    String title = 'Peso no registrado',
    required String message,
  }) async {
    if (Platform.isMacOS || Platform.isWindows) {
      try {
        await _operatorAlertChannel.invokeMethod<void>('show', {
          'title': title,
          'message': message,
          'durationMs': 4000,
        });
        return;
      } catch (error) {
        debugPrint('No se pudo mostrar la alerta global: $error');
      }
    }

    if (!mounted) {
      return;
    }
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: colorScheme.error,
        content: Text(message, style: TextStyle(color: colorScheme.onError)),
      ),
    );
  }

  Future<void> _handleWeightCaptureHotkeyCall(MethodCall call) async {
    if (call.method == 'pressed') {
      await _handleF12Pressed();
    }
  }

  Future<bool> _setF12HotkeyEnabled(bool enabled) async {
    if (!Platform.isMacOS && !Platform.isWindows) {
      return true;
    }
    try {
      await _weightCaptureHotkeyChannel.invokeMethod<void>(
        'setEnabled',
        enabled,
      );
      return true;
    } catch (error) {
      debugPrint(
        'No se pudo ${enabled ? 'activar' : 'desactivar'} F12: $error',
      );
      return false;
    }
  }

  Future<void> _handleF12Pressed() async {
    if (_isTyping || _isDemoExpired) {
      return;
    }
    await _applyWeightCaptureDecision(_weightCaptureController.onF12Pressed());
  }

  Future<void> _applyWeightCaptureDecision(
    WeightCaptureDecision decision, {
    String? displayText,
    String? zeroDisplayText,
  }) async {
    final capturedDisplay =
        displayText ??
        (decision.reading == null
            ? null
            : '${decision.reading!.captureText} ${_selectedOutputUnit.label}');

    if (decision.outcome == WeightCaptureOutcome.zeroRejected) {
      if (zeroDisplayText != null || capturedDisplay != null) {
        _cleanWeightDisplay = zeroDisplayText ?? capturedDisplay!;
      }
      _uiStatusMessage = 'Peso cero. No se registró.';
      _captureStatusIsError = true;
      unawaited(_showOperatorAlert(message: _uiStatusMessage));
      _scheduleTelemetryRefresh();
      return;
    }

    if (decision.outcome == WeightCaptureOutcome.outOfRange) {
      if (capturedDisplay != null) {
        _cleanWeightDisplay = capturedDisplay;
      }
      _uiStatusMessage = 'Peso fuera del rango permitido. No se registró.';
      _captureStatusIsError = true;
      final rangeMessage =
          'Peso fuera del rango ${_captureMinimumController.text} – '
          '${_captureMaximumController.text} ${_captureRangeUnit.label}. '
          'No se registró.';
      unawaited(_showOperatorAlert(message: rangeMessage));
      _scheduleTelemetryRefresh();
      return;
    }

    if (decision.outcome == WeightCaptureOutcome.invalidConfiguration) {
      _uiStatusMessage =
          decision.configurationError ??
          'La configuración de captura no es válida.';
      _captureStatusIsError = true;
      unawaited(_showOperatorAlert(message: _uiStatusMessage));
      _scheduleTelemetryRefresh();
      return;
    }

    if (decision.outcome == WeightCaptureOutcome.noReading) {
      _uiStatusMessage = 'Todavía no hay un peso disponible. No se registró.';
      _captureStatusIsError = true;
      unawaited(_showOperatorAlert(message: _uiStatusMessage));
      _scheduleTelemetryRefresh();
      return;
    }

    if (decision.outcome == WeightCaptureOutcome.waitingForZero) {
      _uiStatusMessage =
          'Retire el peso y espere que la balanza vuelva a cero.';
      _captureStatusIsError = true;
      unawaited(
        _showOperatorAlert(
          title: 'Esperando paso por cero',
          message: _uiStatusMessage,
        ),
      );
      _scheduleTelemetryRefresh();
      return;
    }

    if (decision.outcome == WeightCaptureOutcome.continuousInputDetected) {
      _uiStatusMessage =
          'El indicador envía datos continuos, pero Pondera está en modo Print manual.';
      _captureStatusIsError = true;
      unawaited(
        _showOperatorAlert(
          message:
              'Configuración incompatible: el indicador está en modo continuo y Pondera en Print manual. Cambie el indicador a envío manual o seleccione Tecla F12.',
        ),
      );
      _scheduleTelemetryRefresh();
      return;
    }

    _clearCaptureErrorState();
    if (!decision.shouldCapture || decision.reading == null) {
      return;
    }

    _isTyping = true;
    if (capturedDisplay != null) {
      _cleanWeightDisplay = capturedDisplay;
    }
    _uiStatusMessage = 'Peso registrado correctamente.';
    _scheduleTelemetryRefresh();

    try {
      await _writeWeightToCursor(decision.reading!.captureText);
    } finally {
      _isTyping = false;
    }
  }

  void _clearCaptureErrorState() {
    final hadError = _captureStatusIsError;
    _captureStatusIsError = false;
    if (hadError) {
      _scheduleTelemetryRefresh();
    }
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
      await manualFile.writeAsBytes(bytes.buffer.asUint8List(), flush: true);

      if (Platform.isMacOS) {
        await Process.run('open', [manualFile.path]);
      } else if (Platform.isWindows) {
        await Process.run('explorer.exe', [manualFile.path]);
      } else {
        throw UnsupportedError('Plataforma no soportada para abrir el manual.');
      }
    } catch (error) {
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
      'license_expires_at':
          (licensePayload?.expiresAt ?? demoLicense?.expirationDate)
              ?.toUtc()
              .toIso8601String(),
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
    } on TimeoutException {
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
    return offlineLicense.status == LicenseVerificationStatus.expired ||
        (offlineLicense.status == LicenseVerificationStatus.missing &&
            (demoLicense?.isExpired ?? false));
  }

  Future<void> _clearRecipeStorage() async {
    if (_savedRegex.isEmpty &&
        _settingsRepository.load().recipePattern.isEmpty) {
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
        await _windowsKeyboardChannel
            .invokeMethod<void>('sendWeightSequence', <String, String>{
              'prefix': currentPrefix,
              'weight': weightToType,
              'suffix': currentSuffix,
            })
            .timeout(const Duration(seconds: 2));
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
    _captureStatusIsError = false;

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
      _scalePollingState.reset();

      if (mounted) {
        setState(() {
          _uiStatusMessage = 'Conectado. Controlando flujo activamente.';
          _networkDiagnostics =
              'Socket conectado. Esperando respuesta del indicador...';
        });
      }

      _pollingTimer = Timer.periodic(AppConfig.scalePollingInterval, (
        timer,
      ) async {
        if (!_isConnected) {
          return;
        }

        final now = DateTime.now();
        if (_scalePollingState.hasTimedOut(now)) {
          _handleDisconnect('El indicador no respondió a la consulta de peso.');
          return;
        }
        if (!_scalePollingState.beginRequest(now)) {
          return;
        }

        try {
          _socket?.write('P\r\n');
          await _socket?.flush();
          _pollRequestsSent++;
          _networkDiagnostics =
              'Polling enviados: $_pollRequestsSent | Bytes recibidos: $_bytesReceived';
          _scheduleTelemetryRefresh();
        } catch (e) {
          _scalePollingState.reset();
          _handleDisconnect('Error enviando polling: $e');
        }
      });

      _socket!.listen(
        (List<int> data) {
          _scalePollingState.completeResponse();
          final String chunk = utf8.decode(data, allowMalformed: true);
          _appendIncomingChunk(chunk, data.length, sourceLabel: 'TCP');
        },
        onError: (error) {
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

          if (cleanedChunk.text.isEmpty || cleanedChunk.ignoredBytes > 0) {
            _networkDiagnostics =
                'RS-232 escuchando | Bytes útiles recibidos: $_bytesReceived | Bytes ignorados: $_serialIgnoredBytes';
            _scheduleTelemetryRefresh();
          }

          if (cleanedChunk.text.isEmpty) {
            return;
          }

          _appendIncomingChunk(
            cleanedChunk.text,
            data.length - cleanedChunk.ignoredBytes,
            sourceLabel: 'RS-232',
          );
        },
        onError: (error) {
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
    if (_networkAccumulator.isEmpty) {
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
        if (parsedWeight == null) {
          _uiStatusMessage = 'La lectura recibida no contiene un peso válido.';
          _captureStatusIsError = true;
          unawaited(_showOperatorAlert(message: _uiStatusMessage));
          _scheduleTelemetryRefresh();
          return;
        }

        final double valorConvertido = WeightConverter.convert(
          parsedWeight,
          from: _selectedInputUnit,
          to: _selectedOutputUnit,
        );
        final valorString = valorConvertido.toStringAsFixed(
          reading.decimalPlaces,
        );
        final pesoFinalAInyectar = ReadingParser.formatWeight(
          valorString,
          expectedValue: _expectedValue,
        );

        _cleanWeightDisplay =
            '$pesoFinalAInyectar ${_selectedOutputUnit.label}';
        _scheduleTelemetryRefresh();

        if (_isTyping) {
          return;
        }

        final now = DateTime.now();
        final decision = _weightCaptureController.onReading(
          WeightCaptureReading(
            value: parsedWeight,
            unit: _selectedInputUnit,
            captureText: pesoFinalAInyectar,
          ),
          receivedAt: now,
        );
        await _applyWeightCaptureDecision(
          decision,
          displayText: '$pesoFinalAInyectar ${_selectedOutputUnit.label}',
          zeroDisplayText: '$nuevoPesoOriginal ${_selectedInputUnit.label}',
        );
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
    _releaseConnectionResources();
    _captureStatusIsError = false;
    _weightCaptureController.updateConfiguration(
      _weightCaptureController.configuration,
    );

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
    _reconnectTimer?.cancel();
    _releaseConnectionResources();
    _captureStatusIsError = false;
    _weightCaptureController.updateConfiguration(
      _weightCaptureController.configuration,
    );
    if (mounted) {
      setState(() {
        _uiStatusMessage = 'Desconectado';
        _cleanWeightDisplay = '---';
        _networkDiagnostics = 'Sin actividad de enlace.';
      });
    }
  }

  void _releaseConnectionResources() {
    _pollingTimer?.cancel();
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
    _scalePollingState.reset();
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
                isError: _captureStatusIsError,
                onToggleConnection: showingConnected ? _disconnect : _connect,
              ),
              const SizedBox(height: 10),
              RawDataLogPanel(
                entries: _receivedDataLog,
                receptionSequence: _receptionSequence,
                continuousMode:
                    _selectedCaptureMode != WeightCaptureMode.indicatorPrint,
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
              WeightCaptureSettingsPanel(
                selectedMode: _selectedCaptureMode,
                rangeEnabled: _captureRangeEnabled,
                rangeUnit: _captureRangeUnit,
                minimumController: _captureMinimumController,
                maximumController: _captureMaximumController,
                stableMillisecondsController:
                    _captureStableMillisecondsController,
                onModeChanged: (mode) {
                  unawaited(_changeWeightCaptureMode(mode));
                },
                onRangeEnabledChanged: (enabled) {
                  setState(() => _captureRangeEnabled = enabled);
                },
                onRangeUnitChanged: (unit) {
                  setState(() => _captureRangeUnit = unit);
                },
                onSave: _saveWeightCaptureConfig,
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
