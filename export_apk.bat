@echo off
chcp 65001 >nul

:: Godot Android APK 导出脚本（使用国内镜像加速）

setlocal enabledelayedexpansion

set "PROJECT_DIR=%~dp0"
set "ANDROID_BUILD_DIR=%PROJECT_DIR%android\build"
set "EXPORT_PATH=%PROJECT_DIR%builds"
set "APK_NAME=SensorDisplay.apk"

echo ========================================
echo  Godot Android APK 导出工具
echo 使用阿里云镜像加速 Gradle 下载
echo ========================================

:: 创建导出目录
if not exist "%EXPORT_PATH%" mkdir "%EXPORT_PATH%"

:: 备份原始文件
echo [1/5] 备份原始 Gradle 配置...
copy /Y "%ANDROID_BUILD_DIR%\build.gradle" "%ANDROID_BUILD_DIR%\build.gradle.bak" >nul
copy /Y "%ANDROID_BUILD_DIR%\settings.gradle" "%ANDROID_BUILD_DIR%\settings.gradle.bak" >nul

:: 配置阿里云镜像
echo [2/5] 配置阿里云镜像...

:: 创建新的 build.gradle
call :WriteBuildGradle

:: 创建新的 settings.gradle
call :WriteSettingsGradle

:: 配置导出路径
echo [3/5] 配置导出路径...
echo     导出路径: %EXPORT_PATH%\%APK_NAME%

:: 更新 export_presets.cfg
powershell -Command "(Get-Content '%PROJECT_DIR%export_presets.cfg') -replace 'export_path=\".*\"', 'export_path=\"%EXPORT_PATH:/=\\%\\%APK_NAME%\"' | Set-Content '%PROJECT_DIR%export_presets.cfg'"

:: 执行导出
echo [4/5] 开始导出 APK...
echo     这可能需要几分钟，请耐心等待...
echo.

godot --headless --path "%PROJECT_DIR%" --export-release "Android" "%EXPORT_PATH%\%APK_NAME%" 2>&1 | tee "%EXPORT_PATH%\export.log"

set EXPORT_RESULT=%ERRORLEVEL%

:: 恢复原始文件
echo.
echo [5/5] 恢复原始 Gradle 配置...
copy /Y "%ANDROID_BUILD_DIR%\build.gradle.bak" "%ANDROID_BUILD_DIR%\build.gradle" >nul
copy /Y "%ANDROID_BUILD_DIR%\settings.gradle.bak" "%ANDROID_BUILD_DIR%\settings.gradle" >nul

:: 删除备份文件
del "%ANDROID_BUILD_DIR%\build.gradle.bak"
del "%ANDROID_BUILD_DIR%\settings.gradle.bak"

:: 检查结果
if %EXPORT_RESULT% == 0 (
    if exist "%EXPORT_PATH%\%APK_NAME%" (
        echo.
        echo ========================================
        echo 导出成功!
        echo APK 路径: %EXPORT_PATH%\%APK_NAME%
        echo ========================================
        dir "%EXPORT_PATH%\%APK_NAME%"
        exit /b 0
    )
)

echo.
echo ========================================
echo 导出失败!
echo 请查看日志: %EXPORT_PATH%\export.log
echo ========================================
exit /b 1

:WriteBuildGradle
(
echo // Gradle build config for Godot Engine's Android port.
echo plugins {
echo     id 'com.android.application'
echo     id 'org.jetbrains.kotlin.android'
echo }
echo.
echo apply from: 'config.gradle'
echo.
echo allprojects {
echo     repositories {
echo         // 阿里云镜像（优先）
echo         maven { url 'https://maven.aliyun.com/repository/google' }
echo         maven { url 'https://maven.aliyun.com/repository/public' }
echo         maven { url 'https://maven.aliyun.com/repository/gradle-plugin' }
echo         // 备用镜像
echo         google(^)
echo         mavenCentral(^)
echo         gradlePluginPortal(^)
echo         maven { url "https://plugins.gradle.org/m2/" }
echo         maven { url "https://central.sonatype.com/repository/maven-snapshots/"}
echo.
echo         // Godot user plugins custom maven repos
necho         String[] mavenRepos = getGodotPluginsMavenRepos(^)
echo         if (mavenRepos ^!= null ^&^& mavenRepos.size(^) ^> 0) {
echo             for (String repoUrl : mavenRepos) {
echo                 maven {
echo                     url repoUrl
echo                 }
echo             }
echo         }
echo     }
echo }
echo.
echo configurations {
echo     // Initializes a placeholder for the devImplementation dependency configuration.
echo     devImplementation {}
echo     // Initializes a placeholder for the monoImplementation dependency configuration.
echo     monoImplementation {}
echo }
echo.
echo dependencies {
echo     // Android instrumented test dependencies
echo     androidTestImplementation "androidx.test.ext:junit:$versions.junitVersion"
echo     androidTestImplementation "androidx.test.espresso:espresso-core:$versions.espressoCoreVersion"
echo     androidTestImplementation "org.jetbrains.kotlin:kotlin-test:$versions.kotlinTestVersion"
echo     androidTestImplementation "androidx.test:runner:$versions.testRunnerVersion"
echo     androidTestUtil "androidx.test:orchestrator:$versions.testOrchestratorVersion"
echo.
echo     implementation "androidx.fragment:fragment:$versions.fragmentVersion"
echo     implementation "androidx.core:core-splashscreen:$versions.splashscreenVersion"
echo.
echo     if (rootProject.findProject(":lib")) {
echo         implementation project(":lib")
echo     } else if (rootProject.findProject(":godot:lib")) {
echo         implementation project(":godot:lib")
echo     } else {
echo         // Godot gradle build mode. In this scenario this project is the only one around and the Godot
echo         // library is available through the pre-generated godot-lib.*.aar android archive files.
echo         debugImplementation fileTree(dir: 'libs/debug', include: ['**/*.jar', '*.aar'])
echo         devImplementation fileTree(dir: 'libs/dev', include: ['**/*.jar', '*.aar'])
echo         releaseImplementation fileTree(dir: 'libs/release', include: ['**/*.jar', '*.aar'])
echo     }
echo.
echo     // Godot user plugins remote dependencies
echo     String[] remoteDeps = getGodotPluginsRemoteBinaries(^)
echo     if (remoteDeps ^!= null ^&^& remoteDeps.size(^) ^> 0) {
echo         for (String dep : remoteDeps) {
echo             implementation dep
echo         }
echo     }
echo.
echo     // Godot user plugins local dependencies
echo     String[] pluginsBinaries = getGodotPluginsLocalBinaries(^)
echo     if (pluginsBinaries ^!= null ^&^& pluginsBinaries.size(^) ^> 0) {
echo         implementation files(pluginsBinaries)
echo     }
echo.
echo     // Automatically pick up local dependencies in res://addons
echo     String addonsDirectory = getAddonsDirectory(^)
echo     if (addonsDirectory ^!= null ^&^& ^!addonsDirectory.isBlank(^)) {
echo         implementation fileTree(dir: "$addonsDirectory", include: ['*.jar', '*.aar'])
echo     }
echo.
echo     // .NET dependencies
echo     String jar = '../../../../modules/mono/thirdparty/libSystem.Security.Cryptography.Native.Android.jar'
echo     if (file(jar).exists(^)) {
echo         monoImplementation files(jar)
echo     }
echo }
echo.
echo android {
echo     compileSdkVersion versions.compileSdk
echo     buildToolsVersion versions.buildTools
echo     ndkVersion versions.ndkVersion
echo.
echo     compileOptions {
echo         sourceCompatibility versions.javaVersion
echo         targetCompatibility versions.javaVersion
echo     }
echo.
echo     kotlinOptions {
echo         jvmTarget = versions.javaVersion
echo     }
echo.
echo     assetPacks = [":assetPackInstallTime"]
echo.
echo     namespace = 'com.godot.game'
echo.
echo     defaultConfig {
echo         // The default ignore pattern for the 'assets' directory includes hidden files and directories which are used by Godot projects.
echo         aaptOptions {
echo             ignoreAssetsPattern "!.svn:!.git:!.gitignore:!.ds_store:!*.scc:!CVS:!thumbs.db:!picasa.ini:!*~"
echo         }
echo.
echo         ndk {
echo             debugSymbolLevel 'NONE'
echo             String[] export_abi_list = getExportEnabledABIs(^)
echo             abiFilters export_abi_list
echo         }
echo.
echo         // Feel free to modify the application id to your own.
echo         applicationId getExportPackageName(^)
echo         versionCode getExportVersionCode(^)
echo         versionName getExportVersionName(^)
echo         minSdkVersion getExportMinSdkVersion(^)
echo         targetSdkVersion getExportTargetSdkVersion(^)
echo.
echo         missingDimensionStrategy 'products', 'template'
echo.
echo         testInstrumentationRunner "androidx.test.runner.AndroidJUnitRunner"
echo.
echo         // The following argument makes the Android Test Orchestrator run its
echo         // "pm clear" command after each test invocation. This command ensures
echo         // that the app's state is completely cleared between tests.
echo         testInstrumentationRunnerArguments clearPackageData: 'true'
echo     }
echo.
echo     testOptions {
echo         execution 'ANDROIDX_TEST_ORCHESTRATOR'
echo     }
echo.
echo     lintOptions {
echo         abortOnError false
echo         disable 'MissingTranslation', 'UnusedResources'
echo     }
echo.
echo     ndkVersion versions.ndkVersion
echo.
echo     packagingOptions {
echo         exclude 'META-INF/LICENSE'
echo         exclude 'META-INF/NOTICE'
echo.
echo         // Debug symbols are kept for development within Android Studio.
echo         if (shouldNotStrip(^)) {
echo             jniLibs {
echo                 keepDebugSymbols += '**/*.so'
echo             }
echo         }
echo.
echo         jniLibs {
echo             // Setting this to true causes AGP to package compressed native libraries when building the app
echo             // For more background, see:
echo             // - https://developer.android.com/build/releases/past-releases/agp-3-6-0-release-notes#extractNativeLibs
echo             // - https://stackoverflow.com/a/44704840
echo             useLegacyPackaging shouldUseLegacyPackaging(^)
echo         }
echo.
echo         // Always select Godot's version of libc++_shared.so in case deps have their own
echo         pickFirst 'lib/x86/libc++_shared.so'
echo         pickFirst 'lib/x86_64/libc++_shared.so'
echo         pickFirst 'lib/armeabi-v7a/libc++_shared.so'
echo         pickFirst 'lib/arm64-v8a/libc++_shared.so'
echo     }
echo.
echo     signingConfigs {
echo         debug {
echo             if (hasCustomDebugKeystore(^)) {
echo                 storeFile new File(getDebugKeystoreFile(^))
echo                 storePassword getDebugKeystorePassword(^)
echo                 keyAlias getDebugKeyAlias(^)
echo                 keyPassword getDebugKeystorePassword(^)
echo             }
echo         }
echo.
echo         release {
echo             File keystoreFile = new File(getReleaseKeystoreFile(^))
echo             if (keystoreFile.isFile(^)) {
echo                 storeFile keystoreFile
echo                 storePassword getReleaseKeystorePassword(^)
echo                 keyAlias getReleaseKeyAlias(^)
echo                 keyPassword getReleaseKeystorePassword(^)
echo             }
echo         }
echo     }
echo.
echo     buildFeatures {
echo         buildConfig = true
echo     }
echo.
echo     buildTypes {
echo.
echo         debug {
echo             // Signing and zip-aligning are skipped for prebuilt builds, but
echo             // performed for Godot gradle builds.
echo             zipAlignEnabled shouldZipAlign(^)
echo             if (shouldSign(^)) {
echo                 signingConfig signingConfigs.debug
echo             } else {
echo                 signingConfig null
echo             }
echo         }
echo.
echo         dev {
echo             initWith debug
echo             // Signing and zip-aligning are skipped for prebuilt builds, but
echo             // performed for Godot gradle builds.
echo             zipAlignEnabled shouldZipAlign(^)
echo             if (shouldSign(^)) {
echo                 signingConfig signingConfigs.debug
echo             } else {
echo                 signingConfig null
echo             }
echo         }
echo.
echo         release {
echo             // Signing and zip-aligning are skipped for prebuilt builds, but
echo             // performed for Godot gradle builds.
echo             zipAlignEnabled shouldZipAlign(^)
echo             if (shouldSign(^)) {
echo                 signingConfig signingConfigs.release
echo             } else {
echo                 signingConfig null
echo             }
echo         }
echo     }
echo.
echo     flavorDimensions 'edition'
echo.
echo     productFlavors {
echo         // Product flavor for the standard (no .net support) builds.
echo         standard {
echo             getIsDefault(^).set(true)
echo         }
echo.
echo         // Product flavor for the Mono (.net) builds.
echo         mono {}
echo.
echo         // Product flavor used for running instrumented tests.
echo         instrumented {
echo             applicationIdSuffix ".instrumented"
echo             versionNameSuffix "-instrumented"
echo         }
echo     }
echo.
echo     sourceSets {
echo         main.res.srcDirs += ['res']
echo         debug.jniLibs.srcDirs = ['libs/debug', 'libs/debug/vulkan_validation_layers']
echo         dev.jniLibs.srcDirs = ['libs/dev']
echo         release.jniLibs.srcDirs = ['libs/release']
echo     }
echo.
echo     applicationVariants.all { variant ->
echo         variant.outputs.all { output ->
echo             String filenameSuffix = variant.flavorName == "mono" ? variant.name : variant.buildType.name
echo             output.outputFileName = "android_${filenameSuffix}.apk"
echo         }
echo     }
echo }
echo.
echo task copyAndRenameBinary(type: Copy^) {
echo     // The 'doNotTrackState' is added to disable gradle's up-to-date checks for output files
echo     // and directories. Otherwise this check may cause permissions access failures on Windows
echo     // machines.
echo     doNotTrackState("No need for up-to-date checks for the copy-and-rename operation")
echo.
echo     String exportPath = getExportPath(^)
echo     String exportFilename = getExportFilename(^)
echo     String exportEdition = getExportEdition(^)
echo     String exportBuildType = getExportBuildType(^)
echo     String exportBuildTypeCapitalized = exportBuildType.capitalize(^)
echo     String exportFormat = getExportFormat(^)
echo.
echo     boolean isAab = exportFormat == "aab"
echo     boolean isMono = exportEdition == "mono"
echo     String filenameSuffix = isAab ? "${exportEdition}-${exportBuildType}" : exportBuildType
echo     if (isMono^) {
echo         filenameSuffix = isAab ? "${exportEdition}-${exportBuildType}" : "${exportEdition}${exportBuildTypeCapitalized}"
echo     }
echo.
echo     String sourceFilename = isAab ? "${project.name}-${filenameSuffix}.aab" : "android_${filenameSuffix}.apk"
echo     String sourceFilepath = isAab ? "$buildDir/outputs/bundle/${exportEdition}${exportBuildTypeCapitalized}/$sourceFilename" : "$buildDir/outputs/apk/$exportEdition/$exportBuildType/$sourceFilename"
echo.
echo     from sourceFilepath
echo     into exportPath
echo     rename sourceFilename, exportFilename
echo }
echo.
echo /**
echo  * Used to validate the version of the Java SDK used for the Godot gradle builds.
echo  */
echo task validateJavaVersion {
echo     if (^!JavaVersion.current(^).isCompatibleWith(versions.javaVersion^)) {
echo         throw new GradleException("Invalid Java version ${JavaVersion.current(^)}. Version ${versions.javaVersion} is the minimum supported Java version for Godot gradle builds.")
echo     }
echo }
echo.
echo /*
echo  * Older versions of our vendor plugin include a loader that we no longer need.
echo  * This code ensures those are removed.
echo  */
echo tasks.withType( com.android.build.gradle.internal.tasks.MergeNativeLibsTask^) {
echo     doFirst {
echo         externalLibNativeLibs.each { jniDir ->
echo             if (jniDir.getCanonicalPath(^).contains("godot-openxr-") ^|^| jniDir.getCanonicalPath(^).contains("godotopenxr"^)^) {
echo                 // Delete the 'libopenxr_loader.so' files from the vendors plugin so we only use the version from the
echo                 // openxr loader dependency.
echo                 File armFile = new File(jniDir, "arm64-v8a/libopenxr_loader.so")
echo                 if (armFile.exists(^)) {
echo                     armFile.delete(^)
echo                 }
echo                 File x86File = new File(jniDir, "x86_64/libopenxr_loader.so")
echo                 if (x86File.exists(^)) {
echo                     x86File.delete(^)
echo                 }
echo             }
echo         }
echo     }
echo }
echo.
echo /*
echo When they're scheduled to run, the copy*AARToAppModule tasks generate dependencies for the 'app'
echo module, so we're ensuring the ':app:preBuild' task is set to run after those tasks.
echo  */
echo if (rootProject.tasks.findByPath("copyDebugAARToAppModule"^) ^!= null^) {
echo     preBuild.mustRunAfter(rootProject.tasks.named("copyDebugAARToAppModule"^)^)
echo }
echo if (rootProject.tasks.findByPath("copyDevAARToAppModule"^) ^!= null^) {
echo     preBuild.mustRunAfter(rootProject.tasks.named("copyDevAARToAppModule"^)^)
echo }
echo if (rootProject.tasks.findByPath("copyReleaseAARToAppModule"^) ^!= null^) {
echo     preBuild.mustRunAfter(rootProject.tasks.named("copyReleaseAARToAppModule"^)^)
echo }
) > "%ANDROID_BUILD_DIR%\build.gradle"
goto :eof

:WriteSettingsGradle
(
echo // This is the root directory of the Godot Android gradle build.
echo pluginManagement {
echo     apply from: 'config.gradle'
echo.
echo     plugins {
echo         id 'com.android.application' version versions.androidGradlePlugin
echo         id 'org.jetbrains.kotlin.android' version versions.kotlinVersion
echo     }
echo     repositories {
echo         // 阿里云镜像（优先）
echo         maven { url 'https://maven.aliyun.com/repository/google' }
echo         maven { url 'https://maven.aliyun.com/repository/public' }
echo         maven { url 'https://maven.aliyun.com/repository/gradle-plugin' }
echo         // 备用镜像
echo         google(^)
echo         mavenCentral(^)
echo         gradlePluginPortal(^)
echo         maven { url "https://plugins.gradle.org/m2/" }
echo         maven { url "https://central.sonatype.com/repository/maven-snapshots/"}
echo     }
echo }
echo.
echo include ':assetPackInstallTime'
) > "%ANDROID_BUILD_DIR%\settings.gradle"
goto :eof
