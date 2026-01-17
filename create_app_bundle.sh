#!/bin/bash
set -e

APP_NAME="FlowState"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"

echo "🚀 Building ${APP_NAME} for release..."
swift build -c release --arch arm64

echo "📦 Creating App Bundle Structure..."
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy executable
cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"

# Fix RPATH to include Frameworks folder
install_name_tool -add_rpath "@executable_path/../Frameworks" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"


# Copy Resource Bundles (MLX, etc.)
if [ -d "${BUILD_DIR}/mlx-swift_Cmlx.bundle" ]; then
    echo "📦 Copying MLX Resource Bundle..."
    cp -r "${BUILD_DIR}/mlx-swift_Cmlx.bundle" "${APP_BUNDLE}/Contents/Resources/"
fi

# Copy Frameworks (Sparkle)
mkdir -p "${APP_BUNDLE}/Contents/Frameworks"
if [ -d "${BUILD_DIR}/Sparkle.framework" ]; then
    echo "📦 Copying Sparkle Framework..."
    cp -r "${BUILD_DIR}/Sparkle.framework" "${APP_BUNDLE}/Contents/Frameworks/"
fi

# Create Info.plist (Always overwrite to ensure updates)
# if [ ! -f "${APP_BUNDLE}/Contents/Info.plist" ]; then
cat <<EOF > "${APP_BUNDLE}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.flowstate.app</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleShortVersionString</key>
    <string>2.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>com.flowstate.dashboard</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>flowstate</string>
            </array>
        </dict>
    </array>
    <key>NSMicrophoneUsageDescription</key>
    <string>Need microphone for transcription</string>
    <key>SUFeedURL</key>
    <string>https://raw.githubusercontent.com/AbhisarAnand/flow-state/main/appcast.xml</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>
    <key>SUPublicEDKey</key>
    <string>mmDjPeWik2w3GwjpJOtNBd42z8HyO72PqqXVv+MXTCY=</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
EOF
# fi

# Generate AppIcon.icns
if [ -f "Assets/logo.png" ]; then
    echo "🎨 Generating AppIcon.icns..."
    mkdir -p AppIcon.iconset
    sips -z 16 16     -s format png Assets/logo.png --out AppIcon.iconset/icon_16x16.png > /dev/null
    sips -z 32 32     -s format png Assets/logo.png --out AppIcon.iconset/icon_16x16@2x.png > /dev/null
    sips -z 32 32     -s format png Assets/logo.png --out AppIcon.iconset/icon_32x32.png > /dev/null
    sips -z 64 64     -s format png Assets/logo.png --out AppIcon.iconset/icon_32x32@2x.png > /dev/null
    sips -z 128 128   -s format png Assets/logo.png --out AppIcon.iconset/icon_128x128.png > /dev/null
    sips -z 256 256   -s format png Assets/logo.png --out AppIcon.iconset/icon_128x128@2x.png > /dev/null
    sips -z 256 256   -s format png Assets/logo.png --out AppIcon.iconset/icon_256x256.png > /dev/null
    sips -z 512 512   -s format png Assets/logo.png --out AppIcon.iconset/icon_256x256@2x.png > /dev/null
    sips -z 512 512   -s format png Assets/logo.png --out AppIcon.iconset/icon_512x512.png > /dev/null
    sips -z 1024 1024 -s format png Assets/logo.png --out AppIcon.iconset/icon_512x512@2x.png > /dev/null
    
    iconutil -c icns AppIcon.iconset
    cp AppIcon.icns "${APP_BUNDLE}/Contents/Resources/"
    
    # Also copy PNG for UI usage
    cp Assets/logo.png "${APP_BUNDLE}/Contents/Resources/AppIcon-UI.png"
    rm -rf AppIcon.iconset
fi

echo "🔏 Signing app bundle..."
# Sign Frameworks First
if [ -d "${APP_BUNDLE}/Contents/Frameworks/Sparkle.framework/Versions/B" ]; then
    codesign --force --deep --sign "FlowState" "${APP_BUNDLE}/Contents/Frameworks/Sparkle.framework/Versions/B"
fi

codesign --force --sign "FlowState" --entitlements Entitlements.plist "${APP_BUNDLE}"

echo "✅ App Bundle created at ./${APP_BUNDLE}"

echo "💿 Creating Styled DMG..."
./create_dmg.sh
