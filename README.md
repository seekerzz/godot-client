# Godot Android 传感器数据发送应用

一个基于 Godot 4.6 开发的 Android 应用，实时读取手机传感器数据并通过 UDP 网络发送到 PC 端进行 3D 可视化。

---

## 功能特性

- **传感器读取**: 加速度计、陀螺仪、重力传感器、磁力计
- **网络发送**: 通过 UDP 将数据实时发送到 PC 端
- **本地显示**: 同时显示传感器数值
- **录制回放**: 支持传感器数据录制和回放功能

---

## 项目结构

```
godot_client/
├── icon.svg                    # 应用图标
├── main.tscn                   # 主场景文件
├── project.godot               # 项目配置文件
├── sensor_sender.gd            # 传感器数据发送脚本
├── sensor_display.gd           # 传感器显示脚本
├── export_presets.cfg          # Android 导出配置
├── android/                    # Android 构建模板
│   ├── build/                  # Gradle 构建目录
│   │   ├── gradle.properties   # Gradle 属性配置
│   │   ├── settings.gradle     # Gradle 仓库配置
│   │   └── ...
│   └── plugins/                # Android 插件（如使用）
├── builds/                     # 构建输出目录
│   └── SensorDisplay.apk       # 生成的 APK 文件
└── README.md                   # 本文档
```

---

## 环境准备

### 1. 安装 Godot 导出模板

在 Godot 编辑器中：
```
项目 → 安装 Android 构建模板
```
或按 `Ctrl+Shift+A`

### 2. 配置 Android SDK

编辑器设置 → 导出 → Android：
- Android SDK 路径: `C:\Users\用户名\AppData\Local\Android\Sdk`
- Java SDK 路径: JDK 17+
- Debug Keystore: 自动生成或手动创建

### 3. 前置要求

| 工具 | 版本 | 说明 |
|------|------|------|
| Godot | 4.6+ | 游戏引擎 |
| Android SDK | 34.0.0+ | Android 构建工具 |
| JDK | 17+ | Java 开发工具包 |
| ADB | 最新版 | Android 调试桥 |

---

## 国内镜像加速配置

### 问题：Gradle 和依赖库下载极慢或超时

### 解决方案：

#### 1. Gradle Wrapper 配置（已配置）
文件：`android/build/gradle/wrapper/gradle-wrapper.properties`
```properties
distributionUrl=https\://mirrors.cloud.tencent.com/gradle/gradle-8.11.1-bin.zip
```

#### 2. Maven 仓库配置（已配置）
文件：`android/build/settings.gradle`
```gradle
pluginManagement {
    repositories {
        // 阿里云镜像（优先）
        maven { url 'https://maven.aliyun.com/repository/google' }
        maven { url 'https://maven.aliyun.com/repository/public' }
        maven { url 'https://maven.aliyun.com/repository/gradle-plugin' }
        // 备用
        google()
        mavenCentral()
    }
}
```

#### 3. 全局 Gradle 配置
文件：`~/.gradle/init.gradle`
```gradle
allprojects {
    buildscript {
        repositories {
            maven { url 'https://maven.aliyun.com/repository/google' }
            maven { url 'https://maven.aliyun.com/repository/public' }
            maven { url 'https://maven.aliyun.com/repository/gradle-plugin' }
            maven { url 'https://repo.huaweicloud.com/repository/maven/' }
            google()
            mavenCentral()
        }
    }
    repositories {
        maven { url 'https://maven.aliyun.com/repository/google' }
        maven { url 'https://maven.aliyun.com/repository/public' }
        maven { url 'https://maven.aliyun.com/repository/gradle-plugin' }
        maven { url 'https://repo.huaweicloud.com/repository/maven/' }
        google()
        mavenCentral()
    }
}
```

---

## 导出配置

### 1. 项目设置（project.godot）

**传感器配置**（必须使用 `enable_` 前缀）：
```ini
[input_devices]

sensors/enable_accelerometer=true
sensors/enable_gyroscope=true
sensors/enable_gravity=true
sensors/enable_magnetometer=true
```

**网络配置**：
```ini
[network]
limits/udp_server/max_clients=1
```

**显示配置**：
```ini
[display]
window/size/viewport_width=1080
window/size/viewport_height=1920
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
window/handheld/orientation=1
```

### 2. 导出预设（export_presets.cfg）

关键配置项：
```ini
[preset.0]
name="Android"
platform="Android"
export_path="builds/SensorDisplay.apk"

[preset.0.options]
; 使用固定包名，避免使用 $genname 动态生成
package/unique_name="com.example.sensordisplay"

; 启用 Gradle 构建
gradle_build/use_gradle_build=true

; 架构选择（推荐 arm64-v8a）
architectures/arm64-v8a=true
architectures/armeabi-v7a=false

; 签名配置
keystore/debug="C:/Users/Administrator/.config/godot/keystores/android_debug.keystore"
keystore/debug_user="androiddebugkey"
keystore/debug_password="android"
```

---

## 导出步骤

### 方法一：使用脚本导出（推荐）

运行提供的导出脚本：
```bash
# Windows
export_apk_cn.bat

# 或手动执行
export_apk_with_mirror.bat
```

### 方法二：命令行导出

```bash
# Debug 模式（推荐用于测试）
godot --headless --path . --export-debug "Android" "builds/SensorDisplay.apk"

# Release 模式（需要配置发布密钥库）
godot --headless --path . --export-release "Android" "builds/SensorDisplay.apk"
```

### 方法三：Godot 编辑器导出

1. 打开 Godot 编辑器
2. 项目 → 导出
3. 选择 "Android" 预设
4. 点击 "导出项目" 或 "一键导出"

---

## ADB 安装调试

### 连接设备

```bash
# 列出已连接设备
adb devices -l

# 连接网络设备（无线调试）
adb connect IP:端口
# 例如: adb connect 192.168.50.11:38955

# 断开设备
adb disconnect
```

### 安装 APK

```bash
# 安装/覆盖安装
adb install -r builds/SensorDisplay.apk

# 如果包名冲突，先卸载旧版本
adb uninstall com.example.sensordisplay
```

### 启动应用

**重要**：必须使用 `GodotAppLauncher` Activity：
```bash
# 正确启动方式 ✅
adb shell am start -n "com.example.sensordisplay/com.godot.game.GodotAppLauncher"

# 错误启动方式 ❌
# adb shell am start -n "com.example.sensordisplay/com.godot.game.GodotApp"
```

### 查看日志

```bash
# 清除旧日志
adb logcat -c

# 查看 Godot 相关日志
adb logcat -s "godot:*"

# 查看错误和警告
adb logcat | grep -E "ERROR|WARNING|Exception"

# 实时查看
adb logcat | grep godot
```

### 清除应用数据

```bash
adb shell pm clear com.example.sensordisplay
```

---

## 踩坑记录（避坑大全）

### 坑 1: 运行时报错 "Couldn't load file 'res://project.binary'"

**现象**：应用启动后崩溃，日志显示找不到项目数据文件

**原因**：
- 导出时未正确打包项目资源
- 使用了 `--export-debug` 但项目数据未生成

**解决**：
- 确保使用正确的导出命令（带 `--export-debug` 或 `--export-release`）
- 检查 `export_filter` 设置为 `"all_resources"`
- 重新导出 APK

### 坑 2: 包名冲突 / 多个包名混乱

**现象**：安装后出现 `com.godot.game` 和 `com.example.sensordisplay` 两个应用

**原因**：使用了 `$genname` 动态包名生成

**解决**：
在 `export_presets.cfg` 中设置固定包名：
```ini
package/unique_name="com.example.sensordisplay"
```

### 坑 3: 传感器数据获取失败

**现象**：日志显示 `input_devices/sensors/enable_accelerometer is not enabled`

**原因**：
- 项目设置中未启用传感器
- 配置格式错误（缺少 `enable_` 前缀）
- `SensorPlugin` 单例注册是异步的，应用刚启动时立即检查可能返回 `false`

**解决**：
```ini
[input_devices]
; 正确写法 ✅
sensors/enable_accelerometer=true
sensors/enable_gyroscope=true
sensors/enable_gravity=true
sensors/enable_magnetometer=true

; 错误写法 ❌
; sensors/accelerometer=true
```

插件注册延时相关建议：
- 启动后等待 `1~2` 秒再检查 `Engine.has_singleton("SensorPlugin")`
- 建议在 `_process` 前几帧做轮询，超时（如 `2s`）再判定失败
- 验证时不要只看 `am start -W` 成功，必须确认业务内插件状态

### 坑 4: Gradle 下载超时或失败

**现象**：首次导出时 Gradle 下载极慢或失败

**原因**：访问官方 Gradle 仓库超时

**解决**：
1. 配置腾讯云 Gradle 镜像（见上文）
2. 手动下载 Gradle 放到 `%USERPROFILE%\.gradle\wrapper\dists\`
3. 删除不完整的 Gradle 下载：
   ```bash
   rm -rf ~/.gradle/wrapper/dists/gradle-8.11.1-bin/
   ```

### 坑 5: 路径包含非 ASCII 字符导致构建失败

**现象**：Windows 下构建失败，提示路径错误

**原因**：项目路径包含中文或特殊字符

**解决**：
在 `android/build/gradle.properties` 中添加：
```properties
android.overridePathCheck=true
```

### 坑 6: 启动应用时 "Permission Denial"

**现象**：`adb shell am start` 报错，提示权限拒绝

**原因**：使用了错误的 Activity 名称

**解决**：
使用正确的 Activity 名称启动：
```bash
adb shell am start -n "com.example.sensordisplay/com.godot.game.GodotAppLauncher"
```

### 坑 7: Java 版本不兼容

**现象**：构建时提示 Java 版本错误

**原因**：Java 版本低于 17

**解决**：
- 安装 Java 17 或更高版本
- 配置 `JAVA_HOME` 环境变量
- 在 Godot 编辑器中设置正确的 Java SDK 路径

### 坑 8: APK 安装失败 - 无证书

**现象**：安装时报错 `INSTALL_PARSE_FAILED_NO_CERTIFICATES`

**原因**：APK 未签名

**解决**：
- 使用 Debug 签名：Godot 会自动使用 debug.keystore
- 或手动签名（见下文快速脚本）

### 坑 9: Godot 编辑器设置被覆盖

**问题**：修改 `editor_settings-4.6.tres` 后，Godot 启动时自动恢复旧配置

**解决**：在 Godot 编辑器关闭状态下修改，或直接在编辑器中设置：
```
编辑器 → 编辑器设置 → 导出 → Android
```

### 坑 10: Android SDK 路径冲突

**问题**：系统同时存在 `ANDROID_HOME` 和 `ANDROID_SDK_ROOT`

**解决**：
1. 统一使用 `ANDROID_HOME`
2. 删除冲突的 `ANDROID_SDK_ROOT`
3. 确保 Godot 编辑器设置中的路径正确

---

## 快速脚本

### 完整构建部署脚本（Windows）

创建 `build_and_deploy.bat`：
```batch
@echo off
chcp 65001 >nul
echo =========================================
echo  Godot APK 构建部署脚本
echo =========================================
echo.

REM 设置 Gradle 国内镜像
set "GRADLE_OPTS=-Dorg.gradle.daemon=true -Dorg.gradle.parallel=true"

REM 1. 导出 APK
echo [1/4] 正在导出 APK...
godot --headless --path . --export-debug "Android" "builds/SensorDisplay.apk"
if %errorlevel% neq 0 (
    echo [错误] 导出失败！
    pause
    exit /b 1
)

REM 2. 连接设备
echo [2/4] 连接设备...
adb connect localhost:38955 2>nul

REM 3. 安装 APK
echo [3/4] 安装 APK...
adb install -r "builds/SensorDisplay.apk"
if %errorlevel% neq 0 (
    echo [错误] 安装失败，尝试卸载后重装...
    adb uninstall com.example.sensordisplay
    adb install "builds/SensorDisplay.apk"
)

REM 4. 启动应用
echo [4/4] 启动应用...
adb shell am start -n "com.example.sensordisplay/com.godot.game.GodotAppLauncher"

echo.
echo [完成] 应用已启动！
pause
```

### 手动签名脚本（如需要）

```bash
# 创建调试密钥库
keytool -genkey -v \
    -keystore debug.keystore \
    -alias androiddebugkey \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass android -keypass android \
    -dname "CN=Android Debug,O=Android,C=US"

# 签名 APK
$ANDROID_HOME/build-tools/34.0.0/apksigner sign \
    --ks ./debug.keystore \
    --ks-pass pass:android \
    --key-pass pass:android \
    --out ./signed.apk \
    ./unsigned.apk
```

---

## AndroidSensors 插件（可选）

如果需要使用 AndroidSensors 插件获取更丰富的传感器数据：

### 插件 API

```gdscript
# 获取插件单例
var android_sensors = Engine.get_singleton("AndroidSensors")

# 启动旋转矢量传感器 (Type 11)
if android_sensors:
    var success = android_sensors.startSensor(11, 10000)  # 10ms = 100Hz
    if success:
        print("旋转矢量传感器启动成功")

# 获取传感器数据
var data = android_sensors.getSensorData(11)
if data.size() >= 4:
    var x = data[0]
    var y = data[1]
    var z = data[2]
    var w = data[3]
    # 坐标系转换: Android -> Godot
    var quat = Quaternion(x, z, -y, w)
```

### 传感器类型常量

| 值 | 名称 | 说明 |
|----|------|------|
| 1 | TYPE_ACCELEROMETER | 加速度计 |
| 4 | TYPE_GYROSCOPE | 陀螺仪 |
| 9 | TYPE_GRAVITY | 重力 |
| 10 | TYPE_LINEAR_ACCELERATION | 线性加速度 |
| 11 | TYPE_ROTATION_VECTOR | **旋转矢量 (推荐)** |
| 15 | TYPE_GAME_ROTATION_VECTOR | 游戏旋转矢量 |

---

## 检查清单

导出 APK 前确认：
- [ ] 已安装 Android 构建模板
- [ ] 已配置 Android SDK 和 Java SDK 路径
- [ ] 包名设置为固定值（非 `$genname`）
- [ ] 传感器已启用（使用 `enable_` 前缀）
- [ ] 已配置国内镜像加速
- [ ] 选择正确的架构（arm64-v8a）
- [ ] PC 端 IP 地址正确配置

安装调试时确认：
- [ ] 设备已通过 ADB 连接
- [ ] 使用 `-r` 参数覆盖安装
- [ ] 使用 `GodotAppLauncher` 启动
- [ ] 使用 `logcat` 查看运行日志
- [ ] 启动后等待 `1~2` 秒再判断 `SensorPlugin` 是否注册成功
- [ ] 用 `adb shell run-as com.example.sensordisplay cat files/plugin_check.txt` 确认 `plugin_ready=true`

---

## 参考链接

- [阿里云 Maven 仓库](https://developer.aliyun.com/mvn/guide)
- [腾讯云 Gradle 镜像](https://mirrors.cloud.tencent.com/gradle/)
- [Godot Android 导出文档](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)
- [Godot 传感器输入文档](https://docs.godotengine.org/en/stable/classes/class_input.html)

---

## 许可证

MIT License
