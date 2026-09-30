#!/bin/sh

set -eu

app_path="${TARGET_BUILD_DIR:?}/${WRAPPER_NAME:?}"
login_helper="$app_path/Contents/Library/LoginItems/LaunchAtLoginHelper.app"
launch_resources="${BUILT_PRODUCTS_DIR:?}/LaunchAtLogin_LaunchAtLogin.bundle/Contents/Resources"
launch_entitlements="$launch_resources/LaunchAtLogin.entitlements"
sparkle_framework="$app_path/Contents/Frameworks/Sparkle.framework"

if [ ! -d "$login_helper" ]; then
  echo "error: Missing LaunchAtLoginHelper.app at $login_helper" >&2
  exit 1
fi
if [ ! -f "$launch_entitlements" ]; then
  echo "error: Missing LaunchAtLogin helper entitlements at $launch_entitlements" >&2
  exit 1
fi

identity="${EXPANDED_CODE_SIGN_IDENTITY:-}"
if [ -z "$identity" ]; then
  identity="${EXPANDED_CODE_SIGN_IDENTITY_NAME:-}"
fi
if [ -z "$identity" ]; then
  identity="-"
fi

# LaunchAtLogin rewrites the helper bundle identifier after extracting its
# pre-signed helper. Re-sign the resulting bundle so its Info.plist and sandbox
# entitlement are sealed before Xcode signs the containing Senpwai.app.
if [ "$identity" = "-" ]; then
  codesign \
    --force \
    --deep \
    --options runtime \
    --timestamp=none \
    --entitlements "$launch_entitlements" \
    --sign - \
    "$login_helper"
else
  codesign \
    --force \
    --deep \
    --options runtime \
    --entitlements "$launch_entitlements" \
    --sign "$identity" \
    "$login_helper"
fi

codesign --verify --deep --strict "$login_helper"

# CocoaPods embeds Sparkle after the login helper is copied. Its nested XPC
# services must remain internally valid; fail the build instead of publishing a
# bundle that Gatekeeper can describe as damaged.
if [ -d "$sparkle_framework" ]; then
  codesign --verify --deep --strict "$sparkle_framework"
fi
