abstract final class HttpCacheDefaults {
  static const liveSearchTtlSeconds = 2 * 60;
  static const catalogueTtlSeconds = 60 * 60;
  static const referenceTtlSeconds = 24 * 60 * 60;

  static const liveSearchTtl = Duration(seconds: liveSearchTtlSeconds);
  static const catalogueTtl = Duration(seconds: catalogueTtlSeconds);
  static const referenceTtl = Duration(seconds: referenceTtlSeconds);
}
