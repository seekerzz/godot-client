# Godot Android 传感器数据展示应用

一个基于 Godot 4.3 开发的 Android 应用，实时显示手机加速度计、陀螺仪、重力传感器和磁力计数据。

---

## 功能特性

- **加速度计 (Accelerometer)**: 显示 X/Y/Z 三轴加速度数据 (单位: m/s²)
- **陀螺仪 (Gyroscope)**: 显示 X/Y/Z 三轴角速度数据 (单位: rad/s)
- **重力传感器 (Gravity)**: 显示重力方向数据 (单位: m/s²)
- **磁力计 (Magnetometer)**: 显示磁场强度数据 (单位: μT)

---

## 项目结构

```
godot_snake/
├── icon.svg              # 应用图标
├── main.tscn             # 主场景文件
├── sensor_display.gd     # 传感器数据显示脚本
├── export_presets.cfg    # Android 导出配置
└── sensor_display.apk    # 构建好的 APK 文件
```

---

## 构建过程总结

### 1. ADB 无线调试配置

```bash
# 1. 配对设备（配对码会定期更新）
adb pair 192.168.50.11:45751 268360

# 2. 连接设备
adb connect 192.168.50.11:38415

# 3. 验证连接
adb devices
```

### 2. Godot 项目配置

#### 场景结构
- 根节点: `Control` (全屏界面)
- 子节点: 多个 `Label` 用于显示各传感器数据
- 使用 `%UniqueName` 语法在脚本中引用节点

#### 核心代码逻辑
```gdscript
# 在 _process 中每帧读取传感器数据
func _process(_delta):
    var accel = Input.get_accelerometer()    # 加速度计
    var gyro = Input.get_gyroscope()         # 陀螺仪
    var gravity = Input.get_gravity()        # 重力
    var magneto = Input.get_magnetometer()   # 磁力计
```

### 3. Android 导出配置

编辑 `export_presets.cfg` 关键配置：

```ini
[preset.0]
name="Android"
platform="Android"
export_path="./sensor_display.apk"

[preset.0.options]
gradle_build/use_gradle_build=true
architectures/armeabi-v7a=false
architectures/arm64-v8a=true
package/unique_name="com.example.sensordisplay"
package/name="传感器数据显示"
keystore/debug="./debug.keystore"
keystore/debug_user="androiddebugkey"
keystore/debug_password="android"
```

---

## 踩坑记录

### 坑 1: Godot 编辑器设置被覆盖

**问题**: 修改 `editor_settings-4.3.tres` 后，Godot 启动时会自动恢复旧配置。

**解决**: 在 Godot 编辑器关闭状态下修改，或直接在编辑器中设置：
```
编辑器 → 编辑器设置 → 导出 → Android
```

### 坑 2: Android SDK 路径冲突

**问题**: 系统同时存在 `ANDROID_HOME` 和 `ANDROID_SDK_ROOT`，且 Godot 编辑器中配置的 SDK 路径与实际路径不一致。

**解决**:
1. 统一使用 `ANDROID_HOME` 指向 `D:/tools/android-sdk`
2. 删除冲突的 `ANDROID_SDK_ROOT`
3. 确保 Godot 编辑器设置中的路径正确：
   - `export/android/android_sdk_path = "D:/tools/android-sdk"`
   - `export/android/java_sdk_path = "D:/tools/jdk-17"`

### 坑 3: 密钥库签名失败

**问题**: Godot 命令行导出时提示 "找不到密钥库"，即使路径正确也无法识别。

**解决**: 采用手动签名方案：

```bash
# 1. 导出未签名的 APK
godot --headless --export-release Android ./sensor_display_unsigned.apk

# 2. 创建调试密钥库
keytool -genkey -v \
    -keystore debug.keystore \
    -alias androiddebugkey \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass android -keypass android \
    -dname "CN=Android Debug,O=Android,C=US"

# 3. 使用 apksigner 签名
/path/to/android-sdk/build-tools/34.0.0/apksigner.bat sign \
    --ks debug.keystore \
    --ks-pass pass:android \
    --key-pass pass:android \
    --out sensor_display.apk \
    sensor_display_unsigned.apk
```

### 坑 4: APK 安装失败 - 无证书

**问题**: 未签名的 APK 安装时报错 `INSTALL_PARSE_FAILED_NO_CERTIFICATES`

**原因**: Android 系统要求所有 APK 必须经过数字签名才能安装

**解决**: 使用上述手动签名流程

### 坑 5: 缺少应用图标

**问题**: 导出时提示 `Error opening file 'res://icon.svg'`

**解决**: 在项目根目录创建简单的 SVG 图标文件

### 坑 6: 设备连接断开

**问题**: ADB 无线连接在一段时间后会自动断开

**解决**: 重新执行连接命令：
```bash
adb connect 192.168.50.11:38415
```

---

## 快速构建脚本

```bash
#!/bin/bash

# 1. 连接设备
adb connect 192.168.50.11:38415

# 2. 导出未签名 APK
godot --headless --export-release Android ./sensor_display_unsigned.apk

# 3. 签名
$ANDROID_HOME/build-tools/34.0.0/apksigner.bat sign \
    --ks ./debug.keystore \
    --ks-pass pass:android \
    --key-pass pass:android \
    --out ./sensor_display.apk \
    ./sensor_display_unsigned.apk

# 4. 安装
adb install -r ./sensor_display.apk

# 5. 启动
adb shell am start -n com.example.sensordisplay/com.godot.game.GodotApp

# 6. 清理
rm ./sensor_display_unsigned.apk
```

---

## 环境要求

| 工具 | 版本 | 路径 |
|------|------|------|
| Godot | 4.3 stable | - |
| Android SDK | 34.0.0 | D:/tools/android-sdk |
| JDK | 17 | D:/tools/jdk-17 |
| ADB | 最新版 | $ANDROID_HOME/platform-tools |

---

## 参考链接

- [Godot Android 导出文档](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)
- [Godot 传感器输入文档](https://docs.godotengine.org/en/stable/classes/class_input.html)
