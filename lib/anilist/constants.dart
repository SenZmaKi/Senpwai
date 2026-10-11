import 'package:senpwai/shared/application_identity.dart';

class Constants {
  static const apiEntryPoint = "https://graphql.anilist.co";
  static const oauthAuthorizeUrl = "https://anilist.co/api/v2/oauth/authorize";
  static const oauthTokenUrl = "https://anilist.co/api/v2/oauth/token";
  static const clientId = ApplicationIdentity.nightly ? '53445' : '36391';
  static const authRedirectUri =
      '${ApplicationIdentity.authScheme}://auth/callback';
  static const defaultPerPage = 25;
}
