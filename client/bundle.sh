#!/bin/bash
set -euo pipefail

APP_NAME="SpeechToText"
BUNDLE_DIR=".build/${APP_NAME}.app"

swift build -c release

rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS"
mkdir -p "$BUNDLE_DIR/Contents/Resources"

cp ".build/release/${APP_NAME}" "$BUNDLE_DIR/Contents/MacOS/${APP_NAME}"
cp Info.plist "$BUNDLE_DIR/Contents/Info.plist"

codesign --force --deep --sign - "$BUNDLE_DIR"

echo "Built $BUNDLE_DIR"
echo "Run with: open $BUNDLE_DIR"
