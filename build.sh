#!/usr/bin/env bash
# build.sh — Unified Build Script for Seamless Connect
# Compiles Android Companion App, packages Magisk/KSU/APatch module, and prepares releases.
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"

if [ -z "$SDK_ROOT" ]; then
    if [ -d "$HOME/android_sdk" ]; then
        SDK_ROOT="$HOME/android_sdk"
    elif [ -d "$HOME/Android/Sdk" ]; then
        SDK_ROOT="$HOME/Android/Sdk"
    fi
fi

if [ -z "$SDK_ROOT" ] || [ ! -d "$SDK_ROOT" ]; then
    echo "Error: Android SDK not found! Please set ANDROID_SDK_ROOT or ANDROID_HOME."
    exit 1
fi

PLATFORM_JAR="$SDK_ROOT/platforms/android-34/android.jar"
if [ ! -f "$PLATFORM_JAR" ]; then
    PLATFORM_JAR="$(find "$SDK_ROOT/platforms" -name "android.jar" 2>/dev/null | sort -V | tail -n 1)"
fi

BUILD_TOOLS_DIR="$(find "$SDK_ROOT/build-tools" -maxdepth 1 -mindepth 1 2>/dev/null | sort -V | tail -n 1)"
AAPT2="$BUILD_TOOLS_DIR/aapt2"
D8="$BUILD_TOOLS_DIR/d8"
ZIPALIGN="$BUILD_TOOLS_DIR/zipalign"
APKSIGNER="$BUILD_TOOLS_DIR/apksigner"

echo "========================================================"
echo "          Seamless Connect Build System                 "
echo "========================================================"
echo "SDK:         $SDK_ROOT"
echo "Platform:    $PLATFORM_JAR"
echo "Build Tools: $BUILD_TOOLS_DIR"
echo "========================================================"

BUILD_DIR="$PROJECT_DIR/build"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/app/classes" "$BUILD_DIR/app/gen" "$BUILD_DIR/release"

# 1. Compile Android Companion App
echo "--> [1/4] Compiling Android resources with AAPT2..."
"$AAPT2" compile --dir "$PROJECT_DIR/android/src/main/res" -o "$BUILD_DIR/app/compiled.zip"

echo "--> [2/4] Linking APK and generating R.java..."
"$AAPT2" link -I "$PLATFORM_JAR" \
    --manifest "$PROJECT_DIR/android/AndroidManifest.xml" \
    --java "$BUILD_DIR/app/gen" \
    -o "$BUILD_DIR/app/unaligned.apk" \
    "$BUILD_DIR/app/compiled.zip"

echo "--> [3/4] Compiling Java classes..."
javac -cp "$PLATFORM_JAR" -d "$BUILD_DIR/app/classes" \
    "$BUILD_DIR/app/gen/com/seamlessconnect/R.java" \
    "$PROJECT_DIR/android/src/main/java/com/seamlessconnect/"*.java

echo "--> [4/4] D8 desugaring and dexing..."
"$D8" --lib "$PLATFORM_JAR" --output "$BUILD_DIR/app" "$BUILD_DIR/app/classes/com/seamlessconnect/"*.class

(cd "$BUILD_DIR/app" && zip -u unaligned.apk classes.dex)
"$ZIPALIGN" -f 4 "$BUILD_DIR/app/unaligned.apk" "$BUILD_DIR/release/SeamlessConnect.apk"

# Sign APK
KEYSTORE="$BUILD_DIR/debug.keystore"
if [ ! -f "$KEYSTORE" ]; then
    keytool -genkeypair -v -keystore "$KEYSTORE" -alias androiddebugkey \
        -keypass android -storepass android -keyalg RSA -keysize 2048 \
        -validity 10000 -dname "CN=SeamlessConnect,O=OpenSource,C=US" 2>/dev/null
fi
"$APKSIGNER" sign --ks "$KEYSTORE" --ks-pass pass:android --key-pass pass:android "$BUILD_DIR/release/SeamlessConnect.apk"
echo "✓ Companion App built: $BUILD_DIR/release/SeamlessConnect.apk"

# 2. Package into Magisk Module
echo ""
echo "--> Packaging Magisk / KernelSU / APatch module..."
mkdir -p "$PROJECT_DIR/magisk_module/system/app/SeamlessConnect"
cp -f "$BUILD_DIR/release/SeamlessConnect.apk" "$PROJECT_DIR/magisk_module/system/app/SeamlessConnect/SeamlessConnect.apk"
chmod 644 "$PROJECT_DIR/magisk_module/system/app/SeamlessConnect/SeamlessConnect.apk"
chmod 755 "$PROJECT_DIR/magisk_module/system/bin/seamless-ctl"
chmod 755 "$PROJECT_DIR/magisk_module/files/ftp-server.sh"
chmod 755 "$PROJECT_DIR/magisk_module/service.sh"

MAGISK_ZIP="$BUILD_DIR/release/seamless_connect_magisk.zip"
(cd "$PROJECT_DIR/magisk_module" && zip -r -FS "$MAGISK_ZIP" .)
echo "✓ Magisk Module packaged: $MAGISK_ZIP"

echo ""
echo "========================================================"
echo " Build Complete!"
echo " APK:    $BUILD_DIR/release/SeamlessConnect.apk"
echo " Module: $MAGISK_ZIP"
echo "========================================================"
