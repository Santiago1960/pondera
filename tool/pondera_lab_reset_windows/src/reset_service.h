#pragma once

#include <cstdint>
#include <filesystem>
#include <string>

namespace pondera_reset {

inline constexpr wchar_t kLegacyCredentialTarget[] =
    L"pondera_VGhpcyBpcyB0aGUgcHJlZml4IGZv_pondera_installation_id";

struct ResetPaths {
  std::filesystem::path data_directory;
  std::filesystem::path backup_root;
  std::filesystem::path audit_root;
};

class SystemAdapter {
 public:
  virtual ~SystemAdapter() = default;

  virtual bool IsPonderaRunning(std::wstring* error) const = 0;
  virtual bool IsReparsePoint(const std::filesystem::path& path,
                              std::wstring* error) const = 0;
  virtual bool CredentialExists(const std::wstring& target,
                                std::wstring* error) const = 0;
};

struct ResetInspection {
  bool safe_to_reset = false;
  bool pondera_running = false;
  bool data_directory_exists = false;
  bool secure_storage_exists = false;
  bool shared_preferences_exists = false;
  bool offline_license_exists = false;
  bool legacy_credential_exists = false;
  std::uintmax_t file_count = 0;
  std::uintmax_t total_bytes = 0;
  std::wstring error;
};

struct ResetResult {
  bool success = false;
  bool changed = false;
  bool data_backed_up = false;
  bool identity_preserved = false;
  std::filesystem::path backup_path;
  std::filesystem::path audit_path;
  std::wstring message;
  std::wstring warning;
};

class ResetService {
 public:
  ResetService(ResetPaths paths, SystemAdapter& system);

  const ResetPaths& paths() const { return paths_; }
  ResetInspection Inspect() const;
  ResetResult Execute();

 private:
  bool ValidatePaths(std::wstring* error) const;
  std::filesystem::path NextBackupPath(std::wstring* error) const;
  void WriteAudit(ResetResult* result) const;

  ResetPaths paths_;
  SystemAdapter& system_;
};

}  // namespace pondera_reset
