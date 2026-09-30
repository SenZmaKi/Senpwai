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

- Android: release-signed ABI-specific APK (`android`, with `arm64`, `arm`, or
  `x64` architecture).
- Windows: unsigned Inno Setup installers (`windows`, `x64` and `arm64`).
- Linux: AppImage (`linux`, architecture matching the runner).
- macOS: universal arm64/x86_64 ad-hoc-signed ZIP referenced by the appcast and
  signed with Sparkle's Ed25519 key. Developer ID/notarization remain optional
  if that policy changes.

Release assets are staged in a draft and checksummed before publication. The
signed update feed is deployed after publication so its URLs resolve for users.
The update manifest accepts only HTTPS GitHub release URLs.

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
move GitHub's `latest` release pointer. Pages then deploys the signed update
feed and prerelease appcast. The announcement job runs after Pages succeeds.

## Prereleases

Use a prerelease version and matching tag, for example `3.1.0-beta.1+3` and
`v3.1.0-beta.1`. The same workflow builds every platform, marks the GitHub
release as a prerelease, and publishes prerelease update entries.

Before the first run, configure these repository Actions secrets:

- `SENPWAI_ANDROID_KEYSTORE_BASE64`: base64-encoded permanent Android release
  keystore.
- `SENPWAI_ANDROID_KEYSTORE_PASSWORD`
- `SENPWAI_ANDROID_KEY_ALIAS`
- `SENPWAI_ANDROID_KEY_PASSWORD`

Use the same keystore for every Android prerelease and the later public Android
release. Android rejects updates signed by a different key, and every new APK
must have a higher build number (`versionCode`) than the installed APK.

The DMG is the human-facing macOS installer. The ZIP is Sparkle's update
payload. Both contain the same ad-hoc-signed app, so Gatekeeper approval remains
required only for the first installation.
