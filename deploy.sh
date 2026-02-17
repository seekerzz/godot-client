#!/bin/bash
set -e

echo "=========================================="
echo "Godot AndroidSensors Export and Deploy"
echo "=========================================="
echo ""

# Configuration
GODOT_EXE="/d/tools/godot.exe"
PROJECT_PATH="/c/Users/Administrator/Desktop/godot_pingpong/godot_client"
APK_NAME="SensorDisplayWithPlugin.apk"
ADB_HOST="192.168.50.11"
ADB_PORT="38955"
PC_IP="192.168.50.64"
PC_PORT="49555"

cd "$PROJECT_PATH"

echo "[1/5] Exporting APK from Godot..."
echo "    Project: $PROJECT_PATH"
echo "    Output: $PROJECT_PATH/$APK_NAME"
echo ""

"$GODOT_EXE" --headless --export-release "Android" "./$APK_NAME"

if [ ! -f "$APK_NAME" ]; then
    echo "[ERROR] APK export failed or file not found!"
    exit 1
fi

echo "[SUCCESS] APK exported: $APK_NAME"
echo ""

echo "[2/5] Connecting to ADB..."
echo "    Target: $ADB_HOST:$ADB_PORT"
echo ""

adb disconnect 2>/dev/null || true
adb connect "$ADB_HOST:$ADB_PORT"

echo "[SUCCESS] ADB connected"
echo ""
echo "[3/5] Installing APK..."

adb install -r "$APK_NAME"

echo "[SUCCESS] APK installed"
echo ""
echo "[4/5] Setup complete"
echo ""
echo "[5/5] Starting logcat..."
echo "=========================================="
echo "Press Ctrl+C to stop logging"
echo "=========================================="
echo ""

adb logcat -c
adb logcat AndroidSensors:D SensorSender:D Godot:D dalvikvm:D *:S
