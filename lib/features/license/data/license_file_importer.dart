import 'package:file_selector/file_selector.dart';

class LicenseFileImporter {
  const LicenseFileImporter();

  Future<String?> selectAndRead() async {
    const typeGroup = XTypeGroup(
      label: 'Licencia Pondera',
      extensions: ['pondera-license'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    return file?.readAsString();
  }
}
