@echo off
setlocal
cd /d "%~dp0"
title Tibia - reiniciar servidor
echo Deslogue os personagens antes de continuar (o progresso e salvo no logout).
pause
set "GAME_PYTHON=%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
"%GAME_PYTHON%" "%~dp0tools\restart-server.py"
pause
