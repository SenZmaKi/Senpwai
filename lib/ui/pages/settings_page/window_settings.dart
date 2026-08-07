import 'package:flutter/material.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/ui/pages/settings_page/settings_controls.dart';
import 'package:senpwai/ui/pages/settings_page/settings_tile.dart';

class WindowSettings extends StatelessWidget {
  final AppSettings settings;
  final AppSettingsNotifier notifier;
  final String? searchQuery;

  const WindowSettings({
    super.key,
    required this.settings,
    required this.notifier,
    this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    final preferences = settings.window;
    return SettingsGroupCard(
      title: 'Window',
      icon: Icons.web_asset_rounded,
      description: 'Choose how the app window opens and stays visible',
      searchQuery: searchQuery,
      searchTerms: [
        'desktop window launch startup',
        'launch at login automatically open when computer starts',
        'always on top',
        'close minimize hide system tray notification area',
        'open maximized',
        'open full screen fullscreen',
      ],
      children: [
        SettingsTile(
          icon: Icons.rocket_launch_outlined,
          title: 'Launch at startup',
          subtitle: 'Open Senpwai when you sign in to this computer',
          keywords: 'desktop launch startup login automatically open computer',
          searchQuery: searchQuery,
          trailing: AsyncSwitch(
            value: preferences.launchAtStartup,
            onChanged: notifier.setLaunchAtStartup,
          ),
        ),
        SettingsTile(
          icon: Icons.vertical_align_top_rounded,
          title: 'Always on top',
          subtitle: 'Keep Senpwai above other windows',
          keywords: 'desktop window stay visible foreground',
          searchQuery: searchQuery,
          trailing: AsyncSwitch(
            value: preferences.alwaysOnTop,
            onChanged: notifier.setWindowAlwaysOnTop,
          ),
        ),
        SettingsTile(
          icon: Icons.move_to_inbox_outlined,
          title: 'Minimize to tray',
          subtitle: 'Keep Senpwai running when the window is closed',
          keywords: 'desktop window close minimize hide tray notification area',
          searchQuery: searchQuery,
          trailing: AsyncSwitch(
            value: preferences.closeToTray,
            onChanged: notifier.setWindowCloseToTray,
          ),
        ),
        SettingsTile(
          icon: Icons.crop_square_rounded,
          title: 'Open maximized',
          subtitle: 'Fill the desktop when Senpwai starts',
          keywords: 'desktop window launch startup maximize',
          searchQuery: searchQuery,
          trailing: AsyncSwitch(
            value: preferences.startMaximized,
            onChanged: notifier.setWindowStartMaximized,
          ),
        ),
        SettingsTile(
          icon: Icons.fullscreen_rounded,
          title: 'Open in full screen',
          subtitle: 'Use the entire screen when Senpwai starts',
          keywords: 'desktop window launch startup fullscreen',
          searchQuery: searchQuery,
          trailing: AsyncSwitch(
            value: preferences.startFullScreen,
            onChanged: notifier.setWindowStartFullScreen,
          ),
        ),
      ],
    );
  }
}
