; --- กำหนดชื่อแอปและเวอร์ชัน ---
#define MyAppName "S_MartPOS"
#define MyAppVersion "1.0.7+7"
#define MyAppPublisher "S_Mart"
#define MyAppExeName "pos_desktop.exe"

; --- สำคัญ: ชี้ไปที่โฟลเดอร์ Build ใหม่ที่คุณแจ้งมา ---
#define BuildPath "C:\pos_desktop\build\windows\x64\runner\Release"
#define ProjectPath "C:\pos_desktop"

[Setup]
AppId={{D43F6522-892F-4D49-B285-112233445566}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}

; ไฟล์ Setup ที่เสร็จแล้วจะไปอยู่ที่โฟลเดอร์ Output_Installer ใน C:\pos_desktop
OutputDir={#ProjectPath}\Output_Installer
OutputBaseFilename=S_MartPOS_Setup_v{#MyAppVersion}

Compression=lzma
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; 1. ดึงไฟล์ .exe หลัก
Source: "{#BuildPath}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion

; 2. ดึงไฟล์ *ทุกอย่าง* ที่เหลือ (DLL, data, plugins) มาหมดเลย อัตโนมัติ!
Source: "{#BuildPath}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

; 3. ✅ เพิ่มไฟล์ Start System (สำหรับเปิดเซิร์ฟเวอร์ + POS)
Source: "{#ProjectPath}\start_system.bat"; DestDir: "{app}"; Flags: ignoreversion

; 4. ✅ เพิ่มไฟล์ Setup Ngrok
Source: "{#ProjectPath}\setup_ngrok.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#ProjectPath}\ngrok.exe"; DestDir: "{app}"; Flags: ignoreversion

; 5. ✅ เพิ่มโฟลเดอร์ Backend (Server.exe)
Source: "{#ProjectPath}\backend\server.exe"; DestDir: "{app}\backend"; Flags: ignoreversion
Source: "{#ProjectPath}\backend\.env"; DestDir: "{app}\backend"; Flags: ignoreversion
; Optional: Include other backend assets if needed, but avoid full source code if possible
; Source: "{#ProjectPath}\backend\*"; DestDir: "{app}\backend"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
; สร้าง Shortcut สำหรับตัวเปิดระบบรวม (Server + POS)
Name: "{autodesktop}\Start S-Mart System (Server+POS)"; Filename: "{app}\start_system.bat"; IconFilename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{autodesktop}\Setup Ngrok Token"; Filename: "{app}\setup_ngrok.bat"; IconFilename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; รัน Start System แทนตัว exe เปล่าๆ เพื่อให้เปิดพร้อม Server (Optional: ติ๊กเลือกได้)
Filename: "{app}\start_system.bat"; Description: "Launch S-Mart POS System (with Server)"; Flags: nowait postinstall skipifsilent unchecked
Filename: "{app}\{#MyAppExeName}"; Description: "Launch POS Only (Client Mode)"; Flags: nowait postinstall skipifsilent
