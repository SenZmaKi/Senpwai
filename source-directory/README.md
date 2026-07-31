# Senpwai source directory

The Flutter app fetches the signed directory from:

`https://senzmaki.github.io/Senpwai/source-directory.json`

Update `source_directory.payload.json` when a source host moves. Keep values
declarative: HTTPS endpoints, source-owned allowed hosts, and Nyaa's request
cap only. Parser changes still require an app release.

The initial signing key has been provisioned in the repository Actions secret
`SOURCE_DIRECTORY_PRIVATE_KEY`; its public half is embedded in the app. To
rotate that key, generate a replacement locally:

```sh
cd source-directory/signer
dart pub get
dart run bin/sign.dart --generate-key --private-key-output /secure/path/senpwai-source-directory.key
```

Put the printed public key in `SourceDirectory._publicKeyBase64`, then replace
the repository Actions secret `SOURCE_DIRECTORY_PRIVATE_KEY` with the contents
of the private-key file. Do not commit or share that file. The Pages workflow
signs and publishes this payload whenever it changes on `master`.

To test a signed directory locally, set the same environment variable and run:

```sh
cd source-directory/signer
dart run bin/sign.dart --input ../source_directory.payload.json --output /tmp/source-directory.json
```
