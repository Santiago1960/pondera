#include "reset_service.h"

#include <algorithm>
#include <chrono>
#include <cwctype>
#include <fstream>
#include <iomanip>
#include <iterator>
#include <sstream>
#include <system_error>

namespace pondera_reset {
namespace fs = std::filesystem;

namespace {

std::wstring Timestamp() {
  const auto now = std::chrono::system_clock::now();
  const std::time_t time = std::chrono::system_clock::to_time_t(now);
  std::tm local_time{};
  localtime_s(&local_time, &time);
  std::wostringstream output;
  output << std::put_time(&local_time, L"%Y%m%d-%H%M%S");
  return output.str();
}

std::wstring Lowercase(std::wstring value) {
  for (auto& character : value) {
    character = static_cast<wchar_t>(std::towlower(character));
  }
  return value;
}

bool SamePath(const fs::path& left, const fs::path& right) {
  return Lowercase(left.lexically_normal().native()) ==
         Lowercase(right.lexically_normal().native());
}

void AppendWarning(std::wstring* warning, const std::wstring& value) {
  if (value.empty()) {
    return;
  }
  if (!warning->empty()) {
    *warning += L" ";
  }
  *warning += value;
}

std::wstring ErrorMessage(const std::error_code& error) {
  const auto message = error.message();
  return std::wstring(message.begin(), message.end());
}

bool FilesEqual(const fs::path& left, const fs::path& right) {
  std::error_code ec;
  const auto left_size = fs::file_size(left, ec);
  if (ec) {
    return false;
  }
  const auto right_size = fs::file_size(right, ec);
  if (ec || left_size != right_size) {
    return false;
  }

  std::ifstream left_stream(left, std::ios::binary);
  std::ifstream right_stream(right, std::ios::binary);
  return left_stream && right_stream &&
         std::equal(std::istreambuf_iterator<char>(left_stream),
                    std::istreambuf_iterator<char>(),
                    std::istreambuf_iterator<char>(right_stream));
}

}  // namespace

ResetService::ResetService(ResetPaths paths, SystemAdapter& system)
    : paths_(std::move(paths)), system_(system) {}

bool ResetService::ValidatePaths(std::wstring* error) const {
  if (error != nullptr) {
    error->clear();
  }
  if (paths_.data_directory.empty() || paths_.backup_root.empty() ||
      paths_.audit_root.empty()) {
    if (error != nullptr) {
      *error = L"No se pudieron determinar todas las rutas de trabajo.";
    }
    return false;
  }

  const auto data = paths_.data_directory.lexically_normal();
  if (_wcsicmp(data.filename().c_str(), L"pondera") != 0 ||
      _wcsicmp(data.parent_path().filename().c_str(),
               L"com.caicedosantiago") != 0) {
    if (error != nullptr) {
      *error = L"La carpeta de datos no coincide con la ruta exacta de Pondera.";
    }
    return false;
  }

  const auto expected_backup =
      data.parent_path() / L"PonderaLabReset" / L"backups";
  if (!SamePath(paths_.backup_root, expected_backup)) {
    if (error != nullptr) {
      *error = L"La carpeta de respaldo no coincide con la ruta segura esperada.";
    }
    return false;
  }

  if (SamePath(data, data.root_path()) || SamePath(data, paths_.backup_root)) {
    if (error != nullptr) {
      *error = L"Las rutas resueltas no son seguras para continuar.";
    }
    return false;
  }
  return true;
}

ResetInspection ResetService::Inspect() const {
  ResetInspection inspection;
  if (!ValidatePaths(&inspection.error)) {
    return inspection;
  }

  std::wstring system_error;
  inspection.pondera_running = system_.IsPonderaRunning(&system_error);
  if (!system_error.empty()) {
    inspection.error = system_error;
    return inspection;
  }

  inspection.legacy_credential_exists =
      system_.CredentialExists(kLegacyCredentialTarget, &system_error);
  if (!system_error.empty()) {
    inspection.error = system_error;
    return inspection;
  }

  std::error_code ec;
  inspection.data_directory_exists = fs::exists(paths_.data_directory, ec);
  if (ec) {
    inspection.error = L"No se pudo comprobar la carpeta de datos: " +
                       ErrorMessage(ec);
    return inspection;
  }

  if (inspection.data_directory_exists) {
    if (!fs::is_directory(paths_.data_directory, ec) || ec) {
      inspection.error =
          L"La ruta de datos de Pondera existe, pero no es una carpeta válida.";
      return inspection;
    }
    if (system_.IsReparsePoint(paths_.data_directory, &system_error)) {
      inspection.error =
          L"La carpeta de Pondera es un enlace o punto de reanálisis. Se bloqueó "
          L"la operación.";
      return inspection;
    }
    if (!system_error.empty()) {
      inspection.error = system_error;
      return inspection;
    }

    inspection.secure_storage_exists =
        fs::is_regular_file(paths_.data_directory /
                                L"flutter_secure_storage.dat",
                            ec);
    ec.clear();
    inspection.shared_preferences_exists =
        fs::is_regular_file(paths_.data_directory / L"shared_preferences.json",
                            ec);
    ec.clear();
    inspection.offline_license_exists = fs::is_regular_file(
        paths_.data_directory / L"licensing" / L"active.pondera-license", ec);
    ec.clear();

    fs::recursive_directory_iterator iterator(
        paths_.data_directory, fs::directory_options::skip_permission_denied,
        ec);
    const fs::recursive_directory_iterator end;
    while (!ec && iterator != end) {
      if (iterator->is_regular_file(ec) && !ec) {
        ++inspection.file_count;
        inspection.total_bytes += iterator->file_size(ec);
      }
      if (ec) {
        break;
      }
      iterator.increment(ec);
    }
    if (ec) {
      inspection.error =
          L"No se pudo analizar completamente la carpeta de Pondera: " +
          ErrorMessage(ec);
      return inspection;
    }
  }

  if (inspection.pondera_running) {
    inspection.error =
        L"Pondera está abierto. Ciérrelo antes de crear el respaldo.";
    return inspection;
  }

  inspection.safe_to_reset = true;
  return inspection;
}

fs::path ResetService::NextBackupPath(std::wstring* error) const {
  if (error != nullptr) {
    error->clear();
  }
  std::error_code ec;
  fs::create_directories(paths_.backup_root, ec);
  if (ec) {
    if (error != nullptr) {
      *error = L"No se pudo crear la carpeta de respaldos: " +
               ErrorMessage(ec);
    }
    return {};
  }

  const auto base_name = L"pondera-before-reset-" + Timestamp();
  for (int suffix = 0; suffix < 100; ++suffix) {
    std::wstring name = base_name;
    if (suffix > 0) {
      std::wostringstream value;
      value << L"-" << std::setfill(L'0') << std::setw(2) << suffix;
      name += value.str();
    }
    const auto candidate = paths_.backup_root / name;
    if (!fs::exists(candidate, ec) && !ec) {
      return candidate;
    }
    ec.clear();
  }
  if (error != nullptr) {
    *error = L"No se pudo reservar un nombre único para el respaldo.";
  }
  return {};
}

ResetResult ResetService::Execute() {
  ResetResult result;
  const auto inspection = Inspect();
  if (!inspection.safe_to_reset) {
    result.message = inspection.error.empty()
                         ? L"La comprobación previa bloqueó la operación."
                         : inspection.error;
    WriteAudit(&result);
    return result;
  }

  if (!inspection.data_directory_exists) {
    result.success = true;
    result.identity_preserved = inspection.legacy_credential_exists;
    result.message =
        L"El perfil local de Pondera ya estaba limpio. La identidad del "
        L"equipo se conservó.";
    WriteAudit(&result);
    return result;
  }

  if (inspection.data_directory_exists) {
    std::wstring path_error;
    result.backup_path = NextBackupPath(&path_error);
    if (result.backup_path.empty()) {
      result.message = path_error;
      WriteAudit(&result);
      return result;
    }

    std::error_code ec;
    fs::rename(paths_.data_directory, result.backup_path, ec);
    if (ec) {
      result.message = L"No se pudo mover la carpeta de Pondera al respaldo: " +
                       ErrorMessage(ec);
      result.backup_path.clear();
      WriteAudit(&result);
      return result;
    }
    result.changed = true;
    result.data_backed_up = true;
    result.identity_preserved = inspection.legacy_credential_exists;

    if (inspection.secure_storage_exists) {
      const auto identity_source =
          result.backup_path / L"flutter_secure_storage.dat";
      const auto identity_target =
          paths_.data_directory / L"flutter_secure_storage.dat";
      fs::create_directories(paths_.data_directory, ec);
      if (!ec) {
        fs::copy_file(identity_source, identity_target,
                      fs::copy_options::overwrite_existing, ec);
      }
      if (ec || !FilesEqual(identity_source, identity_target)) {
        result.message =
            L"No se pudo conservar la identidad segura de la instalación.";
        std::error_code cleanup_error;
        fs::remove(identity_target, cleanup_error);
        cleanup_error.clear();
        fs::remove(paths_.data_directory, cleanup_error);
        std::error_code rollback_error;
        fs::rename(result.backup_path, paths_.data_directory, rollback_error);
        if (!rollback_error) {
          result.data_backed_up = false;
          result.changed = false;
          result.backup_path.clear();
          AppendWarning(
              &result.warning,
              L"La carpeta original fue restaurada automáticamente.");
        } else {
          AppendWarning(
              &result.warning,
              L"No se pudo restaurar la carpeta original; los datos permanecen "
              L"en el respaldo indicado.");
        }
        WriteAudit(&result);
        return result;
      }
      result.identity_preserved = true;
    }
  }

  std::error_code verification_error;
  const bool preferences_still_exist = fs::exists(
      paths_.data_directory / L"shared_preferences.json", verification_error);
  verification_error.clear();
  const bool license_still_exists = fs::exists(
      paths_.data_directory / L"licensing" / L"active.pondera-license",
      verification_error);
  std::wstring credential_error;
  const bool credential_still_exists = system_.CredentialExists(
      kLegacyCredentialTarget, &credential_error);
  if (verification_error || !credential_error.empty() ||
      preferences_still_exist || license_still_exists ||
      credential_still_exists != inspection.legacy_credential_exists) {
    result.message =
        L"La limpieza se aplicó, pero la verificación final no fue concluyente.";
    AppendWarning(&result.warning,
                  L"No inicie Pondera hasta revisar el respaldo y el registro.");
    WriteAudit(&result);
    return result;
  }

  result.success = true;
  result.message = result.changed
                       ? L"El perfil local quedó limpio y listo para producción. "
                         L"La identidad de instalación se conservó."
                       : L"El perfil local de Pondera ya estaba limpio.";
  WriteAudit(&result);
  return result;
}

void ResetService::WriteAudit(ResetResult* result) const {
  std::error_code ec;
  fs::create_directories(paths_.audit_root, ec);
  if (ec) {
    AppendWarning(&result->warning,
                  L"No se pudo crear el directorio del registro local.");
    return;
  }

  auto audit_path = paths_.audit_root / (L"reset-" + Timestamp() + L".log");
  for (int suffix = 1; fs::exists(audit_path, ec) && !ec && suffix < 100;
       ++suffix) {
    audit_path = paths_.audit_root /
                 (L"reset-" + Timestamp() + L"-" +
                  std::to_wstring(suffix) + L".log");
  }
  if (ec) {
    AppendWarning(&result->warning,
                  L"No se pudo comprobar el nombre del registro local.");
    return;
  }

  std::wofstream output(audit_path, std::ios::out | std::ios::trunc);
  if (!output) {
    AppendWarning(&result->warning,
                  L"No se pudo escribir el registro local de la operación.");
    return;
  }
  output << L"Pondera Lab Reset\n"
         << L"timestamp=" << Timestamp() << L"\n"
         << L"success=" << (result->success ? L"true" : L"false") << L"\n"
         << L"changed=" << (result->changed ? L"true" : L"false") << L"\n"
         << L"data_backed_up="
         << (result->data_backed_up ? L"true" : L"false") << L"\n"
         << L"identity_preserved="
         << (result->identity_preserved ? L"true" : L"false") << L"\n"
         << L"backup_created="
         << (!result->backup_path.empty() ? L"true" : L"false") << L"\n";
  output.close();
  if (!output) {
    AppendWarning(&result->warning,
                  L"El registro local no pudo cerrarse correctamente.");
    return;
  }
  result->audit_path = audit_path;
}

}  // namespace pondera_reset
