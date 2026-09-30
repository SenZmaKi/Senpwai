#!/bin/sh

set -eu

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 /path/to/Senpwai.app" >&2
  exit 64
fi

app_path="$1"
if [ ! -d "$app_path" ]; then
  echo "Missing app bundle: $app_path" >&2
  exit 1
fi

# This verifies structural signature integrity, including every nested helper.
# An ad-hoc build will still be rejected by Gatekeeper's trust assessment; that
# is separate from the malformed-signature failure this check prevents.
codesign --verify --deep --strict --verbose=4 "$app_path"
