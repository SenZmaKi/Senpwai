import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/shared/net/browser_transport/routing.dart';
import 'package:senpwai/shared/net/interceptors/cookie_manager.dart';
import 'package:senpwai/shared/source_directory/source_directory.dart';

void main() {
  group('SourceEndpoint validation', () {
    test('accepts a constrained HTTPS endpoint', () {
      const SourceEndpoint(
        baseUrl: 'https://source.example',
        apiEntryPoint: 'https://api.source.example/v1/',
        allowedHosts: {'source.example', 'api.source.example'},
        maxConcurrentRequests: 5,
      ).validate();
    });

    for (final invalid in <String, SourceEndpoint>{
      'plain HTTP': const SourceEndpoint(
        baseUrl: 'http://source.example',
        allowedHosts: {'source.example'},
      ),
      'userinfo': const SourceEndpoint(
        baseUrl: 'https://user:secret@source.example',
        allowedHosts: {'source.example'},
      ),
      'custom port': const SourceEndpoint(
        baseUrl: 'https://source.example:8443',
        allowedHosts: {'source.example'},
      ),
      'unlisted base host': const SourceEndpoint(
        baseUrl: 'https://source.example',
        allowedHosts: {'other.example'},
      ),
      'unlisted API host': const SourceEndpoint(
        baseUrl: 'https://source.example',
        apiEntryPoint: 'https://api.source.example/v1/',
        allowedHosts: {'source.example'},
      ),
      'invalid host characters': const SourceEndpoint(
        baseUrl: 'https://source.example',
        allowedHosts: {'source.example', 'UPPER.example'},
      ),
      'zero concurrency': const SourceEndpoint(
        baseUrl: 'https://source.example',
        allowedHosts: {'source.example'},
        maxConcurrentRequests: 0,
      ),
      'excessive concurrency': const SourceEndpoint(
        baseUrl: 'https://source.example',
        allowedHosts: {'source.example'},
        maxConcurrentRequests: 21,
      ),
    }.entries) {
      test('rejects ${invalid.key}', () {
        expect(invalid.value.validate, throwsFormatException);
      });
    }

    test('rejects oversized allowed-host lists', () {
      final endpoint = SourceEndpoint(
        baseUrl: 'https://host0.example',
        allowedHosts: {
          for (var index = 0; index < 9; index++) 'host$index.example',
        },
      );

      expect(endpoint.validate, throwsFormatException);
    });
  });

  group('SourceDirectory payload', () {
    test('parses a complete future-dated directory', () {
      final directory = SourceDirectory.fromJson(_directoryJson());

      expect(directory.version, 7);
      expect(directory.expiresAt.isUtc, isTrue);
      expect(directory.animePahe.apiEntryPoint, endsWith('/api?m='));
      expect(directory.nyaa.maxConcurrentRequests, 5);
    });

    test('defaults a missing directory version to zero', () {
      final json = _directoryJson()..remove('version');

      expect(SourceDirectory.fromJson(json).version, 0);
    });

    test('rejects expired directories', () {
      final json = _directoryJson()..['expiresAt'] = '2000-01-01T00:00:00Z';

      expect(() => SourceDirectory.fromJson(json), throwsFormatException);
    });

    test('rejects missing source entries', () {
      final json = _directoryJson();
      (json['sources'] as Map<String, dynamic>).remove('nyaa');

      expect(() => SourceDirectory.fromJson(json), throwsFormatException);
    });
  });

  test('source directory requests bypass cookies/browser and accept 304', () {
    final options = sourceDirectoryRequestOptions(eTag: '"abc"');

    expect(options.headers?['Cache-Control'], 'no-cache');
    expect(options.headers?['If-None-Match'], '"abc"');
    expect(options.extra?[skipCookieManagerExtraKey], isTrue);
    expect(
      options.extra?[transportPreferenceExtraKey],
      TransportPreference.native,
    );
    expect(options.validateStatus?.call(HttpStatus.ok), isTrue);
    expect(options.validateStatus?.call(HttpStatus.notModified), isTrue);
    expect(options.validateStatus?.call(HttpStatus.badRequest), isFalse);
  });
}

Map<String, dynamic> _directoryJson() => {
  'version': 7,
  'expiresAt': '2100-01-01T00:00:00Z',
  'sources': {
    'animepahe': {
      'baseUrl': 'https://anime.example',
      'apiEntryPoint': 'https://anime.example/api?m=',
      'allowedHosts': ['anime.example'],
    },
    'kwik': {
      'baseUrl': 'https://kwik.example',
      'allowedHosts': ['kwik.example'],
    },
    'nyaa': {
      'baseUrl': 'https://nyaa.example',
      'allowedHosts': ['nyaa.example'],
      'maxConcurrentRequests': 5,
    },
    'tokyoinsider': {
      'baseUrl': 'https://tokyo.example',
      'allowedHosts': ['tokyo.example'],
    },
  },
};
