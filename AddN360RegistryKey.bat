@echo off
REM Batch script to add N360 registry key
REM Creates: HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\N360
REM 32-bit OS HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\N360
REM 64-bit OS HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\N360

echo N360 Registry Key Creation Script
echo =================================

REM Check for administrator privileges
net session >nul 2>&1
if %errorLevel% == 0 (
    echo Running with Administrator privileges...
) else (
    echo This script requires Administrator privileges.
    echo Please run as Administrator.
    exit /b 1
)

REM Create the registry key
echo Creating registry key...
reg add "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\N360" /f
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\N360" /f

if %errorLevel% == 0 (
    echo Registry key created successfully!
) else (
    echo Failed to create registry key.
    exit /b 1
)

echo.
echo Operation completed successfully.