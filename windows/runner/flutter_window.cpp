#include "flutter_window.h"

#include <algorithm>
#include <cstdint>
#include <memory>
#include <optional>
#include <string>
#include <vector>

#include "flutter/generated_plugin_registrant.h"
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

namespace {

constexpr wchar_t kOperatorAlertWindowClass[] =
    L"PONDERA_OPERATOR_ALERT_WINDOW";
constexpr UINT_PTR kOperatorAlertTimerId = 1;
constexpr int kOperatorAlertWidth = 430;
constexpr int kOperatorAlertHeight = 112;
constexpr int kOperatorAlertMargin = 24;
constexpr UINT kF12PressedMessage = WM_APP + 1;

struct OperatorAlertState {
  std::wstring title;
  std::wstring message;
  UINT duration_ms = 4000;
  HFONT title_font = nullptr;
  HFONT message_font = nullptr;

  ~OperatorAlertState() {
    if (title_font) {
      DeleteObject(title_font);
    }
    if (message_font) {
      DeleteObject(message_font);
    }
  }
};

HWND g_operator_alert_window = nullptr;
std::unique_ptr<OperatorAlertState> g_operator_alert_state;
HHOOK g_f12_keyboard_hook = nullptr;
HWND g_f12_target_window = nullptr;
bool g_f12_key_is_down = false;

LRESULT CALLBACK F12KeyboardHookProc(int code, WPARAM wparam,
                                    LPARAM lparam) noexcept {
  if (code == HC_ACTION) {
    const auto* keyboard_event =
        reinterpret_cast<const KBDLLHOOKSTRUCT*>(lparam);
    if (keyboard_event->vkCode == VK_F12) {
      if (wparam == WM_KEYDOWN || wparam == WM_SYSKEYDOWN) {
        if (!g_f12_key_is_down && g_f12_target_window) {
          g_f12_key_is_down = true;
          PostMessage(g_f12_target_window, kF12PressedMessage, 0, 0);
        }
        return 1;
      }
      if (wparam == WM_KEYUP || wparam == WM_SYSKEYUP) {
        g_f12_key_is_down = false;
        return 1;
      }
    }
  }

  return CallNextHookEx(g_f12_keyboard_hook, code, wparam, lparam);
}

bool SetF12KeyboardHookEnabled(HWND target_window, bool enabled) {
  if (enabled) {
    if (g_f12_keyboard_hook) {
      return g_f12_target_window == target_window;
    }

    g_f12_target_window = target_window;
    g_f12_key_is_down = false;
    g_f12_keyboard_hook = SetWindowsHookExW(
        WH_KEYBOARD_LL, F12KeyboardHookProc, GetModuleHandle(nullptr), 0);
    if (!g_f12_keyboard_hook) {
      g_f12_target_window = nullptr;
      return false;
    }
    return true;
  }

  g_f12_target_window = nullptr;
  g_f12_key_is_down = false;
  if (!g_f12_keyboard_hook) {
    return true;
  }

  const HHOOK hook = g_f12_keyboard_hook;
  g_f12_keyboard_hook = nullptr;
  return UnhookWindowsHookEx(hook) != FALSE;
}

int ScaleForDpi(int value, UINT dpi) {
  return MulDiv(value, static_cast<int>(dpi), USER_DEFAULT_SCREEN_DPI);
}

LRESULT CALLBACK OperatorAlertWindowProc(HWND window, UINT message,
                                         WPARAM wparam,
                                         LPARAM lparam) noexcept {
  auto* state = reinterpret_cast<OperatorAlertState*>(
      GetWindowLongPtr(window, GWLP_USERDATA));

  if (message == WM_NCCREATE) {
    const auto* create = reinterpret_cast<CREATESTRUCT*>(lparam);
    state = static_cast<OperatorAlertState*>(create->lpCreateParams);
    SetWindowLongPtr(window, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(state));
  }

  switch (message) {
    case WM_CREATE: {
      if (!state) {
        return -1;
      }

      const UINT dpi = GetDpiForWindow(window);
      state->title_font = CreateFontW(
          -ScaleForDpi(16, dpi), 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
          DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
          CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI");
      state->message_font = CreateFontW(
          -ScaleForDpi(13, dpi), 0, 0, 0, FW_MEDIUM, FALSE, FALSE, FALSE,
          DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
          CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI");
      SetTimer(window, kOperatorAlertTimerId, state->duration_ms, nullptr);
      return 0;
    }

    case WM_ERASEBKGND:
      return 1;

    case WM_PAINT: {
      PAINTSTRUCT paint{};
      HDC device_context = BeginPaint(window, &paint);
      RECT bounds{};
      GetClientRect(window, &bounds);

      HBRUSH background = CreateSolidBrush(RGB(185, 28, 28));
      FillRect(device_context, &bounds, background);
      DeleteObject(background);

      if (state) {
        const UINT dpi = GetDpiForWindow(window);
        const int horizontal_padding = ScaleForDpi(18, dpi);
        const int top_padding = ScaleForDpi(14, dpi);
        const int title_height = ScaleForDpi(24, dpi);
        const int spacing = ScaleForDpi(5, dpi);

        SetBkMode(device_context, TRANSPARENT);
        SetTextColor(device_context, RGB(255, 255, 255));

        RECT title_bounds{horizontal_padding, top_padding,
                          bounds.right - horizontal_padding,
                          top_padding + title_height};
        SelectObject(device_context, state->title_font);
        DrawTextW(device_context, state->title.c_str(), -1, &title_bounds,
                  DT_LEFT | DT_SINGLELINE | DT_END_ELLIPSIS | DT_NOPREFIX);

        RECT message_bounds{horizontal_padding,
                            top_padding + title_height + spacing,
                            bounds.right - horizontal_padding,
                            bounds.bottom - top_padding};
        SelectObject(device_context, state->message_font);
        DrawTextW(device_context, state->message.c_str(), -1, &message_bounds,
                  DT_LEFT | DT_WORDBREAK | DT_END_ELLIPSIS | DT_NOPREFIX);
      }

      EndPaint(window, &paint);
      return 0;
    }

    case WM_TIMER:
      if (wparam == kOperatorAlertTimerId) {
        KillTimer(window, kOperatorAlertTimerId);
        DestroyWindow(window);
        return 0;
      }
      break;

    case WM_NCDESTROY:
      SetWindowLongPtr(window, GWLP_USERDATA, 0);
      if (g_operator_alert_window == window) {
        g_operator_alert_window = nullptr;
        g_operator_alert_state.reset();
      }
      return 0;
  }

  return DefWindowProc(window, message, wparam, lparam);
}

bool EnsureOperatorAlertWindowClass() {
  WNDCLASSW window_class{};
  window_class.style = CS_DROPSHADOW;
  window_class.lpfnWndProc = OperatorAlertWindowProc;
  window_class.hInstance = GetModuleHandle(nullptr);
  window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
  window_class.lpszClassName = kOperatorAlertWindowClass;

  if (RegisterClassW(&window_class)) {
    return true;
  }
  return GetLastError() == ERROR_CLASS_ALREADY_EXISTS;
}

void DismissOperatorAlert() {
  if (g_operator_alert_window) {
    DestroyWindow(g_operator_alert_window);
  }
}

bool ShowOperatorAlert(HWND owner_window, const std::wstring& title,
                       const std::wstring& message, UINT duration_ms) {
  DismissOperatorAlert();
  if (!EnsureOperatorAlertWindowClass()) {
    return false;
  }

  POINT cursor_position{};
  GetCursorPos(&cursor_position);
  const HMONITOR monitor =
      MonitorFromPoint(cursor_position, MONITOR_DEFAULTTONEAREST);
  MONITORINFO monitor_info{};
  monitor_info.cbSize = sizeof(monitor_info);
  if (!GetMonitorInfo(monitor, &monitor_info)) {
    return false;
  }

  const UINT dpi = owner_window ? GetDpiForWindow(owner_window)
                                : USER_DEFAULT_SCREEN_DPI;
  const int width = ScaleForDpi(kOperatorAlertWidth, dpi);
  const int height = ScaleForDpi(kOperatorAlertHeight, dpi);
  const int margin = ScaleForDpi(kOperatorAlertMargin, dpi);
  const int left = monitor_info.rcWork.right - width - margin;
  const int top = monitor_info.rcWork.top + margin;

  g_operator_alert_state = std::make_unique<OperatorAlertState>();
  g_operator_alert_state->title = title;
  g_operator_alert_state->message = message;
  g_operator_alert_state->duration_ms = duration_ms;

  g_operator_alert_window = CreateWindowExW(
      WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE,
      kOperatorAlertWindowClass, title.c_str(), WS_POPUP, left, top, width,
      height, nullptr, nullptr, GetModuleHandle(nullptr),
      g_operator_alert_state.get());
  if (!g_operator_alert_window) {
    g_operator_alert_state.reset();
    return false;
  }

  HRGN rounded_region = CreateRoundRectRgn(
      0, 0, width + 1, height + 1, ScaleForDpi(12, dpi),
      ScaleForDpi(12, dpi));
  if (!SetWindowRgn(g_operator_alert_window, rounded_region, TRUE)) {
    DeleteObject(rounded_region);
  }

  SetWindowPos(g_operator_alert_window, HWND_TOPMOST, left, top, width, height,
               SWP_NOACTIVATE | SWP_SHOWWINDOW);
  ShowWindow(g_operator_alert_window, SW_SHOWNOACTIVATE);
  return true;
}

std::wstring Utf8ToWide(const std::string& value) {
  if (value.empty()) {
    return std::wstring();
  }

  int size = MultiByteToWideChar(CP_UTF8, 0, value.c_str(), -1, nullptr, 0);
  if (size <= 0) {
    return std::wstring();
  }

  std::wstring result(static_cast<size_t>(size), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, value.c_str(), -1, result.data(), size);
  if (!result.empty() && result.back() == L'\0') {
    result.pop_back();
  }
  return result;
}

bool SendInputBatch(const std::vector<INPUT>& inputs, UINT* sent_events,
                    DWORD* last_error) {
  if (inputs.empty()) {
    return true;
  }

  std::vector<INPUT> mutable_inputs = inputs;
  UINT expected = static_cast<UINT>(mutable_inputs.size());
  UINT sent = SendInput(expected, mutable_inputs.data(), sizeof(INPUT));
  *sent_events += sent;

  if (sent != expected) {
    *last_error = GetLastError();
    return false;
  }

  Sleep(30);
  return true;
}

bool SendVirtualKey(WORD virtual_key, UINT* sent_events, DWORD* last_error) {
  std::vector<INPUT> inputs(2);
  inputs[0].type = INPUT_KEYBOARD;
  inputs[0].ki.wVk = virtual_key;

  inputs[1].type = INPUT_KEYBOARD;
  inputs[1].ki.wVk = virtual_key;
  inputs[1].ki.dwFlags = KEYEVENTF_KEYUP;

  return SendInputBatch(inputs, sent_events, last_error);
}

bool SendUnicodeChar(wchar_t character, UINT* sent_events, DWORD* last_error) {
  std::vector<INPUT> inputs(2);
  inputs[0].type = INPUT_KEYBOARD;
  inputs[0].ki.wScan = character;
  inputs[0].ki.dwFlags = KEYEVENTF_UNICODE;

  inputs[1].type = INPUT_KEYBOARD;
  inputs[1].ki.wScan = character;
  inputs[1].ki.dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP;

  return SendInputBatch(inputs, sent_events, last_error);
}

bool SendCtrlV(UINT* sent_events, DWORD* last_error) {
  std::vector<INPUT> inputs(4);
  inputs[0].type = INPUT_KEYBOARD;
  inputs[0].ki.wVk = VK_CONTROL;

  inputs[1].type = INPUT_KEYBOARD;
  inputs[1].ki.wVk = 'V';

  inputs[2].type = INPUT_KEYBOARD;
  inputs[2].ki.wVk = 'V';
  inputs[2].ki.dwFlags = KEYEVENTF_KEYUP;

  inputs[3].type = INPUT_KEYBOARD;
  inputs[3].ki.wVk = VK_CONTROL;
  inputs[3].ki.dwFlags = KEYEVENTF_KEYUP;

  return SendInputBatch(inputs, sent_events, last_error);
}

bool TryReadSpecialToken(const std::wstring& sequence, size_t index,
                         WORD* virtual_key, size_t* token_length) {
  if (sequence.compare(index, 5, L"{TAB}") == 0) {
    *virtual_key = VK_TAB;
    *token_length = 5;
    return true;
  }
  if (sequence.compare(index, 7, L"{ENTER}") == 0) {
    *virtual_key = VK_RETURN;
    *token_length = 7;
    return true;
  }
  if (sequence.compare(index, 7, L"{SPACE}") == 0) {
    *virtual_key = VK_SPACE;
    *token_length = 7;
    return true;
  }
  return false;
}

bool SendSequence(const std::wstring& sequence, UINT* sent_events,
                  DWORD* last_error) {
  for (size_t index = 0; index < sequence.size();) {
    WORD virtual_key = 0;
    size_t token_length = 0;
    if (TryReadSpecialToken(sequence, index, &virtual_key, &token_length)) {
      if (!SendVirtualKey(virtual_key, sent_events, last_error)) {
        return false;
      }
      index += token_length;
      continue;
    }

    if (!SendUnicodeChar(sequence[index], sent_events, last_error)) {
      return false;
    }
    index++;
  }

  return true;
}

const std::string* GetStringArgument(const flutter::EncodableMap& arguments,
                                     const char* key) {
  auto it = arguments.find(flutter::EncodableValue(key));
  if (it == arguments.end()) {
    return nullptr;
  }
  return std::get_if<std::string>(&it->second);
}

int64_t GetIntegerArgument(const flutter::EncodableMap& arguments,
                           const char* key, int64_t fallback) {
  auto it = arguments.find(flutter::EncodableValue(key));
  if (it == arguments.end()) {
    return fallback;
  }
  if (const auto* value = std::get_if<int32_t>(&it->second)) {
    return *value;
  }
  if (const auto* value = std::get_if<int64_t>(&it->second)) {
    return *value;
  }
  return fallback;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  weight_capture_hotkey_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "pondera/weight_capture_hotkey",
          &flutter::StandardMethodCodec::GetInstance());
  weight_capture_hotkey_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() != "setEnabled") {
          result->NotImplemented();
          return;
        }

        const bool* enabled = std::get_if<bool>(call.arguments());
        if (!enabled) {
          result->Error("invalid_arguments", "Expected a boolean argument.");
          return;
        }
        if (*enabled == f12_keyboard_hook_installed_) {
          result->Success();
          return;
        }

        if (*enabled) {
          if (!SetF12KeyboardHookEnabled(GetHandle(), true)) {
            result->Error(
                "keyboard_hook_installation_failed",
                "Windows could not install the F12 keyboard hook.",
                flutter::EncodableValue(
                    static_cast<int32_t>(GetLastError())));
            return;
          }
          f12_keyboard_hook_installed_ = true;
          result->Success();
          return;
        }

        if (!SetF12KeyboardHookEnabled(GetHandle(), false)) {
          result->Error(
              "keyboard_hook_removal_failed",
              "Windows could not remove the F12 keyboard hook.",
              flutter::EncodableValue(static_cast<int32_t>(GetLastError())));
          return;
        }
        f12_keyboard_hook_installed_ = false;
        result->Success();
      });

  windows_keyboard_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "pondera/windows_keyboard",
          &flutter::StandardMethodCodec::GetInstance());

  windows_keyboard_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        if (call.method_name() != "sendPasteSequence") {
          result->NotImplemented();
          return;
        }

        const auto* arguments =
            std::get_if<flutter::EncodableMap>(call.arguments());
        if (!arguments) {
          result->Error("invalid_arguments", "Expected a map of arguments.");
          return;
        }

        const std::string* prefix = GetStringArgument(*arguments, "prefix");
        const std::string* suffix = GetStringArgument(*arguments, "suffix");
        if (!prefix || !suffix) {
          result->Error("invalid_arguments",
                        "Expected string arguments: prefix and suffix.");
          return;
        }

        UINT sent_events = 0;
        DWORD last_error = ERROR_SUCCESS;

        if (!SendSequence(Utf8ToWide(*prefix), &sent_events, &last_error) ||
            !SendCtrlV(&sent_events, &last_error) ||
            !SendSequence(Utf8ToWide(*suffix), &sent_events, &last_error)) {
          result->Error("send_input_failed", "Windows SendInput failed.",
                        flutter::EncodableValue(
                            static_cast<int32_t>(last_error)));
          return;
        }

        result->Success();
      });

  operator_alert_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "pondera/operator_alert",
          &flutter::StandardMethodCodec::GetInstance());
  operator_alert_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() != "show") {
          result->NotImplemented();
          return;
        }

        const auto* arguments =
            std::get_if<flutter::EncodableMap>(call.arguments());
        if (!arguments) {
          result->Error("invalid_arguments", "Expected a map of arguments.");
          return;
        }

        const std::string* title = GetStringArgument(*arguments, "title");
        const std::string* message = GetStringArgument(*arguments, "message");
        if (!title || !message) {
          result->Error("invalid_arguments",
                        "Expected string arguments: title and message.");
          return;
        }

        const int64_t requested_duration =
            GetIntegerArgument(*arguments, "durationMs", 4000);
        const UINT duration = static_cast<UINT>(std::clamp<int64_t>(
            requested_duration, 1500, 10000));
        if (!ShowOperatorAlert(GetHandle(), Utf8ToWide(*title),
                               Utf8ToWide(*message), duration)) {
          result->Error("show_alert_failed",
                        "Windows could not show the operator alert.",
                        flutter::EncodableValue(
                            static_cast<int32_t>(GetLastError())));
          return;
        }

        result->Success();
      });

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (f12_keyboard_hook_installed_) {
    SetF12KeyboardHookEnabled(GetHandle(), false);
    f12_keyboard_hook_installed_ = false;
  }
  if (weight_capture_hotkey_channel_) {
    weight_capture_hotkey_channel_->SetMethodCallHandler(nullptr);
  }
  weight_capture_hotkey_channel_ = nullptr;

  if (operator_alert_channel_) {
    operator_alert_channel_->SetMethodCallHandler(nullptr);
  }
  operator_alert_channel_ = nullptr;
  DismissOperatorAlert();

  if (windows_keyboard_channel_) {
    windows_keyboard_channel_->SetMethodCallHandler(nullptr);
  }
  windows_keyboard_channel_ = nullptr;

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == kF12PressedMessage) {
    if (weight_capture_hotkey_channel_) {
      weight_capture_hotkey_channel_->InvokeMethod("pressed", nullptr);
    }
    return 0;
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
