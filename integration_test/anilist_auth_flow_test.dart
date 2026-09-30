import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/anilist/anilist.dart';

void main() {
  setUpAll(setupLogger);
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test(
    "anilist auth flow integration",
    timeout: const Timeout(Duration(minutes: 5)),
    () async {
      final auth = AnilistAuthenticatorClient();
      final token = await auth.authenticate();
      expect(token, isNotEmpty);
    },
  );
}
