@echo off
chcp 65001 > nul
echo ===================================================
echo   S-Link POS System Launcher (Server/Main Machine)
echo ===================================================
echo.

set "BASE_DIR=%~dp0"

:: 1. Start Backend Server
echo [1/3] Launching Backend Server (Port 8080)...
taskkill /F /FI "WINDOWTITLE eq S-Link Backend API*" /T >nul 2>&1
taskkill /F /IM server.exe /T >nul 2>&1
if exist "%BASE_DIR%backend\server.exe" (
    start "S-Link Backend API" /D "%BASE_DIR%backend" "%BASE_DIR%backend\server.exe"
) else (
    echo       [DEV MODE] Running from source...
    start "S-Link Backend API" /D "%BASE_DIR%backend" cmd /k "dart run bin/server.dart"
)
echo       Waiting for Backend to be ready (5 seconds)...
timeout /t 5 >nul

:: 2. Start Cloudflare Tunnel
echo [2/3] Launching Cloudflare Tunnel...
taskkill /F /FI "WINDOWTITLE eq Cloudflare Tunnel*" /T >nul 2>&1
taskkill /F /IM cloudflared.exe /T >nul 2>&1
if exist "%BASE_DIR%cloudflared.exe" (
    echo       Starting Tunnel...
    :: Launching Permanent Tunnel (pos)
    start "Cloudflare Tunnel" /D "%BASE_DIR%" cmd /k "cloudflared.exe tunnel run --token eyJhIjoiYmYwYzNmMTZmZTAwN2M4OTVmY2Q0OTI2MzQwNjVhMWYiLCJ0IjoiODFhNmFlOTctM2RlZS00OGIzLWE1NTYtNDc0Yjc1ZDljNDUwIiwicyI6Ik5tWTRZMlppTXpjdE56QTBPQzAwWXpjMUxUbGtZbU10WXpCaU9EZzNORE01TXpNNCJ9"
) else (
    echo       [WARNING] cloudflared.exe not found in %BASE_DIR%.
    echo       If you installed it globally, the service might already be running.
)
timeout /t 3 >nul

:: 3. Start POS Application
echo [3/3] Launching POS Desktop Application...
taskkill /F /IM pos_desktop.exe /T >nul 2>&1

:: Priority: 1. Installer Root 2. Build Release 3. Build Debug
if exist "%BASE_DIR%pos_desktop.exe" (
    start "POS Desktop" /D "%BASE_DIR%" "%BASE_DIR%pos_desktop.exe"
) else if exist "%BASE_DIR%build\windows\x64\runner\Release\pos_desktop.exe" (
    start "POS Desktop" /D "%BASE_DIR%build\windows\x64\runner\Release" "%BASE_DIR%build\windows\x64\runner\Release\pos_desktop.exe"
) else (
    echo [ERROR] pos_desktop.exe not found!
    echo         Please run 'flutter build windows --release' first.
    pause
    exit /b 1
)

echo.
echo ====================================
echo   All systems launched successfully!
echo ====================================
echo.
echo IMPORTANT:
echo   - Keep all black command windows OPEN (Backend API and Cloudflare)
echo   - Backend API: http://localhost:8080
echo.
echo This launcher window will automatically close in 5 seconds...
timeout /t 5 >nul
exit
