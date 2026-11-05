@echo off
cd /d "%~dp0"
set "GODOT=%~dp0..\..\tools\godot\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" (
  echo Godot not found: %GODOT%
  pause
  exit /b 1
)
start "" "%GODOT%" --path .
