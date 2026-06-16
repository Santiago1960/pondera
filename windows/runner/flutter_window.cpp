#include "flutter_window.h"

#include <optional>
#include <string>
#include <vector>

#include "flutter/generated_plugin_registrant.h"
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

namespace {

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
