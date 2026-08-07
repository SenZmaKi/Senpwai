import 'package:fuzzywuzzy/fuzzywuzzy.dart';

final _punctuation = RegExp(r'[^\p{L}\p{N}\s]', unicode: true);
final _whitespace = RegExp(r'\s+');

/// Words people commonly use when looking for a setting rather than its label.
///
/// Keep these close to the search matcher so labels in cards, tiles, and the
/// overall search index all receive the same aliases.
const _settingSearchAliases = <String, List<String>>{
  'launch at startup': [
    'launch on login',
    'start on login',
    'start on boot',
    'auto start',
    'autostart',
  ],
  'always on top': ['pin window', 'keep window visible', 'floating window'],
  'minimize to tray': [
    'close to tray',
    'close to system tray',
    'system tray',
    'notification area',
    'menu bar',
    'hide window',
    'keep running in background',
    'close button behavior',
  ],
  'open maximized': ['start maximized', 'maximize on launch'],
  'open in full screen': ['start fullscreen', 'fullscreen on launch'],
  'title language': [
    'anime title',
    'english title',
    'japanese title',
    'romanized title',
  ],
  'default resolution': [
    'video quality',
    'download quality',
    '1080p',
    '720p',
    '480p',
  ],
  'default audio': ['dub', 'sub', 'voice language', 'audio language'],
  'skip filler episodes': ['filler', 'non canon', 'canon episodes'],
  'adult content': ['nsfw', 'mature content', '18 plus', 'explicit content'],
  'anime library folders': [
    'download folder',
    'save location',
    'destination folder',
    'download path',
  ],
  'http download limit': ['download speed', 'bandwidth limit', 'rate limit'],
  'active http downloads': [
    'simultaneous downloads',
    'parallel downloads',
    'download queue',
  ],
  'torrent download limit': ['torrent speed', 'download bandwidth'],
  'torrent upload limit': ['upload speed', 'upload bandwidth'],
  'active torrent downloads': ['simultaneous torrents', 'torrent queue'],
  'active seeds': ['active seeding', 'seed limit', 'seeding slots'],
  'after download completes': ['seeding mode', 'stop seeding', 'keep seeding'],
  'seed ratio': ['share ratio', 'upload ratio'],
  'seed time': ['seeding duration', 'seeding time'],
  'torrent port': ['listening port', 'incoming port', 'peer port'],
  'maximum connections': ['peer limit', 'connection limit', 'max peers'],
  'local peer discovery': ['lsd', 'lan peers', 'local network peers'],
  'upnp port mapping': [
    'upnp',
    'router port forwarding',
    'automatic port forwarding',
  ],
  'nat pmp port mapping': ['nat pmp', 'natpmp', 'router port forwarding'],
  'peer encryption': ['encrypted peers', 'torrent encryption'],
  'anonymous mode': [
    'privacy mode',
    'hide torrent client',
    'anonymous torrent',
  ],
  'proxy': ['vpn proxy', 'socks', 'socks5', 'http proxy'],
  'system notifications': [
    'desktop notifications',
    'alerts',
    'notification permission',
  ],
  'download notification style': ['completion notification', 'download alerts'],
  'image cache limit': ['cover cache', 'poster cache', 'artwork cache'],
  'http cache age': ['network cache', 'cache expiry', 'cache expiration'],
  'clear cloudflare sessions': [
    'clear cookies',
    'cloudflare cookies',
    'reset cloudflare',
  ],
  'clear app cache sessions': ['clear all cache', 'clear temporary data'],
  'reset all settings': [
    'factory reset',
    'restore defaults',
    'reset preferences',
  ],
};

String _normalize(String value) => value
    .replaceAll(_punctuation, ' ')
    .replaceAll(_whitespace, ' ')
    .trim()
    .toLowerCase();

Iterable<String> _expandTerms(Iterable<String> terms) sync* {
  for (final term in terms) {
    yield term;
    final normalizedTerm = _normalize(term);
    for (final entry in _settingSearchAliases.entries) {
      if (normalizedTerm.contains(entry.key)) {
        yield* entry.value;
      }
    }
  }
}

bool settingsSearchMatches(String? query, Iterable<String> terms) {
  if (query == null || query.trim().isEmpty) return true;

  final normalizedQuery = _normalize(query);
  final normalizedTerms = _expandTerms(
    terms,
  ).map(_normalize).where((term) => term.isNotEmpty).toList();
  final haystack = normalizedTerms.join(' ');

  if (haystack.contains(normalizedQuery)) return true;

  final queryTokens = normalizedQuery.split(' ');
  final termTokens = haystack.split(' ');
  return queryTokens.every((queryToken) {
    if (queryToken.length < 4) return termTokens.contains(queryToken);
    final minimumScore = queryToken.length == 4 ? 75 : 80;
    return termTokens.any(
      (termToken) =>
          termToken.length >= 4 && ratio(queryToken, termToken) >= minimumScore,
    );
  });
}

abstract interface class SettingsSearchable {
  bool matchesSearch(String? query);
}
