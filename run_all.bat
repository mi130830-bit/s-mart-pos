@echo off
start "Backend Server" cmd /k "cd /d c:\pos_desktop\backend & dart run bin/server.dart"
start "Web POS" cmd /k "cd /d c:\pos_desktop\pos_mini_web & npm run dev"
echo System starting...
