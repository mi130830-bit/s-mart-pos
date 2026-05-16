#include "flutter_window.h"
#include <optional>

// ✅ Import ส่วนประกอบสำคัญ
#include "flutter/generated_plugin_registrant.h"
#include "desktop_multi_window/desktop_multi_window_plugin.h"
#include <windows.h>
#include <string>

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

// ✅ ฟังก์ชันเช็คว่า "ฉันคือหน้าต่างลูกใช่ไหม?"
bool IsMultiWindow() {
  int argc;
  wchar_t** argv = ::CommandLineToArgvW(::GetCommandLineW(), &argc);
  if (argv == nullptr) return false;

  bool is_multi = false;
  for (int i = 0; i < argc; ++i) {
    if (std::wstring(argv[i]) == L"multi_window") {
      is_multi = true;
      break;
    }
  }
  ::LocalFree(argv);
  return is_multi;
}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);

  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }

  // ----------------------------------------------------------------------
  // 🔥 ด่านตรวจคนเข้าเมือง (Logic คัดกรอง Plugin)
  // ----------------------------------------------------------------------
  if (IsMultiWindow()) {
    // 🟢 ถ้าเป็น "หน้าต่างลูก" (Customer Display):
    // อนุญาตให้เข้าแค่ "DesktopMultiWindow" ตัวเดียว! (เพื่อไว้คุยกับแม่)
    // ❌ Firebase และอื่นๆ ห้ามเข้า! (ตัดปัญหา Crash ทิ้งทันที)
    DesktopMultiWindowPluginRegisterWithRegistrar(
        flutter_controller_->engine()->GetRegistrarForPlugin("DesktopMultiWindowPlugin"));
  } else {
    // 🔵 ถ้าเป็น "หน้าต่างแม่" (Main POS):
    // เชิญเข้าได้หมดครับ (Firebase, Printer, ฯลฯ)
    RegisterPlugins(flutter_controller_->engine());
  }
  // ----------------------------------------------------------------------

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }
  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
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