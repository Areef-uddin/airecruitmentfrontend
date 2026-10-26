@echo off
title TalentAI Frontend (Port 3000)
cd /d "c:\Users\home\Documents\djanolearning\New folder (2)\ai_recruitment\frontend"

echo ====================================================
echo   TalentAI Frontend Server (Port 3000)
echo   Backend URL: https://airecruitmentbackend.onrender.com/api
echo ====================================================

:: Terminate any hanging dart or flutter processes
taskkill /F /IM dart.exe >nul 2>&1

echo Launching Flutter Web Server on http://localhost:3000 ...
flutter run -d web-server --web-port 3000 --web-hostname 0.0.0.0

pause
