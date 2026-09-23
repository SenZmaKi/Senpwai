import 'package:flutter_test/flutter_test.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:senpwai/updates/models.dart';

void main() {
  group('UpdateArtifact', () {
    test('round trips a valid GitHub release artifact', () {
      final artifact = UpdateArtifact.fromJson(_artifactJson());

      expect(artifact.url.host, 'github.com');
      expect(artifact.sha256, 'a' * 64);
      expect(UpdateArtifact.fromJson(artifact.toJson()).fileName, 'update.zip');
    });

    for (final invalid in <String, Map<String, dynamic>>{
      'HTTP URL': _artifactJson(url: 'http://github.com/acme/update.zip'),
      'untrusted host': _artifactJson(url: 'https://evil.example/update.zip'),
      'URL credentials': _artifactJson(
        url: 'https://user:secret@github.com/acme/update.zip',
      ),
      'empty filename': _artifactJson(fileName: ''),
      'path traversal filename': _artifactJson(fileName: '../update.zip'),
      'Windows path filename': _artifactJson(fileName: r'folder\update.zip'),
      'zero size': _artifactJson(sizeBytes: 0),
      'invalid digest': _artifactJson(sha256: 'ABC123'),
    }.entries) {
      test('rejects ${invalid.key}', () {
        expect(
          () => UpdateArtifact.fromJson(invalid.value),
          throwsFormatException,
        );
      });
    }
  });

  group('AppRelease', () {
    test('applies optional-field defaults', () {
      final release = AppRelease.fromJson({
        'version': '3.1.0',
        'build': 5,
        'artifacts': [_artifactJson()],
      });

      expect(release.channel, 'stable');
      expect(release.mandatory, isFalse);
      expect(release.notes, isEmpty);
      expect(release.displayVersion, 'v3.1.0');
    });

    test('rejects negative builds and malformed artifact collections', () {
      expect(
        () => AppRelease.fromJson({
          'version': '3.1.0',
          'build': -1,
          'artifacts': [],
        }),
        throwsFormatException,
      );
      expect(
        () => AppRelease.fromJson({
          'version': '3.1.0',
          'build': 1,
          'artifacts': 'not-a-list',
        }),
        throwsFormatException,
      );
    });

    test('selects exact architecture before a later any artifact', () {
      final target = UpdateTarget.current;
      final exact = _artifact(
        target.platform,
        target.architecture,
        'exact.zip',
      );
      final any = _artifact(target.platform, 'any', 'any.zip');
      final release = AppRelease(
        version: Version(3, 1, 0),
        build: 1,
        channel: 'stable',
        mandatory: false,
        notes: '',
        artifacts: [exact, any],
      );

      expect(release.artifactForCurrentPlatform()?.fileName, 'exact.zip');
    });
  });

  group('UpdateManifest', () {
    test('selects the newest compatible version and build', () {
      final target = UpdateTarget.current;
      final manifest = UpdateManifest(
        schemaVersion: 1,
        generatedAt: DateTime.utc(2026),
        expiresAt: DateTime.utc(2100),
        releases: [
          _release('3.0.4', 5, target: target),
          _release('3.1.0', 1, target: target),
          _release('3.1.0', 3, target: target),
          _release('4.0.0', 1, target: target, channel: 'beta'),
        ],
      );

      final latest = manifest.latestCompatible(
        currentVersion: '3.0.4',
        currentBuild: 4,
      );

      expect(latest?.release.version, Version(3, 1, 0));
      expect(latest?.release.build, 3);
    });

    test('honors requested channels', () {
      final target = UpdateTarget.current;
      final manifest = UpdateManifest(
        schemaVersion: 1,
        generatedAt: DateTime.utc(2026),
        expiresAt: DateTime.utc(2100),
        releases: [_release('4.0.0', 1, target: target, channel: 'beta')],
      );

      expect(
        manifest.latestCompatible(currentVersion: '3.0.0', currentBuild: 1),
        isNull,
      );
      expect(
        manifest.latestCompatible(
          currentVersion: '3.0.0',
          currentBuild: 1,
          channels: const {'beta'},
        ),
        isNotNull,
      );
    });

    test('does not offer the installed or an older release', () {
      final target = UpdateTarget.current;
      final manifest = UpdateManifest(
        schemaVersion: 1,
        generatedAt: DateTime.utc(2026),
        expiresAt: DateTime.utc(2100),
        releases: [
          _release('3.0.4', 4, target: target),
          _release('3.0.3', 99, target: target),
        ],
      );

      expect(
        manifest.latestCompatible(currentVersion: '3.0.4', currentBuild: 4),
        isNull,
      );
    });

    test('rejects unsupported schemas, bad dates, and expired payloads', () {
      for (final json in [
        _manifestJson()..['schemaVersion'] = 2,
        _manifestJson()..['generatedAt'] = 'not-a-date',
        _manifestJson()..['expiresAt'] = '2000-01-01T00:00:00Z',
        _manifestJson()..['releases'] = 'not-a-list',
      ]) {
        expect(() => UpdateManifest.fromJson(json), throwsFormatException);
      }
    });
  });

  group('UpdateState', () {
    test('clamps progress and hides non-actionable phases', () {
      expect(const UpdateState(totalBytes: 0).progress, isNull);
      expect(
        const UpdateState(bytesReceived: 150, totalBytes: 100).progress,
        1,
      );
      expect(const UpdateState(phase: UpdatePhase.idle).isVisible, isFalse);
      expect(
        const UpdateState(phase: UpdatePhase.unsupported).isVisible,
        isFalse,
      );
      expect(
        const UpdateState(phase: UpdatePhase.downloading).isVisible,
        isTrue,
      );
    });

    test('copyWith preserves or explicitly clears errors', () {
      const failed = UpdateState(phase: UpdatePhase.failed, error: 'boom');

      expect(failed.copyWith(phase: UpdatePhase.checking).error, 'boom');
      expect(failed.copyWith(clearError: true).error, isNull);
    });
  });
}

Map<String, dynamic> _artifactJson({
  String url = 'https://github.com/acme/releases/download/v1/update.zip',
  String fileName = 'update.zip',
  int sizeBytes = 100,
  String? sha256,
}) => {
  'platform': UpdateTarget.current.platform,
  'architecture': UpdateTarget.current.architecture,
  'url': url,
  'fileName': fileName,
  'sizeBytes': sizeBytes,
  'sha256': sha256 ?? 'a' * 64,
};

Map<String, dynamic> _manifestJson() => {
  'schemaVersion': 1,
  'generatedAt': '2026-01-01T00:00:00Z',
  'expiresAt': '2100-01-01T00:00:00Z',
  'releases': [],
};

UpdateArtifact _artifact(String platform, String architecture, String name) =>
    UpdateArtifact(
      platform: platform,
      architecture: architecture,
      url: Uri.parse('https://github.com/acme/releases/$name'),
      fileName: name,
      sizeBytes: 100,
      sha256: 'a' * 64,
    );

AppRelease _release(
  String version,
  int build, {
  required UpdateTarget target,
  String channel = 'stable',
}) => AppRelease(
  version: Version.parse(version),
  build: build,
  channel: channel,
  mandatory: false,
  notes: '',
  artifacts: [
    _artifact(target.platform, target.architecture, 'update-$build.zip'),
  ],
);
