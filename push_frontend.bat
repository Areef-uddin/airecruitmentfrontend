@echo off
cd /d "%~dp0"
echo Adding all changes...
git add .
git commit -m "fix: safe AI field parsing in recruiter create job screen and vercel config"
git push origin main
echo Done!
pause
