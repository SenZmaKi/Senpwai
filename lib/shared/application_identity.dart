/// Names and storage identity for the channel selected by the release build.
abstract final class ApplicationIdentity {
  static const channel = String.fromEnvironment(
    'UPDATE_CHANNEL',
    defaultValue: 'stable',
  );
  static const nightly = channel == 'nightly';
  static const packageName = nightly
      ? 'com.senpwai.app.nightly'
      : 'com.senpwai.app';
  static const name = nightly ? 'Senpwai Nightly' : 'Senpwai';
  static const iconAsset = nightly
      ? 'assets/images/senpwai-nightly-icon.png'
      : 'assets/images/senpwai-icon.png';
  static const dataDirectory = nightly ? 'SenpwaiNightlyData' : 'SenpwaiData';
  static const credentialsAccount = nightly
      ? 'com.senpwai.app.nightly.credentials'
      : 'com.senpwai.app.credentials';
  static const authScheme = nightly ? 'senpwai-nightly' : 'senpwai';
  static const credentialPrefix = nightly ? 'nightly_' : '';
}
