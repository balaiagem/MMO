@echo off
setlocal
cd /d "%~dp0"
title Tibia - iniciar jogo local
set "GAME_PYTHON=%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
if not exist "%GAME_PYTHON%" (
  echo Python local nao encontrado. Verifique a instalacao do projeto.
  pause
  exit /b 1
)
"%GAME_PYTHON%" "%~dp0tools\start-local.py"
if errorlevel 1 (
  pause
  exit /b 1
)
timeout /t 8 >nul
