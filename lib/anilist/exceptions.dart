class AnilistException implements Exception {
  final String message;
  final Object? error;

  const AnilistException(this.message, {this.error});

  @override
  String toString() => "AnilistException: $message (error: $error)";
}

class AnilistGraphqlLocation {
  final int? line;
  final int? column;

  const AnilistGraphqlLocation({this.line, this.column});

  factory AnilistGraphqlLocation.fromJson(Map<String, dynamic> json) {
    return AnilistGraphqlLocation(
      line: json["line"] is int ? json["line"] as int : null,
      column: json["column"] is int ? json["column"] as int : null,
    );
  }

  @override
  String toString() => "AnilistGraphqlLocation(line: $line, column: $column)";
}

class AnilistGraphqlError {
  final String message;
  final String? status;
  final List<AnilistGraphqlLocation> locations;
  final List<String> path;
  final Map<String, dynamic> extensions;

  const AnilistGraphqlError({
    required this.message,
    required this.locations,
    required this.path,
    required this.extensions,
    this.status,
  });

  factory AnilistGraphqlError.fromJson(Map<String, dynamic> json) {
    final extensions = json["extensions"] is Map<String, dynamic>
        ? json["extensions"] as Map<String, dynamic>
        : <String, dynamic>{};
    return AnilistGraphqlError(
      message: json["message"]?.toString() ?? "Unknown GraphQL error",
      status: extensions["status"]?.toString(),
      locations: (json["locations"] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AnilistGraphqlLocation.fromJson)
          .toList(),
      path: (json["path"] as List<dynamic>? ?? const [])
          .map((part) => part.toString())
          .toList(),
      extensions: extensions,
    );
  }

  @override
  String toString() {
    return "AnilistGraphqlError(message: $message, status: $status, "
        "locations: $locations, path: $path, extensions: $extensions)";
  }
}

class AnilistGraphqlException extends AnilistException {
  final List<AnilistGraphqlError> errors;

  AnilistGraphqlException(this.errors, {Object? error})
    : super(_messageForErrors(errors), error: error);

  static String _messageForErrors(List<AnilistGraphqlError> errors) {
    if (errors.isEmpty) {
      return "AniList returned an unknown GraphQL error";
    }
    final messages = errors.map((error) => error.message).join("; ");
    return "AniList returned GraphQL ${errors.length == 1 ? 'error' : 'errors'}: $messages";
  }

  @override
  String toString() => "AnilistGraphqlException: $message (errors: $errors)";
}

class AnilistEmptyResponseException extends AnilistException {
  const AnilistEmptyResponseException()
    : super("AniList response body was empty");
}

class AnilistAuthUrlOpenException extends AnilistException {
  const AnilistAuthUrlOpenException({Object? error})
    : super("Failed to open AniList auth URL", error: error);
}

class AnilistAuthMissingTokenException extends AnilistException {
  const AnilistAuthMissingTokenException()
    : super("Auth redirect missing access_token parameter");
}

class AnilistAuthRequiredException extends AnilistException {
  const AnilistAuthRequiredException()
    : super("Authentication is required for this request");
}

class AnilistInvalidTokenException extends AnilistException {
  const AnilistInvalidTokenException()
    : super("AniList token is invalid or expired");
}
