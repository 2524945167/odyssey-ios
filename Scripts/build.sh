#!/usr/bin/env bash
set -euo pipefail

echo "=================================================="
echo "==> Starting Odyssey Build & Test Process"
echo "=================================================="

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$WORKSPACE_ROOT"

BUILD_DIR="$WORKSPACE_ROOT/build"
PAYLOAD_DIR="$BUILD_DIR/Payload"
IPA_PATH="$BUILD_DIR/Odyssey-unsigned.ipa"
APP_DIR="$BUILD_DIR/Release-iphoneos/Odyssey.app"

# 1. Clean previous build artifacts
echo "==> Cleaning previous build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# 2. Generate Xcode project
echo "==> Generating Xcode project with XcodeGen..."
xcodegen generate

# 3. Run Unit Tests on iOS Simulator
echo "==> Running Unit Tests on iPhone 17 (OS 27.0)..."
xcodebuild test \
    -project Odyssey.xcodeproj \
    -scheme Odyssey \
    -destination "platform=iOS Simulator,name=iPhone 17,OS=27.0" \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    -resultBundlePath "$BUILD_DIR/TestResults.xcresult" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY=""

# 4. Build Release for Generic iOS Device
echo "==> Building Release for generic/platform=iOS..."
xcodebuild build \
    -project Odyssey.xcodeproj \
    -scheme Odyssey \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    CONFIGURATION_BUILD_DIR="$BUILD_DIR/Release-iphoneos" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY=""

# Verify build output
if [[ ! -d "$APP_DIR" ]]; then
    echo "ERROR: Built Odyssey.app not found at $APP_DIR" >&2
    exit 1
fi

# 5. Package unsigned IPA
echo "==> Packaging unsigned IPA..."
mkdir -p "$PAYLOAD_DIR"
cp -R "$APP_DIR" "$PAYLOAD_DIR/"

cd "$BUILD_DIR"
zip -r -y "Odyssey-unsigned.ipa" Payload
cd "$WORKSPACE_ROOT"

# 6. Automatic IPA Verification
echo "==> Automatically verifying generated IPA..."

# 6.1 Check IPA file exists and is non-empty
if [[ ! -s "$IPA_PATH" ]]; then
    echo "ERROR: IPA file does not exist or is empty: $IPA_PATH" >&2
    exit 1
fi
echo "✓ IPA file exists and is non-empty ($(ls -lh "$IPA_PATH" | awk '{print $5}'))"

# 6.2 Check Payload/Odyssey.app/Info.plist exists inside IPA
if ! unzip -l "$IPA_PATH" | grep -q "Payload/Odyssey.app/Info.plist"; then
    echo "ERROR: Payload/Odyssey.app/Info.plist not found inside IPA." >&2
    exit 1
fi
echo "✓ Payload/Odyssey.app/Info.plist confirmed inside IPA"

# 6.3 Verify Bundle ID is com.kupetis.odyssey
VERIFY_DIR=$(mktemp -d)
unzip -q -j "$IPA_PATH" "Payload/Odyssey.app/Info.plist" -d "$VERIFY_DIR"

BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$VERIFY_DIR/Info.plist" 2>/dev/null || plutil -extract CFBundleIdentifier raw "$VERIFY_DIR/Info.plist" 2>/dev/null || grep -A1 "CFBundleIdentifier" "$VERIFY_DIR/Info.plist" | tail -n1 | sed -e 's/<[^>]*>//g' | tr -d ' \t\r\n')
rm -rf "$VERIFY_DIR"

echo "--> Extracted Bundle ID: '$BUNDLE_ID'"
if [[ "$BUNDLE_ID" != "com.kupetis.odyssey" ]]; then
    echo "ERROR: Bundle ID mismatch! Expected 'com.kupetis.odyssey', got '$BUNDLE_ID'" >&2
    exit 1
fi
echo "✓ Bundle ID successfully verified as com.kupetis.odyssey"

# 6.4 Calculate and print SHA-256 of internal IPA
echo "==> Computing SHA-256 for internal unsigned IPA..."
if command -v shasum >/dev/null 2>&1; then
    IPA_SHA256=$(shasum -a 256 "$IPA_PATH" | awk '{print $1}')
elif command -v sha256sum >/dev/null 2>&1; then
    IPA_SHA256=$(sha256sum "$IPA_PATH" | awk '{print $1}')
else
    IPA_SHA256=$(openssl dgst -sha256 "$IPA_PATH" | awk '{print $NF}')
fi
echo "✓ Internal IPA SHA-256: $IPA_SHA256"

echo "=================================================="
echo "==> Odyssey Build, Test, and Packaging Completed Successfully!"
echo "==> Output: $IPA_PATH"
echo "==> Internal IPA SHA-256: $IPA_SHA256"
echo "=================================================="
exit 0
