#!/bin/bash

echo "=========================================="
echo "Android Sensors Test Script"
echo "=========================================="
echo ""

ADB_HOST="192.168.50.11"
ADB_PORT="38955"

echo "Connecting to device at $ADB_HOST:$ADB_PORT..."
adb disconnect 2>/dev/null || true
adb connect "$ADB_HOST:$ADB_PORT"
if [ $? -ne 0 ]; then
    echo "[ERROR] Failed to connect to ADB"
    exit 1
fi

echo "[SUCCESS] Connected"
echo ""

echo "Checking available sensors..."
echo "----------------------------------------"
adb shell "pm list features | grep sensor" 2>/dev/null || echo "(sensor feature list not available)"
echo ""

echo "Checking for rotation vector sensor (Type 11)..."
adb shell "dumpsys sensorservice | grep -i 'rotation\|game rotation'" 2>/dev/null || echo "(sensor service info not available)"
echo ""

echo "If you see 'android.hardware.sensor.rotation_vector' above, your device supports it."
echo ""

echo "Starting logcat for debugging..."
echo "Press Ctrl+C to stop"
echo "=========================================="

adb logcat -c
adb logcat AndroidSensors:D SensorSender:D Godot:D *:S
