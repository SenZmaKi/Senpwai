# Nightly releases

The release workflow checks daily at 02:57 UTC (05:57 Africa/Nairobi), matching
Sentorr, and can be dispatched manually from `master`. Scheduled and manual
nightly runs compare HEAD with the commit of the latest published nightly. If
they match, the workflow skips quality checks, builds, publishing, and Pages
deployment. A first nightly or a different commit proceeds normally. Drafts and
failed releases do not suppress retries. Tag pushes bypass this comparison and
retain the existing stable/prerelease version and release-notes checks.

Nightlies use `<base>-nightly.<run number>.<run attempt>` with a Unix timestamp
build number. The same platform builds and signing secrets produce a GitHub
prerelease. Nightlies do not trigger Discord/Reddit announcements or replace the
stable GitHub latest release.

`nightly_branding.py` runs in each disposable CI checkout before building. It
badges launcher/tray icons, changes displayed names and native application IDs,
and gives the Windows installer a separate ID and installation directory.
After badging the source icon, it runs `tool/generate_splash_icons.py` to generate
matching light/dark Android splash icons at every density, including Android 12's
masked splash. To regenerate stable splash artwork, run
`python tool/generate_splash_icons.py` with Pillow installed. As with Sentorr,
Nightly assets are generated in the disposable build checkout.
`ApplicationIdentity` selects isolated data, credentials and startup entries via
`--dart-define UPDATE_CHANNEL=nightly`. Executable names and asset naming remain
compatible with the existing packaging and updater infrastructure.

The signed update manifest includes the `nightly` channel. Nightly installations
select only that channel; macOS uses `https://senpwai.com/appcast-nightly.xml`.
Pages rebuilds all three feeds from published release assets. The download page
provides keyboard-accessible Stable/Nightly tabs and resolves actual assets.

AniList uses separate OAuth clients and callbacks: stable client `36391` uses
`senpwai://auth/callback`, and nightly client `53445` must be registered with
`senpwai-nightly://auth/callback`. Android, macOS, Linux and Windows register the
matching scheme; Windows forwards links to the matching channel's window title.
The callback listener matches the scheme, host and path. Only public client IDs
are embedded; the implicit grant does not require client secrets.
