@echo off
setlocal
cd /d "%~dp0.."
set "GAME_PYTHON=%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
"%GAME_PYTHON%" "%~dp0restart-server.py" > "%~dp0..\runtime\restart-server.log" 2>&1
type "%~dp0..\runtime\restart-server.log"
timeout /t 5 >nul
