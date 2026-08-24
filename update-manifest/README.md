# Senpwai update feeds

`update_manifest.payload.json` is the source of truth for Android, Windows, and
Linux updates. GitHub Pages signs and publishes it as `update-manifest.json`.
The workflow uses the `UPDATE_MANIFEST_PRIVATE_KEY` Actions secret, and the app
verifies the envelope with `updateManifestPublicKeyBase64`.

macOS uses Sparkle's `appcast.xml` from the latest stable GitHub release.
Release enclosures must point to the packaged macOS archive and include its byte
length and `sparkle:edSignature`.
Sparkle signatures use the independent `SPARKLE_PRIVATE_KEY` Actions secret;
its public half is stored in the macOS `SUPublicEDKey` setting.

The source directory, cross-platform manifest, and Sparkle archive deliberately
use separate keys. See [`docs/signing-keys.md`](../docs/signing-keys.md).

Artifact requirements:

- Android: release-signed universal APK (`platform: android`, `architecture: any`).
- Windows: trusted-certificate-signed MSIX (`windows`, currently `x64`).
- Linux: AppImage (`linux`, architecture matching the runner).
- macOS: universal arm64/x86_64 ad-hoc-signed ZIP referenced by the appcast and
  signed with Sparkle's Ed25519 key. Developer ID/notarization remain optional
  if that policy changes.

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

## Production releases

The tag-driven `Release` workflow is the production source of truth. To release:

1. Set `version:` in `pubspec.yaml` to `<version>+<monotonic build number>`.
2. Commit the complete release state.
3. Create and push the matching `v<version>` tag.

The workflow rejects a tag that does not match `pubspec.yaml`. Its macOS job
analyzes and builds the universal arm64/x86_64 app, verifies both architectures
and the complete nested signature structure, packages a human-facing DMG and
Sparkle ZIP, generates the signed appcast and checksums, and uploads the assets
to a draft GitHub release.
Only after every asset exists does the publish job make the release public and
move GitHub's `latest` release pointer, which atomically exposes the new appcast
to installed copies of Senpwai.

The workflow is split into version preparation, platform build, and final
publication jobs. Add Android, Windows, and Linux build jobs alongside
`build-macos`, upload their `release-*` artifacts, and make `publish` depend on
them after each platform's updater has been validated.

The DMG is the human-facing macOS installer. The ZIP is Sparkle's update
payload. Both contain the same ad-hoc-signed app, so Gatekeeper approval remains
required only for the first installation.
