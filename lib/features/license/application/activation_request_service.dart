import '../data/installation_identity_repository.dart';
import '../domain/license_activation_request.dart';
import '../domain/license_identifier_generator.dart';

class ActivationRequestService {
  ActivationRequestService(
    this._identityRepository, {
    LicenseIdentifierGenerator? identifierGenerator,
  }) : _identifierGenerator =
           identifierGenerator ?? LicenseIdentifierGenerator();

  final InstallationIdentityRepository _identityRepository;
  final LicenseIdentifierGenerator _identifierGenerator;

  Future<LicenseActivationRequest> create({
    required String platform,
    required String appVersion,
    required String customerName,
    required String siteName,
    required String city,
    required String deviceLabel,
    String? assetTag,
    DateTime? now,
  }) async {
    return LicenseActivationRequest(
      requestId: _identifierGenerator.createRequestId(),
      installationId: await _identityRepository.getOrCreate(),
      product: 'pondera',
      platform: platform,
      appVersion: appVersion,
      customerName: customerName.trim(),
      siteName: siteName.trim(),
      city: city.trim(),
      deviceLabel: deviceLabel.trim(),
      assetTag: _optionalTrim(assetTag),
      createdAt: (now ?? DateTime.now()).toUtc(),
    );
  }
}

String? _optionalTrim(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
