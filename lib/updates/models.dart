import 'dart:ffi';
import 'dart:io';

import 'package:pub_semver/pub_semver.dart';

enum UpdatePhase {
  idle,
  checking,
  available,
  downloading,
  verifying,
  preparing,
  ready,
  installing,
  failed,
  unsupported,
}

class UpdateState {
  final UpdatePhase phase;
  final AppRelease? release;
  final UpdateArtifact? artifact;
  final String currentVersion;
  final int currentBuild;
  final int bytesReceived;
  final int totalBytes;
  final String? error;

  const UpdateState({
    this.phase = UpdatePhase.idle,
    this.release,
    this.artifact,
    this.currentVersion = '',
    this.currentBuild = 0,
    this.bytesReceived = 0,
    this.totalBytes = 0,
    this.error,
  });

  double? get progress =>
      totalBytes <= 0 ? null : (bytesReceived / totalBytes).clamp(0.0, 1.0);

  bool get isVisible => switch (phase) {
    UpdatePhase.available ||
    UpdatePhase.downloading ||
    UpdatePhase.verifying ||
    UpdatePhase.preparing ||
    UpdatePhase.ready ||
    UpdatePhase.installing ||
    UpdatePhase.failed => true,
    _ => false,
  };

  UpdateState copyWith({
    UpdatePhase? phase,
    AppRelease? release,
    UpdateArtifact? artifact,
    String? currentVersion,
    int? currentBuild,
    int? bytesReceived,
    int? totalBytes,
    String? error,
    bool clearError = false,
  }) => UpdateState(
    phase: phase ?? this.phase,
    release: release ?? this.release,
    artifact: artifact ?? this.artifact,
    currentVersion: currentVersion ?? this.currentVersion,
    currentBuild: currentBuild ?? this.currentBuild,
    bytesReceived: bytesReceived ?? this.bytesReceived,
    totalBytes: totalBytes ?? this.totalBytes,
    error: clearError ? null : error ?? this.error,
  );
}

class UpdateManifest {
  final int schemaVersion;
  final DateTime generatedAt;
  final DateTime expiresAt;
  final List<AppRelease> releases;

  const UpdateManifest({
    required this.schemaVersion,
    required this.generatedAt,
    required this.expiresAt,
    required this.releases,
  });

  factory UpdateManifest.fromJson(Map<String, dynamic> json) {
    final generatedAt = DateTime.tryParse(json['generatedAt'] as String? ?? '');
    final expiresAt = DateTime.tryParse(json['expiresAt'] as String? ?? '');
    final rawReleases = json['releases'];
    if (json['schemaVersion'] != 1 ||
        generatedAt == null ||
        expiresAt == null ||
        rawReleases is! List) {
      throw const FormatException('Invalid update manifest.');
    }
    final manifest = UpdateManifest(
      schemaVersion: 1,
      generatedAt: generatedAt.toUtc(),
      expiresAt: expiresAt.toUtc(),
      releases: [
        for (final value in rawReleases)
          if (value is Map<String, dynamic>) AppRelease.fromJson(value),
      ],
    );
    if (!manifest.expiresAt.isAfter(DateTime.now().toUtc())) {
      throw const FormatException('The update manifest has expired.');
    }
    return manifest;
  }

  ({AppRelease release, UpdateArtifact artifact})? latestCompatible({
    required String currentVersion,
    required int currentBuild,
    String channel = 'stable',
  }) {
    final installedVersion = Version.parse(currentVersion);
    final compatible = <({AppRelease release, UpdateArtifact artifact})>[];
    for (final release in releases) {
      if (release.channel != channel ||
          !_isNewer(
            release.version,
            release.build,
            installedVersion,
            currentBuild,
          )) {
        continue;
      }
      final artifact = release.artifactForCurrentPlatform();
      if (artifact != null) {
        compatible.add((release: release, artifact: artifact));
      }
    }
    compatible.sort((a, b) {
      final byVersion = a.release.version.compareTo(b.release.version);
      return byVersion != 0
          ? byVersion
          : a.release.build.compareTo(b.release.build);
    });
    return compatible.isEmpty ? null : compatible.last;
  }

  static bool _isNewer(
    Version candidateVersion,
    int candidateBuild,
    Version installedVersion,
    int installedBuild,
  ) {
    final byVersion = candidateVersion.compareTo(installedVersion);
    return byVersion > 0 || (byVersion == 0 && candidateBuild > installedBuild);
  }
}

class AppRelease {
  final Version version;
  final int build;
  final String channel;
  final bool mandatory;
  final String notes;
  final List<UpdateArtifact> artifacts;

  const AppRelease({
    required this.version,
    required this.build,
    required this.channel,
    required this.mandatory,
    required this.notes,
    required this.artifacts,
  });

  factory AppRelease.fromJson(Map<String, dynamic> json) {
    final rawArtifacts = json['artifacts'];
    final versionText = json['version'];
    final build = json['build'];
    if (versionText is! String ||
        build is! int ||
        build < 0 ||
        rawArtifacts is! List) {
      throw const FormatException('Invalid release entry.');
    }
    return AppRelease(
      version: Version.parse(versionText),
      build: build,
      channel: json['channel'] as String? ?? 'stable',
      mandatory: json['mandatory'] as bool? ?? false,
      notes: json['notes'] as String? ?? '',
      artifacts: [
        for (final value in rawArtifacts)
          if (value is Map<String, dynamic>) UpdateArtifact.fromJson(value),
      ],
    );
  }

  String get displayVersion => 'v$version';

  UpdateArtifact? artifactForCurrentPlatform() {
    final target = UpdateTarget.current;
    for (final artifact in artifacts) {
      if (artifact.platform == target.platform &&
          (artifact.architecture == target.architecture ||
              artifact.architecture == 'any')) {
        return artifact;
      }
    }
    return null;
  }
}

class UpdateArtifact {
  static const allowedHosts = {
    'github.com',
    'objects.githubusercontent.com',
    'release-assets.githubusercontent.com',
  };

  final String platform;
  final String architecture;
  final Uri url;
  final String fileName;
  final int sizeBytes;
  final String sha256;

  const UpdateArtifact({
    required this.platform,
    required this.architecture,
    required this.url,
    required this.fileName,
    required this.sizeBytes,
    required this.sha256,
  });

  factory UpdateArtifact.fromJson(Map<String, dynamic> json) {
    final uri = Uri.tryParse(json['url'] as String? ?? '');
    final sizeBytes = json['sizeBytes'];
    final sha256 = (json['sha256'] as String? ?? '').toLowerCase();
    final fileName = json['fileName'] as String? ?? '';
    if (json['platform'] is! String ||
        json['architecture'] is! String ||
        uri == null ||
        uri.scheme != 'https' ||
        !allowedHosts.contains(uri.host) ||
        uri.userInfo.isNotEmpty ||
        sizeBytes is! int ||
        sizeBytes <= 0 ||
        fileName.isEmpty ||
        fileName.contains('/') ||
        fileName.contains('\\') ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(sha256)) {
      throw const FormatException('Invalid update artifact.');
    }
    return UpdateArtifact(
      platform: json['platform'] as String,
      architecture: json['architecture'] as String,
      url: uri,
      fileName: fileName,
      sizeBytes: sizeBytes,
      sha256: sha256,
    );
  }

  Map<String, dynamic> toJson() => {
    'platform': platform,
    'architecture': architecture,
    'url': url.toString(),
    'fileName': fileName,
    'sizeBytes': sizeBytes,
    'sha256': sha256,
  };
}

class UpdateTarget {
  final String platform;
  final String architecture;

  const UpdateTarget(this.platform, this.architecture);

  static UpdateTarget get current {
    final platform = Platform.isAndroid
        ? 'android'
        : Platform.isWindows
        ? 'windows'
        : Platform.isMacOS
        ? 'macos'
        : Platform.isLinux
        ? 'linux'
        : 'unsupported';
    final abi = Abi.current().toString().split('.').last.toLowerCase();
    final architecture = abi.contains('arm64')
        ? 'arm64'
        : abi.contains('arm')
        ? 'arm'
        : abi.contains('ia32')
        ? 'x86'
        : 'x64';
    return UpdateTarget(platform, architecture);
  }
}
