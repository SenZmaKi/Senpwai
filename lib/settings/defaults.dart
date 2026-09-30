import 'package:senpwai/settings/models.dart';
import 'package:senpwai/shared/platform_paths.dart';

/// The single source of truth for an app-settings baseline.
///
/// Both a newly-created settings file and an explicit reset resolve through
/// this registry so device-specific defaults, such as the downloads folder,
/// cannot drift apart.
class AppSettingsDefaultResolver {
  const AppSettingsDefaultResolver._();

  /// Resolves the baseline values that need the current device at runtime.
  static Future<AppSettings> resolve() async {
    final defaultRoot = await defaultAnimeDownloadsRootDirectory();
    return AppSettingsDefaults.settings.copyWith(
      downloads: AppSettingsDefaults.settings.downloads.copyWith(
        defaultRootDirectory: defaultRoot.path,
        rootDirectories: [defaultRoot.path],
      ),
    );
  }
}
