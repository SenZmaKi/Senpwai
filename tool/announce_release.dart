import 'dart:convert';
import 'dart:io';

const _discordChannel = '1142774130689720370';
const _redditUserAgent = 'SenpwaiReleaseBot/3.0 by SenZmaKi';
const _downloadUrl = 'https://senpwai.com/download';

Future<void> main(List<String> args) async {
  if (args.length != 2 || !{'discord', 'reddit'}.contains(args.first)) {
    stderr.writeln(
      'Usage: dart run tool/announce_release.dart <discord|reddit> <version>',
    );
    exitCode = 64;
    return;
  }
  final version = args[1];
  if (!RegExp(r'^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$').hasMatch(version)) {
    throw FormatException('Invalid release version: $version');
  }
  final notes = await File('release-notes/$version.md').readAsString();
  if (notes.trim().isEmpty) throw StateError('Release notes are empty');
  final title = notes
      .split('\n')
      .first
      .replaceFirst(RegExp(r'^#\s+'), '')
      .trim();
  final redditBody = notes.replaceFirst(RegExp(r'^# [^\n]*\r?\n\r?\n'), '');
  final releaseUrl =
      'https://github.com/SenZmaKi/Senpwai/releases/tag/v$version';
  final client = HttpClient();
  try {
    if (args.first == 'discord') {
      final token = _required('DISCORD_BOT_TOKEN');
      final body =
          '${notes.replaceAllMapped(RegExp(r'https://\S+'), (match) => '<${match[0]}>')}\n\nDownload Senpwai: <$_downloadUrl>\nGitHub release: $releaseUrl';
      if (body.length > 2000) {
        throw StateError('Discord announcement exceeds 2000 characters');
      }
      await _postJson(
        client,
        Uri.https('discord.com', '/api/v10/channels/$_discordChannel/messages'),
        {'content': body},
        {'Authorization': 'Bot $token'},
      );
    } else {
      final id = _required('REDDIT_CLIENT_ID');
      final secret = _required('REDDIT_CLIENT_SECRET');
      final username = _required('REDDIT_USERNAME');
      final password = _required('REDDIT_PASSWORD');
      final tokenResponse = await _postForm(
        client,
        Uri.https('www.reddit.com', '/api/v1/access_token'),
        {'grant_type': 'password', 'username': username, 'password': password},
        {'Authorization': 'Basic ${base64Encode(utf8.encode('$id:$secret'))}'},
      );
      final token =
          (jsonDecode(tokenResponse) as Map<String, dynamic>)['access_token']
              as String;
      final response = await _postForm(
        client,
        Uri.https('oauth.reddit.com', '/api/submit'),
        {
          'title': title,
          'kind': 'self',
          'sr': 'Senpwai',
          'resubmit': 'true',
          'send_replies': 'true',
          'text':
              '$redditBody\n\nDownload Senpwai: $_downloadUrl\nGitHub release: $releaseUrl',
        },
        {'Authorization': 'Bearer $token'},
      );
      final result = jsonDecode(response) as Map<String, dynamic>;
      final errors =
          (result['json'] as Map<String, dynamic>?)?['errors']
              as List<dynamic>?;
      if (errors != null && errors.isNotEmpty) {
        throw StateError('Reddit rejected submission: $errors');
      }
      final name =
          ((result['json'] as Map<String, dynamic>?)?['data']
                  as Map<String, dynamic>?)?['name']
              as String?;
      if (name == null || !name.startsWith('t3_')) {
        throw StateError('Reddit did not return a post ID');
      }
      await _postForm(
        client,
        Uri.https('oauth.reddit.com', '/api/approve'),
        {'id': name},
        {'Authorization': 'Bearer $token'},
      );
    }
  } finally {
    client.close();
  }
}

String _required(String name) {
  final value = Platform.environment[name];
  if (value == null || value.isEmpty) throw StateError('Missing $name');
  return value;
}

Future<String> _postJson(
  HttpClient client,
  Uri uri,
  Object body,
  Map<String, String> headers,
) => _post(client, uri, jsonEncode(body), 'application/json', headers);

Future<String> _postForm(
  HttpClient client,
  Uri uri,
  Map<String, String> body,
  Map<String, String> headers,
) => _post(
  client,
  uri,
  Uri(queryParameters: body).query,
  'application/x-www-form-urlencoded',
  headers,
);

Future<String> _post(
  HttpClient client,
  Uri uri,
  String body,
  String contentType,
  Map<String, String> headers,
) async {
  final request = await client.postUrl(uri);
  request.headers.contentType = ContentType.parse(contentType);
  request.headers.set('User-Agent', _redditUserAgent);
  for (final entry in headers.entries) {
    request.headers.set(entry.key, entry.value);
  }
  request.write(body);
  final response = await request.close();
  final text = await utf8.decoder.bind(response).join();
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw HttpException(
      'Announcement request failed (${response.statusCode}): $text',
      uri: uri,
    );
  }
  return text;
}
