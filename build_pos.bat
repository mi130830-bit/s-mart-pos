@echo off
echo Building Flutter Windows App...
call flutter build windows --release
if %errorlevel% neq 0 (
    echo Flutter build failed.
    exit /b %errorlevel%
)
echo Flutter build successful. Packaging with Inno Setup...
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" "C:\pos_desktop\pos_desktop.iss"
if %errorlevel% neq 0 (
    echo Inno Setup packaging failed.
    exit /b %errorlevel%
)
echo Build and Package Complete!
