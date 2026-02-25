class AnilistException implements Exception {
  final String message;
  final Object? error;

  const AnilistException(this.message, {this.error});

  @override
  String toString() => "AnilistException: $message (error: $error)";
}

class AnilistEmptyResponseException extends AnilistException {
  const AnilistEmptyResponseException()
    : super("AniList response body was empty");
}

class AnilistTokenExchangeException extends AnilistException {
  const AnilistTokenExchangeException({Object? error})
    : super("AniList token response missing access_token", error: error);
}

class AnilistAuthUrlOpenException extends AnilistException {
  const AnilistAuthUrlOpenException({Object? error})
    : super("Failed to open AniList auth URL", error: error);
}

class AnilistAuthMissingCodeException extends AnilistException {
  const AnilistAuthMissingCodeException()
    : super("Auth redirect missing code parameter");
}

class AnilistAuthRequiredException extends AnilistException {
  const AnilistAuthRequiredException()
    : super("Authentication is required for this request");
}

class AnilistInvalidTokenException extends AnilistException {
  const AnilistInvalidTokenException()
    : super("AniList token is invalid or expired");
}
