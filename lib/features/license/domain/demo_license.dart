enum DemoLicenseStatus { active, expired, clockTampered }

class DemoLicense {
  const DemoLicense({required this.expirationDate, required this.status});

  final DateTime expirationDate;
  final DemoLicenseStatus status;

  bool get isExpired => status != DemoLicenseStatus.active;

  String get statusMessage {
    return switch (status) {
      DemoLicenseStatus.active =>
        'Demo vigente hasta el ${_formatDate(expirationDate)}.',
      DemoLicenseStatus.expired =>
        'Demo vencida el ${_formatDate(expirationDate)}.',
      DemoLicenseStatus.clockTampered =>
        'Demo bloqueada: se detectó retroceso de fecha del sistema.',
    };
  }

  static DemoLicense evaluate({
    required DateTime now,
    required DateTime expirationDate,
    required bool locked,
    required DateTime? lastRun,
  }) {
    final clockTampered =
        lastRun != null &&
        now.isBefore(lastRun.subtract(const Duration(minutes: 5)));

    if (clockTampered) {
      return DemoLicense(
        expirationDate: expirationDate,
        status: DemoLicenseStatus.clockTampered,
      );
    }
    if (locked || !now.isBefore(expirationDate)) {
      return DemoLicense(
        expirationDate: expirationDate,
        status: DemoLicenseStatus.expired,
      );
    }
    return DemoLicense(
      expirationDate: expirationDate,
      status: DemoLicenseStatus.active,
    );
  }

  static String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }
}
