#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/encodable_value.h>

#include "flutter_window.h"
#include "utils.h"

#include <desktop_multi_window/desktop_multi_window_plugin.h>
#include <window_manager/window_manager_plugin.h>

// ✅ 1. ต้องมีฟังก์ชันนี้ เพื่อเลือกโหลดเฉพาะ Plugin ที่จำเป็นให้จอ 2
void RegisterPluginsForSecondaryWindow(flutter::PluginRegistry* registry) {
  // 🟢 เปิดตัวนี้: เพื่อให้รับส่งข้อมูลกับจอแม่ได้ (แก้ CHANNEL_UNREGISTERED)
  DesktopMultiWindowPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("DesktopMultiWindowPlugin"));

  // ✅ เปิดตัวนี้: เพื่อให้จัดตำแหน่งและทำ Fullscreen จอ 2 ได้
  WindowManagerPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("WindowManagerPlugin"));

  // 🔴 ปิดพวกนี้ให้หมด: เพื่อกัน Crash (Firebase C++ API ยังไม่รองรับ Multi-Window ดีนัก)
  // FirebaseAuthPluginCApiRegisterWithRegistrar(registry->GetRegistrarForPlugin("FirebaseAuthPluginCApi"));
  // FirebaseCorePluginCApiRegisterWithRegistrar(registry->GetRegistrarForPlugin("FirebaseCorePluginCApi"));
}

// ฟังก์ชันช่วยจัดตำแหน่งหน้าต่าง (เก็บไว้ใช้ได้)
void WindowUtilsHandler(
    const flutter::MethodCall<flutter::EncodableValue> &call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result,
    flutter::FlutterViewController *controller) {
  if (call.method_name() == "setBounds") {
    const auto *arguments = std::get_if<flutter::EncodableMap>(call.arguments());
    if (arguments) {
       auto x_it = arguments->find(flutter::EncodableValue("x"));
       auto y_it = arguments->find(flutter::EncodableValue("y"));
       auto w_it = arguments->find(flutter::EncodableValue("width"));
       auto h_it = arguments->find(flutter::EncodableValue("height"));
       
       if (x_it != arguments->end() && y_it != arguments->end() &&
           w_it != arguments->end() && h_it != arguments->end()) {
           
           double x = std::get<double>(x_it->second);
           double y = std::get<double>(y_it->second);
           double width = std::get<double>(w_it->second);
           double height = std::get<double>(h_it->second);

           HWND hwnd = controller->view()->GetNativeWindow();
           SetWindowPos(hwnd, HWND_TOP, (int)x, (int)y, (int)width, (int)height, SWP_SHOWWINDOW);
           result->Success();
           return;
       }
    }
    result->Error("INVALID_ARGUMENTS", "Missing x, y, width, or height");
  } else {
    result->NotImplemented();
  }
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  
  // Callback นี้จะทำงานเมื่อจอ 2 ถูกสร้าง
  DesktopMultiWindowSetWindowCreatedCallback([](void *controller) {
    auto *flutter_view_controller =
        static_cast<flutter::FlutterViewController *>(controller);
    
    // ✅ 2. เรียกฟังก์ชัน Register ที่เราเตรียมไว้ (จุดสำคัญที่สุด!)
    // ถ้าไม่มีบรรทัดนี้ จอ 2 จะเป็นใบ้ คุยกับใครไม่ได้
    RegisterPluginsForSecondaryWindow(flutter_view_controller->engine());

    // Channel พิเศษสำหรับย้ายตำแหน่งจอ
    static auto channel =
        std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            flutter_view_controller->engine()->messenger(), "pos_desktop/window_utils",
            &flutter::StandardMethodCodec::GetInstance());

    channel->SetMethodCallHandler(
        [flutter_view_controller](const auto &call, auto result) {
            WindowUtilsHandler(call, std::move(result), flutter_view_controller);
        });
  });

  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"s_link", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}