#include "windows_system_adapter.h"

#include <windows.h>
#include <wincred.h>
#include <shlobj.h>
#include <tlhelp32.h>

#include <cwchar>

namespace pondera_reset {
namespace {

std::wstring WindowsErrorMessage(DWORD code) {
  wchar_t* buffer = nullptr;
  const DWORD size = FormatMessageW(
      FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM |
          FORMAT_MESSAGE_IGNORE_INSERTS,
      nullptr, code, 0, reinterpret_cast<wchar_t*>(&buffer), 0, nullptr);
  std::wstring message = size == 0 ? L"Error de Windows " + std::to_wstring(code)
                                   : std::wstring(buffer, size);
  if (buffer != nullptr) {
    LocalFree(buffer);
  }
  while (!message.empty() &&
         (message.back() == L'\r' || message.back() == L'\n' ||
          message.back() == L' ')) {
    message.pop_back();
  }
  return message;
}

std::filesystem::path KnownFolder(REFKNOWNFOLDERID id, std::wstring* error) {
  PWSTR raw_path = nullptr;
  const HRESULT result = SHGetKnownFolderPath(id, KF_FLAG_DEFAULT, nullptr,
                                               &raw_path);
  if (FAILED(result)) {
    if (error != nullptr) {
      *error = L"No se pudo resolver una carpeta de Windows (HRESULT " +
               std::to_wstring(static_cast<unsigned long>(result)) + L").";
    }
    return {};
  }
  std::filesystem::path path(raw_path);
  CoTaskMemFree(raw_path);
  return path;
}

}  // namespace

ResetPaths ResolveDefaultPaths(std::wstring* error) {
  if (error != nullptr) {
    error->clear();
  }
  const auto roaming = KnownFolder(FOLDERID_RoamingAppData, error);
  if (roaming.empty()) {
    return {};
  }
  const auto local = KnownFolder(FOLDERID_LocalAppData, error);
  if (local.empty()) {
    return {};
  }

  const auto company = roaming / L"com.caicedosantiago";
  return {
      company / L"pondera",
      company / L"PonderaLabReset" / L"backups",
      local / L"Bitgenial" / L"PonderaLabReset" / L"logs",
  };
}

bool WindowsSystemAdapter::IsPonderaRunning(std::wstring* error) const {
  if (error != nullptr) {
    error->clear();
  }
  const HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if (snapshot == INVALID_HANDLE_VALUE) {
    if (error != nullptr) {
      *error = L"No se pudieron consultar los procesos: " +
               WindowsErrorMessage(GetLastError());
    }
    return false;
  }

  PROCESSENTRY32W entry{};
  entry.dwSize = sizeof(entry);
  bool running = false;
  if (Process32FirstW(snapshot, &entry)) {
    do {
      if (_wcsicmp(entry.szExeFile, L"pondera.exe") == 0) {
        running = true;
        break;
      }
    } while (Process32NextW(snapshot, &entry));
  } else if (error != nullptr) {
    *error = L"No se pudo leer la lista de procesos: " +
             WindowsErrorMessage(GetLastError());
  }
  CloseHandle(snapshot);
  return running;
}

bool WindowsSystemAdapter::IsReparsePoint(
    const std::filesystem::path& path, std::wstring* error) const {
  if (error != nullptr) {
    error->clear();
  }
  const DWORD attributes = GetFileAttributesW(path.c_str());
  if (attributes == INVALID_FILE_ATTRIBUTES) {
    const DWORD code = GetLastError();
    if (code == ERROR_FILE_NOT_FOUND || code == ERROR_PATH_NOT_FOUND) {
      return false;
    }
    if (error != nullptr) {
      *error = L"No se pudieron inspeccionar los atributos de la carpeta: " +
               WindowsErrorMessage(code);
    }
    return false;
  }
  return (attributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0;
}

bool WindowsSystemAdapter::CredentialExists(const std::wstring& target,
                                            std::wstring* error) const {
  if (error != nullptr) {
    error->clear();
  }
  PCREDENTIALW credential = nullptr;
  if (CredReadW(target.c_str(), CRED_TYPE_GENERIC, 0, &credential)) {
    CredFree(credential);
    return true;
  }
  const DWORD code = GetLastError();
  if (code == ERROR_NOT_FOUND) {
    return false;
  }
  if (error != nullptr) {
    *error = L"No se pudo consultar la credencial heredada: " +
             WindowsErrorMessage(code);
  }
  return false;
}

}  // namespace pondera_reset
