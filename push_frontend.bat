@echo off
cd /d "%~dp0"
echo Adding all changes...
git add .
git commit -m "Configure Vercel deployment with build.sh and vercel.json"
git push origin main
echo Done!
pause
