#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

INSTALL=false
CONFIG=Config/Prod.xcconfig

for arg in "$@"; do
    case "$arg" in
        --install) INSTALL=true ;;
        --dev) CONFIG=Config/Dev.xcconfig ;;
        *) echo "usage: $0 [--dev] [--install]" >&2; exit 64 ;;
    esac
done

setting() { sed -n "s/^$1 = //p" "$CONFIG"; }
ICON="$(setting ASSETCATALOG_COMPILER_APPICON_NAME)"
NAME="$(setting APP_DISPLAY_NAME)"
BUNDLE_ID="$(setting PRODUCT_BUNDLE_IDENTIFIER)"
CLI_NAME="$(echo "$NAME" | tr '[:upper:]' '[:lower:]')"

APP="$ROOT/build/$NAME.app"
CONTENTS="$APP/Contents"
INSTALLED="/Applications/$NAME.app"

TAG="$(git describe --tags --abbrev=0 --match 'v[0-9]*' 2>/dev/null || echo v0.0.1)"
VERSION="${TAG#v}"
BUILD="$(git rev-list --count HEAD 2>/dev/null || echo 1)"

swift build -c release --product Mork
BIN_DIR="$(swift build -c release --show-bin-path)"

if [ ! -f "Assets/$ICON.icns" ] || [ ! -d "Assets/$ICON.icon" ]; then
    "$ROOT/scripts/generate-icon.sh"
fi

rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BIN_DIR/Mork" "$CONTENTS/MacOS/Mork"

ICON_BUILD="$ROOT/build/icon"
rm -rf "$ICON_BUILD"
mkdir -p "$ICON_BUILD/source"
cp -R "Assets/$ICON.icon" "$ICON_BUILD/source/AppIcon.icon"
cp -R "Assets/Accent.xcassets" "$ICON_BUILD/source/Accent.xcassets"
xcrun actool "$ICON_BUILD/source/AppIcon.icon" "$ICON_BUILD/source/Accent.xcassets" \
    --compile "$ICON_BUILD" \
    --app-icon AppIcon \
    --accent-color AccentColor \
    --platform macosx \
    --minimum-deployment-target 14.0 \
    --output-partial-info-plist "$ICON_BUILD/partial.plist" >/dev/null
cp "$ICON_BUILD/Assets.car" "$CONTENTS/Resources/Assets.car"
cp "Assets/$ICON.icns" "$CONTENTS/Resources/AppIcon.icns"
sed "s/MORK_BUNDLE_ID:-dev.mantrandev.mork}/MORK_BUNDLE_ID:-$BUNDLE_ID}/" scripts/mork > "$CONTENTS/Resources/mork"
chmod 755 "$CONTENTS/Resources/mork"
cp LICENSE "$CONTENTS/Resources/LICENSE"
cp THIRD_PARTY_NOTICES "$CONTENTS/Resources/THIRD_PARTY_NOTICES"

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Mork</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>NSAccentColorName</key>
    <string>AccentColor</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$NAME</string>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Folder</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.folder</string>
            </array>
        </dict>
    </array>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.developer-tools</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

plutil -lint "$CONTENTS/Info.plist" >/dev/null
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --strict "$APP"

if [ "$INSTALL" = true ]; then
    pkill -f "$INSTALLED/Contents/MacOS/Mork" 2>/dev/null || true
    for _ in $(seq 1 50); do
        pgrep -f "$INSTALLED/Contents/MacOS/Mork" >/dev/null || break
        sleep 0.1
    done
    sleep 0.5
    rm -rf "$INSTALLED"
    ditto "$APP" "$INSTALLED"
    rm -rf "$APP"
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$INSTALLED"
    echo "$INSTALLED ($VERSION build $BUILD)"
    "$ROOT/scripts/install-cli.sh" "$INSTALLED/Contents/Resources/mork" "$CLI_NAME"
else
    echo "$APP ($VERSION build $BUILD)"
fi
