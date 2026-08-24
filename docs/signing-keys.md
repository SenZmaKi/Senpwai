# Signing keys

Senpwai separates remote configuration authority from application release
authority. Never reuse a private key across the trust domains below.

| Trust domain | GitHub Actions secret | Embedded public-key location | Local recovery entry |
| --- | --- | --- | --- |
| Source directory | `SOURCE_DIRECTORY_PRIVATE_KEY` | `sourceDirectoryPublicKeyBase64` in `lib/shared/signed_envelope.dart` | `com.senzmaki.senpwai.signing.source-directory` |
| Android, Windows, and Linux update manifest | `UPDATE_MANIFEST_PRIVATE_KEY` | `updateManifestPublicKeyBase64` in `lib/shared/signed_envelope.dart` | `com.senzmaki.senpwai.signing.update-manifest` |
| macOS Sparkle archives | `SPARKLE_PRIVATE_KEY` | `SUPublicEDKey` in `macos/Runner/Info.plist` | `com.senzmaki.senpwai.signing.sparkle` |

The private values are base64-encoded 32-byte Ed25519 seeds. They are stored as
encrypted GitHub Actions secrets in `SenZmaKi/Senpwai` and as generic-password
entries in the maintainer's macOS login Keychain. Private values must never be
committed, pasted into logs, or included in release artifacts.

The public keys provisioned before the v3.0.0 launch are:

| Trust domain | Public key |
| --- | --- |
| Source directory | `ypBeUW9mAsDQ1buawf/zRT/fUafC6Ea8FB2o3xuM1VY=` |
| Update manifest | `/k0TtLWNnHf6fSg+X3QyZx1IUDcGb4f0ZMmjvHVK0hg=` |
| Sparkle | `uyqccdZCY2282RUX1vyQzbOKsVNsxbM2O0N4vMk0MPg=` |

## Workflow ownership

- `deploy-source-directory.yml` signs `source-directory.json` with the source
  directory key and `update-manifest.json` with the update-manifest key.
- `release.yml` signs the macOS ZIP referenced by `appcast.xml` with the Sparkle
  key.
- GitHub's workflow token publishes Pages and Releases. It is not an artifact
  signing key.
- macOS currently uses ad-hoc bundle signing. The Sparkle key authenticates the
  downloaded update archive; it is not an Apple code-signing identity.

## Recovery

GitHub does not allow an Actions secret to be read back. The Keychain entries
are the recovery copies. A maintainer can confirm that an entry exists without
printing its value:

```sh
security find-generic-password \
  -a Senpwai \
  -s com.senzmaki.senpwai.signing.sparkle
```

Use the corresponding service name from the table for the other keys. Passing
`-w` prints the private value and should only be done when immediately restoring
a missing Actions secret in a private terminal.

## Generate and provision a replacement

Generate each replacement into a protected temporary location:

```sh
cd source-directory/signer
dart run bin/sign.dart \
  --generate-key \
  --private-key-output /secure/path/senpwai-signing.key
chmod 600 /secure/path/senpwai-signing.key
```

The command prints only the public key. Update the appropriate embedded public
key, provision the private value, and then securely remove the temporary file:

```sh
gh secret set SPARKLE_PRIVATE_KEY \
  --repo SenZmaKi/Senpwai \
  < /secure/path/senpwai-signing.key
```

Replace the secret name for the relevant trust domain. Store a new recovery
copy before removing the temporary file.

## Rotation

Before v3.0.0 ships, keys may be replaced directly because there is no installed
v3 trust root to preserve. After launch, do not replace an embedded public key
and immediately start signing with its private half: existing clients would
reject the new signature.

For a post-launch release-key rotation:

1. Create a transition release signed by the old private key.
2. Embed the new public key in that transition release.
3. Sign subsequent releases with the new private key.
4. Retain the retired key offline until the supported upgrade window closes.

For source-directory rotation, first release an app version that trusts the new
key (or temporarily trusts both keys), then change the Pages signing secret.

If any private key may have been exposed, stop the affected publishing workflow,
rotate that trust domain, and treat every artifact signed after the suspected
exposure time as untrusted until reviewed.
