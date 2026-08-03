class AppConfig {
  const AppConfig._();

  static const n8nRequestTimeout = Duration(seconds: 45);
  static const maxScaleAccumulatorCharacters = 8192;
  static const scalePollingInterval = Duration(milliseconds: 500);
  static const scaleResponseTimeout = Duration(seconds: 2);
}
