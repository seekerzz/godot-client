@echo off
setlocal enabledelayedexpansion

echo ==========================================
echo Godot AndroidSensors Export and Deploy
echo ==========================================
echo.

REM Configuration
set "GODOT_EXE=/d/tools/godot.exe"
set "PROJECT_PATH=/c/Users/Administrator/Desktop/godot_pingpong/godot_client"
set "APK_NAME=SensorDisplayWithPlugin.apk"
set "ADB_HOST=192.168.50.11"
set "ADB_PORT=38955"
set "PC_IP=192.168.50.64"
set "PC_PORT=49555"

echo [1/5] Exporting APK from Godot...
echo     Project: %PROJECT_PATH%
echo     Output: %PROJECT_PATH%/%APK_NAME%
echo.

cd /d "%PROJECT_PATH%"
"%GODOT_EXE%" --headless --export-release "Android" "./%APK_NAME%"

if errorlevel 1 (
    echo [ERROR] Godot export failed!
    echo.
    echo Possible causes:
    echo - Godot editor is currently running (close it and retry)
    echo - Export template not installed
    echo - Android build template not installed
    echo.
    pause
    exit /b 1
)

echo [SUCCESS] APK exported: %APK_NAME%
echo.

REM Check if APK exists
if not exist "%APK_NAME%" (
    echo [ERROR] APK file not found after export!
    pause
    exit /b 1
)

echo [2/5] Connecting to ADB...
echo     Target: %ADB_HOST%:%ADB_PORT%
echo.

adb disconnect 2>nul
adb connect %ADB_HOST%:%ADB_PORT%

if errorlevel 1 (
    echo [ERROR] Failed to connect to ADB!
    echo.
    echo Make sure:
    echo - ADB is installed and in PATH
    echo - Phone is connected to WiFi at %ADB_HOST%
    echo - ADB over network is enabled on phone (adb tcpip 5555)
    echo.
    pause
    exit /b 1
)

echo [SUCCESS] ADB connected
echo.
echo [3/5] Installing APK...

adb install -r "%APK_NAME%"

if errorlevel 1 (
    echo [ERROR] APK installation failed!
    echo.
    echo Possible causes:
    echo - APK signature mismatch (uninstall old version first)
    echo - Insufficient storage on device
    echo.
    echo Try: adb uninstall com.example.sensordisplay
    echo.
    pause
    exit /b 1
)

echo [SUCCESS] APK installed
echo.
echo [4/5] Setting up port forwarding for UDP...
echo     PC: %PC_IP%:%PC_PORT% ^<-- Phone sensor data

echo [INFO] Port forwarding not needed for UDP

echo.
echo [5/5] Starting logcat monitoring...
echo ==========================================
echo Filters:
echo   AndroidSensors: Plugin logs
echo   Godot:          Godot engine logs
echo   SensorSender:   GDScript logs
echo.
echo Press Ctrl+C to stop logging
echo ==========================================
echo.

adb logcat -c
adb logcat AndroidSensors:D SensorSender:D Godot:D *:S

endlocal
