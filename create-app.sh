#!/bin/bash
# Create a proper macOS app bundle from the Swift executable

cd "$(dirname "$0")"

APP_NAME="Protokoll"
BUNDLE_ID="com.redaksjon.protokoll"
VERSION="1.0.0"

echo "🔨 Building ${APP_NAME}..."
swift build -c release

if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi

echo "📦 Creating app bundle..."

# Create app bundle structure
APP_DIR="${APP_NAME}.app"
rm -rf "$APP_DIR"

mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy executable
cp .build/release/Protokoll "$APP_DIR/Contents/MacOS/${APP_NAME}"

# Create Info.plist
cat > "$APP_DIR/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
</dict>
</plist>
EOF

# Make executable
chmod +x "$APP_DIR/Contents/MacOS/${APP_NAME}"

echo "✅ App bundle created: ${APP_DIR}"
echo ""
echo "🚀 To launch, run:"
echo "   open ${APP_DIR}"
echo ""
echo "Or double-click ${APP_DIR} in Finder"
