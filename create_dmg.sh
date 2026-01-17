#!/bin/bash
set -e

APP_NAME="FlowState"
DMG_NAME="${APP_NAME}_Installer"
VOL_NAME="${APP_NAME}"
SRC_APP="./${APP_NAME}.app"
BG_IMG_PATH="./Assets/installer_background.png"

# Verify .app exists
if [ ! -d "$SRC_APP" ]; then
    echo "❌ Error: $SRC_APP not found. Please build the app first."
    exit 1
fi

# Cleanup old DMG
rm -f "${DMG_NAME}.dmg"
rm -f "pack.temp.dmg"

# Ensure no previous volume is mounted
if [ -d "/Volumes/${VOL_NAME}" ]; then
    hdiutil detach "/Volumes/${VOL_NAME}" -force || true
fi

echo "📦 Creating temporary DMG..."
hdiutil create -srcfolder "$SRC_APP" -volname "${VOL_NAME}" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW "pack.temp.dmg"

echo "💾 Mounting temporary DMG..."
device=$(hdiutil attach -readwrite -noverify "pack.temp.dmg" | egrep '^/dev/' | sed 1q | awk '{print $1}')
sleep 2

# Path where DMG is mounted
MOUNT_DIR="/Volumes/${VOL_NAME}"

echo "📂 Setting up DMG structure..."
# Link to Applications
ln -s /Applications "${MOUNT_DIR}/Applications"

# Background Image Logic
HAS_BG=false
mkdir -p "${MOUNT_DIR}/.background"
if [ -f "$BG_IMG_PATH" ]; then
    cp "$BG_IMG_PATH" "${MOUNT_DIR}/.background/background.png"
    HAS_BG=true
else
    echo "⚠️ Warning: Background image not found at $BG_IMG_PATH"
fi

# ---------------------------------------------------------
# 🎨 SET VOLUME ICON (The "Logo" request)
# ---------------------------------------------------------
if [ -f "${SRC_APP}/Contents/Resources/AppIcon.icns" ]; then
    echo "✨ Setting Custom Volume Icon..."
    cp "${SRC_APP}/Contents/Resources/AppIcon.icns" "${MOUNT_DIR}/.VolumeIcon.icns"
    # Set the 'Has Custom Icon' bit on the volume root
    SetFile -a C "${MOUNT_DIR}"
fi
# ---------------------------------------------------------

echo "🎨 Applying layout via AppleScript..."
APP_SCRIPT="
tell application \"Finder\"
    tell disk \"${VOL_NAME}\"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 100, 900, 416} -- Width: 500, Height: 316 (288 + 28px Title Bar)
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 100
        
        if ${HAS_BG} then
            set background picture of theViewOptions to file \".background:background.png\"
        end if
        
        -- Position Icons (Centered Vertically at 144)
        -- Width is 500. Middle is 250.
        -- App (Left): 110
        -- Folder (Right): 390
        set position of item \"${APP_NAME}.app\" of container window to {110, 144}
        set position of item \"Applications\" of container window to {390, 144}
        
        update without registering applications
        delay 2
        close
    end tell
end tell
"

echo "$APP_SCRIPT" | osascript

echo "🔒 Syncing changes..."
sync

echo "⏏️  Unmounting..."
hdiutil detach "${device}"

echo "compressing DMG..."
hdiutil convert "pack.temp.dmg" -format UDZO -imagekey zlib-level=9 -o "${DMG_NAME}.dmg"

rm -f "pack.temp.dmg"

echo "✅ DMG Created: ${DMG_NAME}.dmg"
open .
