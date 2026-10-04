# Releases

All application platforms are published by `.github/workflows/release.yml`.
The workflow only runs for a version tag that exactly matches `pubspec.yaml`.

## Versioning

- Stable example: `version: 3.1.0+10` with tag `v3.1.0`.
- Prerelease example: `version: 3.1.0-rc.1+9` with tag `v3.1.0-rc.1`.
- Build numbers must be positive and increase between releases.

Merge the version change and `release-notes/<version>.md` into `master`
before tagging its current commit. The release workflow rejects mismatched tags,
missing notes, and tags outside the current `master` commit.

## Orchestration

The workflow builds these artifacts in parallel:

- signed Android APKs for ARM, ARM64, and x64;
- Linux AppImages for x64 and ARM64;
- an ad-hoc-signed universal macOS app, DMG, Sparkle ZIP, and appcast;
- unsigned Windows Inno Setup installers for x64 and ARM64.

After every build succeeds, the workflow creates a draft GitHub release with
the checked-in notes, an `update-entry.json`, and all platform assets. It then
publishes the release and dispatches `.github/workflows/deploy-pages.yml`.
A prerelease version is published with GitHub's prerelease flag.

The Pages workflow is the only workflow allowed to replace `senpwai.com`. It
combines repository content with the update entries and appcasts stored on
published GitHub Releases, signs the complete metadata, and deploys one atomic
Pages artifact. It never reads the existing live site as an input.

After a release-related Pages deployment succeeds, it dispatches
`.github/workflows/announce-release.yml`. Discord and Reddit are independent
jobs, so GitHub's **Re-run failed jobs** action retries only the failed
destination. The announcement workflow can also be started manually with a
specific published release tag and either all destinations or one selected
destination.

Stable clients only consume stable manifest entries. Prerelease clients consume
both prerelease and stable entries so they automatically graduate to the final
stable release. macOS uses `appcast-prerelease.xml` for the same behavior.

Required GitHub Actions secrets are documented in `docs/signing-keys.md` and
also include the four `SENPWAI_ANDROID_*` Android signing secrets. Announcements
need `DISCORD_BOT_TOKEN`, `REDDIT_CLIENT_ID`, `REDDIT_CLIENT_SECRET`,
`REDDIT_USERNAME`, and `REDDIT_PASSWORD`.

## Publishing a release

1. Bump `pubspec.yaml` to the new version and a higher build number, for example
   `3.0.0-beta.2+2`.
2. Write `release-notes/<version>.md`. Its first-line `# ` heading becomes the
   GitHub release title, and the whole file becomes the release body.
3. Merge both changes into `master`.
4. Tag the current `master` commit `v<version>` and push that tag. The tag
   starts the release workflow; merging into `master` does not publish a
   release.
5. Check all platform jobs, the published release assets, Pages update feeds,
   and Discord and Reddit announcement jobs. A failed announcement can be
   retried separately, but first check whether a post was already created.
