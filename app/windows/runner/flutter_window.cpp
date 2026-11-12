#include "flutter_window.h"

#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <optional>
#include <string>

#include "flutter/generated_plugin_registrant.h"

// Porta in primo piano la finestra principale (clic sulla notifica di nuova posta).
// Windows concede SetForegroundWindow solo in certi casi, per evitare che un programma "rubi" il
// primo piano mentre si lavora altrove: se non basta si aggancia per un attimo l'input del thread
// che ha il primo piano; se nemmeno questo basta, l'icona lampeggia nella barra delle applicazioni.
// Restituisce "foreground" (finestra davanti) oppure "flash" (solo lampeggio).
static std::string PresentWindow(HWND hwnd) {
  ShowWindow(hwnd, IsIconic(hwnd) ? SW_RESTORE : SW_SHOW);
  if (SetForegroundWindow(hwnd) && GetForegroundWindow() == hwnd) {
    return "foreground";
  }

  HWND current = GetForegroundWindow();
  DWORD current_thread = current ? GetWindowThreadProcessId(current, nullptr) : 0;
  DWORD this_thread = GetCurrentThreadId();
  if (current_thread != 0 && current_thread != this_thread &&
      AttachThreadInput(this_thread, current_thread, TRUE)) {
    BringWindowToTop(hwnd);
    SetForegroundWindow(hwnd);
    AttachThreadInput(this_thread, current_thread, FALSE);
  }
  if (GetForegroundWindow() == hwnd) {
    return "foreground";
  }

  FLASHWINFO flash = {};
  flash.cbSize = sizeof(flash);
  flash.hwnd = hwnd;
  flash.dwFlags = FLASHW_ALL | FLASHW_TIMERNOFG;  // finché l'utente non porta davanti la finestra
  FlashWindowEx(&flash);
  return "flash";
}

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

  window_channel_ = std::make_unique<flutter::MethodChannel<>>(
      flutter_controller_->engine()->messenger(), "com.dumm1969.postinovip/window",
      &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<>& call,
             std::unique_ptr<flutter::MethodResult<>> result) {
        if (call.method_name() == "present") {
          result->Success(flutter::EncodableValue(PresentWindow(GetHandle())));
        } else {
          result->NotImplemented();
        }
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
  window_channel_ = nullptr;
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
