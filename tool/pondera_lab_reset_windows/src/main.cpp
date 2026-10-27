#include <windows.h>
#include <commctrl.h>

#include <memory>
#include <sstream>

#include "reset_service.h"
#include "windows_system_adapter.h"

namespace {

constexpr int kAnalyzeButtonId = 1001;
constexpr int kConfirmEditId = 1002;
constexpr int kResetButtonId = 1003;
constexpr int kStatusEditId = 1004;

HWND g_status = nullptr;
HWND g_confirmation = nullptr;
HWND g_reset_button = nullptr;
pondera_reset::WindowsSystemAdapter g_system;
std::unique_ptr<pondera_reset::ResetService> g_service;
pondera_reset::ResetInspection g_inspection;

void UseDefaultFont(HWND control) {
  SendMessageW(control, WM_SETFONT,
               reinterpret_cast<WPARAM>(GetStockObject(DEFAULT_GUI_FONT)), TRUE);
}

std::wstring YesNo(bool value) { return value ? L"Sí" : L"No"; }

std::wstring FormatBytes(std::uintmax_t bytes) {
  std::wostringstream output;
  if (bytes >= 1024 * 1024) {
    output.setf(std::ios::fixed);
    output.precision(2);
    output << static_cast<double>(bytes) / (1024.0 * 1024.0) << L" MB";
  } else if (bytes >= 1024) {
    output.setf(std::ios::fixed);
    output.precision(2);
    output << static_cast<double>(bytes) / 1024.0 << L" KB";
  } else {
    output << bytes << L" bytes";
  }
  return output.str();
}

bool ConfirmationMatches() {
  wchar_t value[32]{};
  GetWindowTextW(g_confirmation, value, static_cast<int>(std::size(value)));
  return std::wstring(value) == L"RESTABLECER";
}

void UpdateResetButton() {
  EnableWindow(g_reset_button,
               g_service != nullptr && g_inspection.safe_to_reset &&
                   ConfirmationMatches());
}

std::wstring InspectionText(const pondera_reset::ResetInspection& value) {
  std::wostringstream output;
  output << L"RUTA INSPECCIONADA\r\n"
         << g_service->paths().data_directory.wstring() << L"\r\n\r\n"
         << L"Pondera abierto: " << YesNo(value.pondera_running) << L"\r\n"
         << L"Perfil local encontrado: "
         << YesNo(value.data_directory_exists) << L"\r\n"
         << L"Almacenamiento seguro: " << YesNo(value.secure_storage_exists)
         << L"\r\n"
         << L"Preferencias locales: "
         << YesNo(value.shared_preferences_exists) << L"\r\n"
         << L"Licencia local: " << YesNo(value.offline_license_exists)
         << L"\r\n"
         << L"Identidad segura adicional: "
         << YesNo(value.legacy_credential_exists) << L"\r\n"
         << L"Archivos: " << value.file_count << L" ("
         << FormatBytes(value.total_bytes) << L")\r\n\r\n";
  if (!value.error.empty()) {
    output << L"BLOQUEADO\r\n" << value.error;
  } else if (!value.data_directory_exists) {
    output << L"LISTO\r\nEl perfil local ya está limpio. La identidad del "
              L"equipo se conservará.";
  } else {
    output << L"LISTO\r\nSe puede crear el respaldo y limpiar este perfil.";
  }
  return output.str();
}

void Analyze() {
  if (g_service == nullptr) {
    return;
  }
  g_inspection = g_service->Inspect();
  const auto text = InspectionText(g_inspection);
  SetWindowTextW(g_status, text.c_str());
  UpdateResetButton();
}

void ExecuteReset(HWND window) {
  if (!g_inspection.safe_to_reset || !ConfirmationMatches()) {
    return;
  }
  const int confirmation = MessageBoxW(
      window,
      L"Se respaldará el perfil local de Pondera y se conservará la identidad "
      L"del equipo. Esta acción no modifica n8n ni la base de datos.\n\n"
      L"¿Continuar?",
      L"Confirmar preparación del equipo", MB_ICONWARNING | MB_YESNO | MB_DEFBUTTON2);
  if (confirmation != IDYES) {
    return;
  }

  const auto result = g_service->Execute();
  std::wostringstream message;
  message << result.message;
  if (!result.backup_path.empty()) {
    message << L"\n\nRespaldo:\n" << result.backup_path.wstring();
  }
  if (!result.audit_path.empty()) {
    message << L"\n\nRegistro:\n" << result.audit_path.wstring();
  }
  if (!result.warning.empty()) {
    message << L"\n\nAdvertencia:\n" << result.warning;
  }
  MessageBoxW(window, message.str().c_str(),
              result.success ? L"Preparación completada"
                             : L"No se completó la preparación",
              (result.success ? MB_ICONINFORMATION : MB_ICONERROR) | MB_OK);
  SetWindowTextW(g_confirmation, L"");
  Analyze();
}

HWND AddControl(HWND parent, const wchar_t* class_name, const wchar_t* text,
                DWORD style, int x, int y, int width, int height, int id) {
  HWND control = CreateWindowExW(
      lstrcmpW(class_name, WC_EDITW) == 0 ? WS_EX_CLIENTEDGE : 0, class_name,
      text,
      WS_CHILD | WS_VISIBLE | style, x, y, width, height, parent,
      reinterpret_cast<HMENU>(static_cast<INT_PTR>(id)),
      GetModuleHandleW(nullptr), nullptr);
  UseDefaultFont(control);
  return control;
}

LRESULT CALLBACK WindowProcedure(HWND window, UINT message, WPARAM w_param,
                                 LPARAM l_param) {
  switch (message) {
    case WM_CREATE: {
      AddControl(window, WC_STATICW, L"Pondera Lab Reset",
                 SS_LEFT, 24, 20, 520, 28, 0);
      AddControl(window, WC_STATICW,
                 L"Uso interno · Windows · No distribuir a clientes",
                 SS_LEFT, 24, 50, 520, 22, 0);
      AddControl(window, WC_BUTTONW, L"Analizar nuevamente",
                 BS_PUSHBUTTON, 574, 30, 170, 34, kAnalyzeButtonId);
      g_status = AddControl(
          window, WC_EDITW, L"Analizando...",
          ES_MULTILINE | ES_READONLY | ES_AUTOVSCROLL | WS_VSCROLL, 24, 88,
          720, 310, kStatusEditId);
      AddControl(window, WC_STATICW,
                 L"Para habilitar la operación, escriba RESTABLECER:",
                 SS_LEFT, 24, 420, 390, 22, 0);
      g_confirmation = AddControl(window, WC_EDITW, L"", ES_AUTOHSCROLL,
                                  24, 448, 300, 30, kConfirmEditId);
      g_reset_button = AddControl(window, WC_BUTTONW,
                                  L"Crear respaldo y limpiar", BS_DEFPUSHBUTTON,
                                  494, 438, 250, 44, kResetButtonId);
      EnableWindow(g_reset_button, FALSE);
      Analyze();
      return 0;
    }
    case WM_COMMAND: {
      const int id = LOWORD(w_param);
      const int notification = HIWORD(w_param);
      if (id == kAnalyzeButtonId && notification == BN_CLICKED) {
        Analyze();
        return 0;
      }
      if (id == kConfirmEditId && notification == EN_CHANGE) {
        UpdateResetButton();
        return 0;
      }
      if (id == kResetButtonId && notification == BN_CLICKED) {
        ExecuteReset(window);
        return 0;
      }
      break;
    }
    case WM_DESTROY:
      PostQuitMessage(0);
      return 0;
  }
  return DefWindowProcW(window, message, w_param, l_param);
}

}  // namespace

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, PWSTR, int show_command) {
  std::wstring path_error;
  const auto paths = pondera_reset::ResolveDefaultPaths(&path_error);
  if (!path_error.empty()) {
    MessageBoxW(nullptr, path_error.c_str(), L"Pondera Lab Reset", MB_ICONERROR);
    return 1;
  }
  g_service = std::make_unique<pondera_reset::ResetService>(paths, g_system);

  INITCOMMONCONTROLSEX controls{sizeof(controls), ICC_STANDARD_CLASSES};
  InitCommonControlsEx(&controls);

  const wchar_t class_name[] = L"PonderaLabResetWindow";
  WNDCLASSW window_class{};
  window_class.lpfnWndProc = WindowProcedure;
  window_class.hInstance = instance;
  window_class.hCursor = LoadCursorW(nullptr, IDC_ARROW);
  window_class.hIcon = LoadIconW(nullptr, IDI_APPLICATION);
  window_class.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1);
  window_class.lpszClassName = class_name;
  if (!RegisterClassW(&window_class)) {
    return 1;
  }

  const HWND window = CreateWindowExW(
      0, class_name, L"Pondera Lab Reset · Uso interno",
      WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX,
      CW_USEDEFAULT, CW_USEDEFAULT, 790, 550, nullptr, nullptr, instance,
      nullptr);
  if (window == nullptr) {
    return 1;
  }
  ShowWindow(window, show_command);
  UpdateWindow(window);

  MSG message{};
  while (GetMessageW(&message, nullptr, 0, 0) > 0) {
    TranslateMessage(&message);
    DispatchMessageW(&message);
  }
  return static_cast<int>(message.wParam);
}
