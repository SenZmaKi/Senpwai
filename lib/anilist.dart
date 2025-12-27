import 'package:dio/dio.dart';

class Constants {
  static const apiEntryPoint = "https://graphql.anilist.co";
}

class AnilistAnimeInfo {}

class AnilistClient {
  final Dio _dio;

  AnilistClient() : _dio = Dio(BaseOptions(baseUrl: Constants.apiEntryPoint));

  Future<dynamic> getAnimeInfo(int id) async {
    final response = await _dio.post(
      "/",
      data: {
        "query":
            """
        query {
          Media(idMal: $id) {
            title {
              romaji
              english
            }
            coverImage {
              large
            }
          }
        }
        """,
      },
    );
    return response.data;
  }
}
