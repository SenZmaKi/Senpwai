# Senpwai update feeds

`update_manifest.payload.json` is the source of truth for Android, Windows, and
Linux updates. GitHub Pages signs and publishes it as `update-manifest.json`.
The app verifies that envelope with the public Ed25519 key embedded in Senpwai.

macOS uses Sparkle's `appcast.xml`. Release enclosures must point to the packaged
macOS archive and include its byte length and `sparkle:edSignature`.
The Sparkle signature uses the same Ed25519 seed stored in the
`SOURCE_DIRECTORY_PRIVATE_KEY` Actions secret.

Artifact requirements:

- Android: release-signed universal APK (`platform: android`, `architecture: any`).
- Windows: trusted-certificate-signed MSIX (`windows`, currently `x64`).
- Linux: AppImage (`linux`, architecture matching the runner).
- macOS: ad-hoc-signed ZIP referenced by the appcast and signed with Sparkle's
  Ed25519 key. Developer ID/notarization remain optional if that policy changes.

Never publish an artifact before its hash, size, version, and build have been
written to the appropriate feed. The update manifest accepts only HTTPS GitHub
release URLs.

The checked-in MSIX publisher (`CN=Senpwai`) is a development identity. Before
the first public Windows release, replace it with the exact subject from the
production signing certificate and keep that package identity stable for every
later update.

For the current unpaid macOS distribution path, Xcode ad-hoc signs the app and
the `Seal Nested Helpers` phase repairs LaunchAtLogin's post-signature bundle-ID
rewrite. Every release build must pass the structural signature check before it
is archived:

```sh
sh macos/scripts/verify_app_signature.sh \
  build/macos/Build/Products/Release/senpwai.app
```

This prevents Gatekeeper's genuinely malformed-signature failure. It does not
make an ad-hoc signature trusted or notarized; first-time users still need to
approve Senpwai through macOS Privacy & Security.

## Rolling macOS test prerelease

Run the `macOS test prerelease` workflow manually to build the Apple Silicon
Release app, verify its nested signatures, and publish a DMG, Sparkle ZIP, and
signed test appcast to the reusable `macos-update-test` GitHub prerelease. The
workflow replaces the same three assets on every run, so test builds do not
create a trail of disposable releases.

The workflow stamps only its CI build with the prerelease appcast URL. Local and
production builds continue to use the stable Pages appcast. Install one workflow
build, then dispatch the workflow again with a higher build number to exercise
Sparkle's complete download, verification, replacement, and relaunch path.

GitHub enables manual workflow dispatch only after the workflow file exists on
the default branch. Until v3 reaches that branch, bumping `version:` in
`pubspec.yaml` on `v3.0.0` triggers the same rolling prerelease using that
version and build number.

The DMG is the human-facing installer. The ZIP is Sparkle's update payload. Both
contain the same ad-hoc-signed app, so Gatekeeper approval is still required on
the first installation.

After building, verifying, and uploading the artifacts, copy
`release.example.json`, update its values, then generate both feeds:

```sh
cd source-directory/signer
dart run bin/build_update_feeds.dart \
  --release ../../update-manifest/release.json \
  --manifest ../../update-manifest/update_manifest.payload.json \
  --appcast ../../update-manifest/appcast.xml
```

Commit the generated feeds. The Pages workflow signs the shared manifest; the
generator has already added Sparkle's artifact signature to the appcast.
