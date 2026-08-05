import 'weight_converter.dart';
import 'weight_unit.dart';

enum WeightCaptureMode { indicatorPrint, keyboardF12, automaticStable }

extension WeightCaptureModeInput on WeightCaptureMode {
  bool get requiresContinuousInput => this != WeightCaptureMode.indicatorPrint;
}

enum WeightCaptureOutcome {
  none,
  capture,
  zeroRejected,
  outOfRange,
  waitingForZero,
  noReading,
  invalidConfiguration,
  continuousInputDetected,
}

class WeightCaptureRange {
  const WeightCaptureRange.unrestricted()
    : enabled = false,
      minimum = null,
      maximum = null,
      unit = WeightUnit.kilogram;

  const WeightCaptureRange.restricted({
    required this.minimum,
    required this.maximum,
    required this.unit,
  }) : enabled = true;

  final bool enabled;
  final double? minimum;
  final double? maximum;
  final WeightUnit unit;

  String? get validationError {
    if (!enabled) {
      return null;
    }
    if (minimum == null || maximum == null) {
      return 'El rango de peso está incompleto.';
    }
    if (!minimum!.isFinite || !maximum!.isFinite) {
      return 'Los límites del rango deben ser números finitos.';
    }
    if (minimum! <= 0) {
      return 'El peso mínimo debe ser mayor que cero.';
    }
    if (maximum! < minimum!) {
      return 'El peso máximo debe ser mayor o igual que el mínimo.';
    }
    return null;
  }

  double convertedValue(double value, WeightUnit sourceUnit) {
    return WeightConverter.convert(value, from: sourceUnit, to: unit);
  }

  bool accepts(double value, WeightUnit sourceUnit) {
    if (!enabled) {
      return true;
    }
    if (validationError != null) {
      return false;
    }

    final converted = convertedValue(value, sourceUnit);
    return converted >= minimum! && converted <= maximum!;
  }
}

class WeightCaptureConfiguration {
  const WeightCaptureConfiguration({
    this.mode = WeightCaptureMode.indicatorPrint,
    this.stableDuration = const Duration(seconds: 1),
    this.range = const WeightCaptureRange.unrestricted(),
  });

  static const minimumStableDuration = Duration(milliseconds: 100);
  static const maximumStableDuration = Duration(seconds: 60);

  final WeightCaptureMode mode;
  final Duration stableDuration;
  final WeightCaptureRange range;

  String? get validationError {
    final rangeError = range.validationError;
    if (rangeError != null) {
      return rangeError;
    }
    if (mode == WeightCaptureMode.automaticStable &&
        (stableDuration < minimumStableDuration ||
            stableDuration > maximumStableDuration)) {
      return 'El tiempo estable debe estar entre 100 y 60000 milisegundos.';
    }
    return null;
  }
}

class WeightCaptureReading {
  const WeightCaptureReading({
    required this.value,
    required this.unit,
    required this.captureText,
  });

  final double value;
  final WeightUnit unit;
  final String captureText;
}

class WeightCaptureDecision {
  const WeightCaptureDecision._({
    required this.outcome,
    this.reading,
    this.evaluatedWeight,
    this.configurationError,
  });

  static const none = WeightCaptureDecision._(
    outcome: WeightCaptureOutcome.none,
  );

  const WeightCaptureDecision.capture(WeightCaptureReading reading)
    : this._(outcome: WeightCaptureOutcome.capture, reading: reading);

  const WeightCaptureDecision.rejected(
    WeightCaptureOutcome outcome, {
    WeightCaptureReading? reading,
    double? evaluatedWeight,
    String? configurationError,
  }) : this._(
         outcome: outcome,
         reading: reading,
         evaluatedWeight: evaluatedWeight,
         configurationError: configurationError,
       );

  final WeightCaptureOutcome outcome;
  final WeightCaptureReading? reading;
  final double? evaluatedWeight;
  final String? configurationError;

  bool get shouldCapture => outcome == WeightCaptureOutcome.capture;
}

class WeightCaptureController {
  WeightCaptureController({
    WeightCaptureConfiguration configuration =
        const WeightCaptureConfiguration(),
  }) : _configuration = configuration,
       _waitingForZero = configuration.mode != WeightCaptureMode.indicatorPrint;

  static const zeroTolerance = 0.0000001;
  static const manualDebounce = Duration(milliseconds: 1500);
  static const continuousInputWindow = Duration(seconds: 2);
  static const continuousInputThreshold = 4;

  WeightCaptureConfiguration _configuration;
  WeightCaptureReading? _latestReading;
  DateTime? _lastManualCaptureAt;
  DateTime? _stableSince;
  String? _stableCandidate;
  bool _waitingForZero;
  bool _outOfRangeReported = false;
  bool _configurationErrorReported = false;
  DateTime? _manualBurstStartedAt;
  DateTime? _lastManualReadingAt;
  int _manualBurstCount = 0;
  bool _continuousInputDetected = false;

  WeightCaptureConfiguration get configuration => _configuration;
  WeightCaptureReading? get latestReading => _latestReading;
  bool get waitingForZero => _waitingForZero;

  void updateConfiguration(WeightCaptureConfiguration configuration) {
    _configuration = configuration;
    _latestReading = null;
    _lastManualCaptureAt = null;
    _waitingForZero = configuration.mode != WeightCaptureMode.indicatorPrint;
    _resetManualInputState();
    _resetAutomaticState();
  }

  void clearReading() {
    _latestReading = null;
    _resetAutomaticState();
  }

  WeightCaptureDecision onReading(
    WeightCaptureReading reading, {
    required DateTime receivedAt,
  }) {
    _latestReading = reading;

    if (_configuration.mode == WeightCaptureMode.indicatorPrint) {
      final continuousInputDecision = _detectContinuousManualInput(
        reading,
        receivedAt,
      );
      if (continuousInputDecision != null) {
        return continuousInputDecision;
      }
    }

    if (_isZero(reading.value)) {
      _resetAutomaticState();
      if (_configuration.mode != WeightCaptureMode.indicatorPrint) {
        _waitingForZero = false;
        return WeightCaptureDecision.none;
      }
      return WeightCaptureDecision.rejected(
        WeightCaptureOutcome.zeroRejected,
        reading: reading,
      );
    }

    return switch (_configuration.mode) {
      WeightCaptureMode.indicatorPrint => _handleIndicatorPrint(
        reading,
        receivedAt,
      ),
      WeightCaptureMode.keyboardF12 => WeightCaptureDecision.none,
      WeightCaptureMode.automaticStable => _handleAutomatic(
        reading,
        receivedAt,
      ),
    };
  }

  WeightCaptureDecision onF12Pressed() {
    if (_configuration.mode != WeightCaptureMode.keyboardF12) {
      return WeightCaptureDecision.none;
    }

    final reading = _latestReading;
    if (reading == null) {
      return const WeightCaptureDecision.rejected(
        WeightCaptureOutcome.noReading,
      );
    }
    if (_isZero(reading.value)) {
      return WeightCaptureDecision.rejected(
        WeightCaptureOutcome.zeroRejected,
        reading: reading,
      );
    }
    if (_waitingForZero) {
      return WeightCaptureDecision.rejected(
        WeightCaptureOutcome.waitingForZero,
        reading: reading,
      );
    }

    final rejection = _validateReading(reading);
    if (rejection != null) {
      return rejection;
    }

    _waitingForZero = true;
    return WeightCaptureDecision.capture(reading);
  }

  WeightCaptureDecision _handleIndicatorPrint(
    WeightCaptureReading reading,
    DateTime receivedAt,
  ) {
    final rejection = _validateReading(reading);
    if (rejection != null) {
      return rejection;
    }
    if (_lastManualCaptureAt != null &&
        receivedAt.difference(_lastManualCaptureAt!) <= manualDebounce) {
      return WeightCaptureDecision.none;
    }

    _lastManualCaptureAt = receivedAt;
    return WeightCaptureDecision.capture(reading);
  }

  WeightCaptureDecision _handleAutomatic(
    WeightCaptureReading reading,
    DateTime receivedAt,
  ) {
    if (_waitingForZero) {
      return WeightCaptureDecision.none;
    }

    final configurationError = _configuration.validationError;
    if (configurationError != null) {
      if (_configurationErrorReported) {
        return WeightCaptureDecision.none;
      }
      _configurationErrorReported = true;
      return WeightCaptureDecision.rejected(
        WeightCaptureOutcome.invalidConfiguration,
        reading: reading,
        configurationError: configurationError,
      );
    }
    _configurationErrorReported = false;

    final evaluatedWeight = _configuration.range.convertedValue(
      reading.value,
      reading.unit,
    );
    final isInRange = _configuration.range.accepts(reading.value, reading.unit);
    if (isInRange) {
      _outOfRangeReported = false;
    }
    final candidate = '${reading.captureText}|$isInRange';
    if (_stableCandidate != candidate) {
      _stableCandidate = candidate;
      _stableSince = receivedAt;
      return WeightCaptureDecision.none;
    }
    if (receivedAt.difference(_stableSince!) < _configuration.stableDuration) {
      return WeightCaptureDecision.none;
    }

    if (!isInRange) {
      if (_outOfRangeReported) {
        return WeightCaptureDecision.none;
      }
      _outOfRangeReported = true;
      return WeightCaptureDecision.rejected(
        WeightCaptureOutcome.outOfRange,
        reading: reading,
        evaluatedWeight: evaluatedWeight,
      );
    }

    _outOfRangeReported = false;
    _waitingForZero = true;
    _stableCandidate = null;
    _stableSince = null;
    return WeightCaptureDecision.capture(reading);
  }

  WeightCaptureDecision? _validateReading(WeightCaptureReading reading) {
    final configurationError = _configuration.validationError;
    if (configurationError != null) {
      return WeightCaptureDecision.rejected(
        WeightCaptureOutcome.invalidConfiguration,
        reading: reading,
        configurationError: configurationError,
      );
    }
    if (!_configuration.range.accepts(reading.value, reading.unit)) {
      return WeightCaptureDecision.rejected(
        WeightCaptureOutcome.outOfRange,
        reading: reading,
        evaluatedWeight: _configuration.range.convertedValue(
          reading.value,
          reading.unit,
        ),
      );
    }
    return null;
  }

  bool _isZero(double value) => value.abs() < zeroTolerance;

  WeightCaptureDecision? _detectContinuousManualInput(
    WeightCaptureReading reading,
    DateTime receivedAt,
  ) {
    final previousReadingAt = _lastManualReadingAt;
    _lastManualReadingAt = receivedAt;
    if (previousReadingAt != null &&
        receivedAt.difference(previousReadingAt) > continuousInputWindow) {
      _resetManualInputState();
      _lastManualReadingAt = receivedAt;
    }

    if (_continuousInputDetected) {
      return WeightCaptureDecision.none;
    }

    final burstStartedAt = _manualBurstStartedAt;
    if (burstStartedAt == null ||
        receivedAt.difference(burstStartedAt) > continuousInputWindow) {
      _manualBurstStartedAt = receivedAt;
      _manualBurstCount = 1;
      return null;
    }

    _manualBurstCount++;
    if (_manualBurstCount < continuousInputThreshold) {
      return null;
    }

    _continuousInputDetected = true;
    return WeightCaptureDecision.rejected(
      WeightCaptureOutcome.continuousInputDetected,
      reading: reading,
    );
  }

  void _resetManualInputState() {
    _manualBurstStartedAt = null;
    _lastManualReadingAt = null;
    _manualBurstCount = 0;
    _continuousInputDetected = false;
  }

  void _resetAutomaticState() {
    _stableCandidate = null;
    _stableSince = null;
    _outOfRangeReported = false;
    _configurationErrorReported = false;
  }
}
