# Releases

All application platforms are published by `.github/workflows/release.yml`.
The workflow only runs for a version tag that exactly matches `pubspec.yaml`.

## Versioning

- Stable example: `version: 3.1.0+10` with tag `v3.1.0`.
- Prerelease example: `version: 3.1.0-rc.1+9` with tag `v3.1.0-rc.1`.
- Build numbers must be positive and increase between releases.

Commit the version change before creating and pushing the corresponding tag.
The release workflow rejects mismatched tags and package versions.

## Orchestration

The workflow builds these artifacts in parallel:

- signed Android APKs for ARM, ARM64, and x64;
- Linux AppImages for x64 and ARM64;
- an ad-hoc-signed universal macOS app, DMG, Sparkle ZIP, and appcast;
- unsigned Windows Inno Setup installers for x64 and ARM64.

After every build succeeds, the workflow creates a draft GitHub release,
uploads all assets, verifies and extends the existing signed update manifest,
deploys the website and update feeds to GitHub Pages, and finally publishes the
release. A prerelease version is published with GitHub's prerelease flag.

Stable clients only consume stable manifest entries. Prerelease clients consume
both prerelease and stable entries so they automatically graduate to the final
stable release. macOS uses `appcast-prerelease.xml` for the same behavior.

Required GitHub Actions secrets are documented in `docs/signing-keys.md` and
also include the four `SENPWAI_ANDROID_*` Android signing secrets.
