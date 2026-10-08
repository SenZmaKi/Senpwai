import 'dart:io';

import 'package:libtorrent_dart/libtorrent_dart.dart';
import 'package:senpwai/settings/models.dart';

// settings_pack identifiers from libtorrent 2.0. The published binding exposes
// generic settings tags but does not yet name these settings.
const _outgoingInterfaces = 4;
const _enableNatpmp = 0x8000 + 60;
const _enableUpnp = 0x8000 + 59;
const _enableLsd = 0x8000 + 61;
const _enableDht = 0x8000 + 62;
const _proxyHostnames = 0x8000 + 64;
const _proxyPeerConnections = 0x8000 + 65;
const _proxyTrackerConnections = 0x8000 + 67;
const _listenSystemPortFallback = 0x8000 + 56;

/// Invalid protection settings leave the session paused instead of falling back.
bool torrentNetworkBlocked(TorrentPreferences settings) {
  final interface = settings.vpnInterface.trim();
  final proxy = settings.proxyMode != TorrentProxyMode.none;
  final validInterface =
      interface.isNotEmpty &&
      !RegExp(r'[,;:\[\]*\r\n]').hasMatch(interface) &&
      InternetAddress.tryParse(interface) == null;
  return (settings.vpnBindingEnabled && (!validInterface || proxy)) ||
      (proxy &&
          (settings.proxyHost.trim().isEmpty ||
              settings.proxyPort <= 0 ||
              settings.proxyPort > 65535));
}

/// Install network policy in the constructor, before any sockets are opened.
List<LibtorrentTagItem> torrentSessionSettings(TorrentPreferences settings) {
  final proxy = settings.proxyMode != TorrentProxyMode.none;
  final bound = settings.vpnBindingEnabled;
  final interface = settings.vpnInterface.trim();
  final blocked = torrentNetworkBlocked(settings);
  final protected = bound || proxy || blocked;
  final config = SessionConfig(
    downloadRateLimit: settings.maxDownloadBytesPerSecond,
    uploadRateLimit: settings.maxUploadBytesPerSecond,
    connectionsLimit: settings.maxConnections,
    activeDownloads: settings.maxActiveDownloads,
    activeSeeds: settings.maxActiveSeeds,
    seedRatioLimit: settings.seedRatioLimit,
    seedTimeLimit: Duration(minutes: settings.seedTimeLimitMinutes),
    torrentPort: settings.torrentPort,
    outgoingEncryptionPolicy: _encryptionPolicyValue(settings.encryptionMode),
    incomingEncryptionPolicy: _encryptionPolicyValue(settings.encryptionMode),
    allowedEncryptionLevel: LibtorrentEncryptionLevel.both,
    anonymousMode: settings.anonymousMode,
    enableIncomingTcp: settings.enableIncomingTcp && !blocked,
    enableIncomingUtp: settings.enableIncomingUtp && !blocked,
    enableOutgoingTcp: settings.enableOutgoingTcp && !blocked,
    enableOutgoingUtp: settings.enableOutgoingUtp && !blocked,
  );
  return [
    ...config.toSettingsItems(),
    LibtorrentTagItem.settingsString(
      _outgoingInterfaces,
      blocked ? 'senpwai-blocked-interface' : (bound ? interface : ''),
    ),
    LibtorrentTagItem.settingsString(
      LibtorrentSettingsTag.listenInterfaces,
      blocked
          ? ''
          : (bound
                ? '$interface:${settings.torrentPort}'
                : SessionConfig.listenInterfacesForPort(settings.torrentPort)),
    ),
    LibtorrentTagItem.settingsBool(_listenSystemPortFallback, !protected),
    LibtorrentTagItem.settingsString(
      LibtorrentSettingsTag.proxyHostname,
      proxy && !blocked ? settings.proxyHost.trim() : '',
    ),
    LibtorrentTagItem.settingsInt(
      LibtorrentSettingsTag.proxyPort,
      proxy && !blocked ? settings.proxyPort : 0,
    ),
    LibtorrentTagItem.settingsString(
      LibtorrentSettingsTag.proxyUsername,
      proxy && !blocked ? settings.proxyUsername : '',
    ),
    LibtorrentTagItem.settingsString(
      LibtorrentSettingsTag.proxyPassword,
      proxy && !blocked ? settings.proxyPassword : '',
    ),
    LibtorrentTagItem.settingsInt(
      LibtorrentSettingsTag.proxyType,
      blocked ? LibtorrentProxyType.none : _proxyTypeValue(settings.proxyMode),
    ),
    LibtorrentTagItem.settingsBool(_proxyHostnames, true),
    LibtorrentTagItem.settingsBool(_proxyPeerConnections, true),
    LibtorrentTagItem.settingsBool(_proxyTrackerConnections, true),
    LibtorrentTagItem.settingsBool(
      _enableDht,
      settings.enableDht &&
          !blocked &&
          (!proxy ||
              settings.proxyMode == TorrentProxyMode.socks5 ||
              settings.proxyMode == TorrentProxyMode.socks5Password),
    ),
    LibtorrentTagItem.settingsBool(
      _enableLsd,
      settings.enableLsd && !protected,
    ),
    LibtorrentTagItem.settingsBool(
      _enableUpnp,
      settings.enableUpnp && !protected,
    ),
    LibtorrentTagItem.settingsBool(
      _enableNatpmp,
      settings.enableNatPmp && !protected,
    ),
  ];
}

/// Metadata inspection must never announce, discover peers or download payload.
Session createOfflineTorrentSession() => createSessionFromTags([
  LibtorrentTagItem.settingsString(LibtorrentSettingsTag.listenInterfaces, ''),
  LibtorrentTagItem.settingsString(
    _outgoingInterfaces,
    'senpwai-blocked-interface',
  ),
  for (final tag in [
    _enableDht,
    _enableLsd,
    _enableUpnp,
    _enableNatpmp,
    LibtorrentSettingsTag.enableIncomingTcp,
    LibtorrentSettingsTag.enableIncomingUtp,
    LibtorrentSettingsTag.enableOutgoingTcp,
    LibtorrentSettingsTag.enableOutgoingUtp,
  ])
    LibtorrentTagItem.settingsBool(tag, false),
]);

int _encryptionPolicyValue(TorrentEncryptionMode mode) {
  return switch (mode) {
    TorrentEncryptionMode.forced => LibtorrentEncryptionPolicy.forced,
    TorrentEncryptionMode.enabled => LibtorrentEncryptionPolicy.enabled,
    TorrentEncryptionMode.disabled => LibtorrentEncryptionPolicy.disabled,
  };
}

int _proxyTypeValue(TorrentProxyMode mode) {
  return switch (mode) {
    TorrentProxyMode.none => LibtorrentProxyType.none,
    TorrentProxyMode.socks4 => LibtorrentProxyType.socks4,
    TorrentProxyMode.socks5 => LibtorrentProxyType.socks5,
    TorrentProxyMode.socks5Password => LibtorrentProxyType.socks5Password,
    TorrentProxyMode.http => LibtorrentProxyType.http,
    TorrentProxyMode.httpPassword => LibtorrentProxyType.httpPassword,
  };
}
