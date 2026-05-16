@echo off
chcp 65001 > nul
cls
echo ===================================================
echo   S-Link POS System - Ngrok Setup
echo ===================================================
echo.
echo This script will help you register your Ngrok Authtoken.
echo This is REQUIRED for Line OA integration to work.
echo.
echo 1. Go to https://dashboard.ngrok.com/signup and login.
echo 2. Copy your Authtoken from "Your Authtoken" page.
echo.
set /p token="Paste your Ngrok Authtoken here: "

if "%token%"=="" (
    echo.
    echo [ERROR] Token cannot be empty.
    pause
    exit /b
)

echo.
echo Registering token...
set "BASE_DIR=%~dp0"
if exist "%BASE_DIR%ngrok.exe" (
    "%BASE_DIR%ngrok.exe" config add-authtoken "%token%"
) else (
    echo [ERROR] ngrok.exe not found in this folder!
    echo         Please make sure ngrok.exe is installed correctly.
    pause
    exit /b
)

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Failed to register token. Please try again.
) else (
    echo.
    echo [SUCCESS] Ngrok Authtoken registered successfully!
    echo You can now run "Start S-Mart System" to start the server.
)

pause
