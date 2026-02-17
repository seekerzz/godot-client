@echo off
chcp 65001 >nul
echo =========================================
echo  Godot APK 导出工具 (国内镜像加速版)
echo =========================================
echo.

REM 设置 Gradle 国内镜像环境变量
set "GRADLE_USER_HOME=%USERPROFILE%\.gradle"
set "GRADLE_INIT_SCRIPT=%CD%\android\build\init.gradle"
set "GRADLE_OPTS=-Dorg.gradle.daemon=true -Dorg.gradle.parallel=true -Dorg.gradle.configureondemand=true"

REM 检查 Godot 是否安装
where godot >nul 2>nul
if %errorlevel% neq 0 (
    where godot4 >nul 2>nul
    if %errorlevel% neq 0 (
        echo [错误] 未找到 Godot 命令，请确保 Godot 已安装并添加到 PATH
        echo 请从 https://godotengine.org/ 下载 Godot 4.x 版本
        pause
        exit /b 1
    ) else (
        set "GODOT_CMD=godot4"
    )
) else (
    set "GODOT_CMD=godot"
)

echo [信息] 使用 Godot 命令: %GODOT_CMD%
echo [信息] 配置 Gradle 国内镜像加速...
echo.

REM 确保构建目录存在
if not exist "builds" mkdir builds

REM 导出 Android APK (Debug 版本)
echo [信息] 开始导出 APK (Debug 版本)...
echo [信息] 首次导出可能需要下载 Gradle，请耐心等待...
echo.

%GODOT_CMD% --headless --path . --export-release "Android" "builds/SensorDisplay.apk" 2>&1

if %errorlevel% neq 0 (
    echo.
    echo [错误] APK 导出失败！
    echo.
    echo 常见问题：
    echo 1. 确保已安装 Android 导出模板 (在 Godot 编辑器中：项目 -> 安装 Android 构建模板)
    echo 2. 确保已配置 Android SDK 路径 (编辑器设置 -> 导出 -> Android)
    echo 3. 检查项目路径是否包含中文或特殊字符
    echo.
    pause
    exit /b 1
)

echo.
echo =========================================
echo [成功] APK 导出完成！
echo =========================================
echo 输出文件: %CD%\builds\SensorDisplay.apk
echo.
pause
