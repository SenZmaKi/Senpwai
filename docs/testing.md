# Testing

Run the deterministic test suite with:

```shell
flutter analyze
flutter test
```

AnimePahe and TokyoInsider live-source tests use the embedded browser transport.
They carry the `browser` tag and are skipped during normal test runs so a
missing WebView session or a remote-site change does not break the local suite.

Run only those browser-dependent tests explicitly with:

```shell
flutter test --tags browser --run-skipped
```

These remain live integration checks: they require network access and a working
WebView/browser transport environment.

AniList, Nyaa, and other direct HTTP checks carry the `network` tag and are also
skipped by default because remote availability and rate limits are outside the
app's control. Run them explicitly with:

```shell
flutter test --tags network --run-skipped
```

Loopback HTTP integration tests carry the `local-http` tag. They run normally
in Linux CI but are skipped on Windows hosts where localhost traffic is
intercepted before Dart's test server receives it.
