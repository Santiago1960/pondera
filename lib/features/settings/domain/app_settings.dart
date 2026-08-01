class AppSettings {
  const AppSettings({
    required this.connectionType,
    required this.deviceIp,
    required this.devicePort,
    required this.serialPortName,
    required this.serialBaudRate,
    required this.serialDataBits,
    required this.serialStopBits,
    required this.serialParity,
    required this.serialFlowControl,
    required this.recipePattern,
    required this.expectedValue,
    required this.keyboardPrefix,
    required this.keyboardSuffix,
    required this.inputUnit,
    required this.outputUnit,
    required this.captureMode,
    required this.captureStableMilliseconds,
    required this.captureRangeEnabled,
    required this.captureMinimumWeight,
    required this.captureMaximumWeight,
    required this.captureRangeUnit,
  });

  final String connectionType;
  final String deviceIp;
  final int devicePort;
  final String serialPortName;
  final int serialBaudRate;
  final int serialDataBits;
  final int serialStopBits;
  final String serialParity;
  final String serialFlowControl;
  final String recipePattern;
  final String expectedValue;
  final String keyboardPrefix;
  final String keyboardSuffix;
  final String inputUnit;
  final String outputUnit;
  final String captureMode;
  final int captureStableMilliseconds;
  final bool captureRangeEnabled;
  final double? captureMinimumWeight;
  final double? captureMaximumWeight;
  final String captureRangeUnit;
}
