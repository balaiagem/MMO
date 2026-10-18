@echo off
setlocal
cd /d "%~dp0"
title Tibia - atualizar cliente (Lua/UI)
set "GAME_PYTHON=%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
"%GAME_PYTHON%" "%~dp0tools\repack-client.py"
echo Recarregue a pagina do jogo (Ctrl+F5).
pause
