@echo off
:: AI CLI Docker Container Manager Launcher
:: Double-click this file to open the management menu

title AI CLI Docker Manager

:: Check if PowerShell is available
where powershell >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo PowerShell not found. Please install PowerShell.
    pause
    exit /b 1
)

:: Get the directory where this script is located
set "SCRIPT_DIR=%~dp0"

:: Run the PowerShell management script
powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%manage-container.ps1"

pause
