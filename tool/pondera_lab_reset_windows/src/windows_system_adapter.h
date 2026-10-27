#pragma once

#include "reset_service.h"

namespace pondera_reset {

ResetPaths ResolveDefaultPaths(std::wstring* error);

class WindowsSystemAdapter final : public SystemAdapter {
 public:
  bool IsPonderaRunning(std::wstring* error) const override;
  bool IsReparsePoint(const std::filesystem::path& path,
                      std::wstring* error) const override;
  bool CredentialExists(const std::wstring& target,
                        std::wstring* error) const override;
};

}  // namespace pondera_reset
