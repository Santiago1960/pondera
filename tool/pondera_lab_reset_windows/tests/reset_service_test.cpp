#include <windows.h>

#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>

#include "reset_service.h"

namespace fs = std::filesystem;
using pondera_reset::ResetPaths;
using pondera_reset::ResetService;
using pondera_reset::SystemAdapter;

namespace {

class FakeSystemAdapter final : public SystemAdapter {
 public:
  bool running = false;
  bool reparse_point = false;
  bool credential_exists = false;

  bool IsPonderaRunning(std::wstring* error) const override {
    error->clear();
    return running;
  }

  bool IsReparsePoint(const fs::path&, std::wstring* error) const override {
    error->clear();
    return reparse_point;
  }

  bool CredentialExists(const std::wstring&, std::wstring* error) const override {
    error->clear();
    return credential_exists;
  }

};

class TestDirectory {
 public:
  TestDirectory() {
    root = fs::temp_directory_path() /
           (L"pondera-reset-test-" + std::to_wstring(GetCurrentProcessId()) +
            L"-" + std::to_wstring(GetTickCount64()));
    fs::create_directories(root);
  }

  ~TestDirectory() {
    std::error_code ignored;
    fs::remove_all(root, ignored);
  }

  ResetPaths Paths() const {
    const auto company = root / L"com.caicedosantiago";
    return {
        company / L"pondera",
        company / L"PonderaLabReset" / L"backups",
        root / L"audit",
    };
  }

  fs::path root;
};

int failures = 0;

void Expect(bool condition, const char* message) {
  if (!condition) {
    std::cerr << "FAILED: " << message << '\n';
    ++failures;
  }
}

void WriteFile(const fs::path& path, const std::string& content) {
  fs::create_directories(path.parent_path());
  std::ofstream output(path, std::ios::binary);
  output << content;
}

std::string ReadFile(const fs::path& path) {
  std::ifstream input(path, std::ios::binary);
  return {std::istreambuf_iterator<char>(input),
          std::istreambuf_iterator<char>()};
}

void TestAlreadyClean() {
  TestDirectory directory;
  FakeSystemAdapter system;
  ResetService service(directory.Paths(), system);

  const auto inspection = service.Inspect();
  Expect(inspection.safe_to_reset, "an empty profile should be safe");
  Expect(!inspection.data_directory_exists, "the data directory should be absent");

  const auto result = service.Execute();
  Expect(result.success, "an already clean profile should succeed");
  Expect(!result.changed, "an already clean profile should not report changes");
  Expect(fs::exists(result.audit_path), "the operation should create an audit log");
}

void TestBackupAndCleanup() {
  TestDirectory directory;
  FakeSystemAdapter system;
  system.credential_exists = true;
  const auto paths = directory.Paths();
  WriteFile(paths.data_directory / L"flutter_secure_storage.dat", "encrypted");
  WriteFile(paths.data_directory / L"shared_preferences.json", "{}");
  WriteFile(paths.data_directory / L"licensing" / L"active.pondera-license",
            "signed-license");
  ResetService service(paths, system);

  const auto inspection = service.Inspect();
  Expect(inspection.safe_to_reset, "a closed Pondera profile should be safe");
  Expect(inspection.file_count == 3, "inspection should count profile files");
  Expect(inspection.legacy_credential_exists,
         "inspection should report the legacy credential");

  const auto result = service.Execute();
  Expect(result.success, "the reset should succeed");
  Expect(result.changed, "the reset should report changes");
  Expect(result.data_backed_up, "the data should be backed up");
  Expect(result.identity_preserved,
         "the installation identity should be preserved");
  Expect(system.credential_exists,
         "the additional secure identity should be preserved");
  Expect(ReadFile(paths.data_directory / L"flutter_secure_storage.dat") ==
             "encrypted",
         "the secure storage file should be restored byte for byte");
  Expect(!fs::exists(paths.data_directory / L"shared_preferences.json"),
         "the active profile should not retain preferences");
  Expect(!fs::exists(paths.data_directory / L"licensing" /
                     L"active.pondera-license"),
         "the active profile should not retain the old license");
  Expect(fs::exists(result.backup_path / L"shared_preferences.json"),
         "the backup should contain the original preferences");
}

void TestRunningAppBlocksReset() {
  TestDirectory directory;
  FakeSystemAdapter system;
  system.running = true;
  const auto paths = directory.Paths();
  WriteFile(paths.data_directory / L"shared_preferences.json", "{}");
  ResetService service(paths, system);

  const auto result = service.Execute();
  Expect(!result.success, "the reset should fail while Pondera is running");
  Expect(fs::exists(paths.data_directory),
         "a blocked reset must preserve the original profile");
}

void TestProfileWithoutSecureFileKeepsExternalIdentity() {
  TestDirectory directory;
  FakeSystemAdapter system;
  system.credential_exists = true;
  const auto paths = directory.Paths();
  WriteFile(paths.data_directory / L"shared_preferences.json", "{}");
  ResetService service(paths, system);

  const auto result = service.Execute();
  Expect(result.success, "a profile with external identity should be cleaned");
  Expect(result.identity_preserved,
         "the external installation identity should remain available");
  Expect(system.credential_exists,
         "the reset must not delete the external secure identity");
  Expect(!fs::exists(paths.data_directory),
         "a profile without secure storage should remain absent after cleanup");
}

void TestUnexpectedPathIsRejected() {
  TestDirectory directory;
  FakeSystemAdapter system;
  auto paths = directory.Paths();
  paths.data_directory = directory.root / L"not-pondera";
  ResetService service(paths, system);

  const auto inspection = service.Inspect();
  Expect(!inspection.safe_to_reset, "an unexpected path must be rejected");
}

}  // namespace

int main() {
  TestAlreadyClean();
  TestBackupAndCleanup();
  TestRunningAppBlocksReset();
  TestProfileWithoutSecureFileKeepsExternalIdentity();
  TestUnexpectedPathIsRejected();
  if (failures == 0) {
    std::cout << "All Pondera Lab Reset tests passed.\n";
    return 0;
  }
  std::cerr << failures << " test(s) failed.\n";
  return 1;
}
