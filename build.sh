#!/bin/bash

# wireguard-dpi-macos Build Script
# This script builds the macOS application

set -e

echo "Building wireguard-dpi-macos for macOS..."

# Clean previous builds
echo "Cleaning previous builds..."
rm -rf .build
rm -rf wireguard-dpi-macos.app

# Build the application
echo "Building Swift package..."
swift build -c release

# Create app bundle structure
echo "Creating application bundle..."
APP_NAME="wireguard-dpi-macos"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"
RESOURCE_BUNDLE_NAME="wireguard-dpi-macos_WireGuardDPIMacOS.bundle"
RESOURCE_BUNDLE=".build/release/${RESOURCE_BUNDLE_NAME}"

mkdir -p "${MACOS}"
mkdir -p "${RESOURCES}"

# Copy executable
echo "Copying executable..."
cp ".build/release/${APP_NAME}" "${MACOS}/"

# Copy ByeDPI binary
echo "Copying ByeDPI binary..."
mkdir -p "${RESOURCES}/bin"
CIADPI_SOURCE=""
if [ -f "Sources/WireGuardDPIMacOS/Resources/bin/ciadpi" ]; then
    CIADPI_SOURCE="Sources/WireGuardDPIMacOS/Resources/bin/ciadpi"
elif [ -f "${RESOURCE_BUNDLE}/ciadpi" ]; then
    CIADPI_SOURCE="${RESOURCE_BUNDLE}/ciadpi"
elif [ -f "byedpi/ciadpi" ]; then
    CIADPI_SOURCE="byedpi/ciadpi"
fi

if [ -n "${CIADPI_SOURCE}" ]; then
    cp "${CIADPI_SOURCE}" "${RESOURCES}/bin/ciadpi"
    chmod +x "${RESOURCES}/bin/ciadpi"
    echo "  ByeDPI (ciadpi) copied from ${CIADPI_SOURCE}"
else
    echo "  Warning: ciadpi not found, ByeDPI will not run"
fi

# Copy SwiftPM resource bundle if it exists. This keeps SwiftPM resources
# available when the executable is packaged manually as a .app bundle.
if [ -d "${RESOURCE_BUNDLE}" ]; then
    echo "Copying SwiftPM resource bundle..."
    cp -R "${RESOURCE_BUNDLE}" "${RESOURCES}/"
    echo "  Resource bundle copied"
fi

# Copy App Icon
echo "Copying application icon..."
if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "${RESOURCES}/"
    echo "  App icon copied"
else
    echo "  Warning: AppIcon.icns not found, skipping..."
fi

# Create Info.plist
echo "Creating Info.plist..."
cat > "${CONTENTS}/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.aliozkanozdurmus.wireguard-dpi-macos</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleDisplayName</key>
    <string>wireguard-dpi-macos</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 wireguard-dpi-macos contributors.</string>
</dict>
</plist>
EOF

# Create PkgInfo
echo "APPL????" > "${CONTENTS}/PkgInfo"

# Ad-hoc sign for local development so macOS treats the bundle consistently.
if command -v codesign >/dev/null 2>&1; then
    echo "Ad-hoc signing app bundle..."
    codesign --force --deep --sign - "${APP_BUNDLE}" >/dev/null 2>&1 || echo "  Warning: codesign failed, continuing..."
fi

echo "Build complete!"
echo "Application bundle created: ${APP_BUNDLE}"
echo ""
echo "To run the application:"
echo "  open ${APP_BUNDLE}"
echo ""
echo "To install to Applications folder:"
echo "  ditto ${APP_BUNDLE} /Applications/${APP_BUNDLE}"
