@echo off
chcp 65001 >nul
echo =========================================
echo  Godot APK 导出工具 (国内镜像加速版)
echo =========================================
echo.

REM 设置 Gradle 国内镜像环境变量
set "GRADLE_USER_HOME=%USERPROFILE%\.gradle"
set "GRADLE_OPTS=-Dorg.gradle.daemon=true -Dorg.gradle.parallel=true -Dorg.gradle.configureondemand=true -Dorg.gradle.internal.network.retry.max.attempts=5"

REM 设置 Gradle Wrapper 使用腾讯镜像
set "GRADLE_WRAPPER_BASE_URL=https://mirrors.cloud.tencent.com/gradle/"

REM 设置初始化脚本路径
if exist "%CD%\android\build\init.gradle" (
    set "GRADLE_INIT_SCRIPT=%CD%\android\build\init.gradle"
)

echo [配置] Gradle 用户目录: %GRADLE_USER_HOME%
echo [配置] Gradle 初始化脚本: %GRADLE_INIT_SCRIPT%
echo [配置] Gradle Wrapper 镜像: %GRADLE_WRAPPER_BASE_URL%
echo.

REM 检查 Godot 是否安装
where godot >nul 2>nul
if %errorlevel% neq 0 (
    where godot4 >nul 2>nul
    if %errorlevel% neq 0 (
        echo [错误] 未找到 Godot 命令，请确保 Godot 已安装并添加到 PATH
        pause
        exit /b 1
    ) else (
        set "GODOT_CMD=godot4"
    )
) else (
    set "GODOT_CMD=godot"
)

echo [信息] 使用 Godot 命令: %GODOT_CMD%
echo.

REM 确保构建目录存在
if not exist "builds" mkdir builds

REM 检查并显示 Gradle Wrapper 配置
echo [信息] 当前 Gradle Wrapper 配置:
type "android\build\gradle\wrapper\gradle-wrapper.properties" | findstr "distributionUrl"
echo.

echo [信息] 开始导出 APK (Debug 版本)...
echo [信息] 首次导出会下载 Gradle 和依赖库，请耐心等待...
echo [信息] 已配置国内镜像加速下载
echo.

REM 使用 Debug 模式导出（避免 release 密钥库问题）
%GODOT_CMD% --headless --path . --export-debug "Android" "builds/SensorDisplay.apk" 2>&1

if %errorlevel% neq 0 (
    echo.
    echo [错误] APK 导出失败！
    echo.
    echo 常见问题：
    echo 1. 确保已安装 Android 导出模板 (项目 -> 安装 Android 构建模板)
    echo 2. 确保已配置 Android SDK 路径 (编辑器设置 -> 导出 -> Android)
    echo 3. 如 Gradle 下载失败，可手动下载放到 %USERPROFILE%\.gradle\wrapper\dists\
    echo.
    echo 手动下载 Gradle 8.11.1:
    echo https://mirrors.cloud.tencent.com/gradle/gradle-8.11.1-bin.zip
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
