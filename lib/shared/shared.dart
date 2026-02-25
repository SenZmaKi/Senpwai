import 'dart:convert';
import 'dart:io';


class Constants {
  static const kiloByte = 1024;
  static const megaByte = kiloByte * kiloByte;
  static const gigaByte = megaByte * kiloByte;
  static const teraByte = gigaByte * kiloByte;
}

class UnsupportedPlatformException implements Exception {
  const UnsupportedPlatformException();

  @override
  String toString() => 'Unsupported platform: ${Platform.operatingSystem}';
}

class Pagination<T> {
  final int currentPage;
  final int perPage;
  final int totalPages;
  final T items;
  final Future<Pagination<T>> Function()? fetchNextPage;

  Pagination({
    required this.currentPage,
    required this.totalPages,
    required this.items,
    required this.fetchNextPage,
    required this.perPage,
  });

  @override
  String toString() {
    return "Pagination(currentPage: $currentPage, totalPages: $totalPages, perPage: $perPage, items: $items, fetchNextPage: $fetchNextPage)";
  }
}

mixin ToJson {
  Map<String, dynamic> toMap();

  String toJson() => jsonEncode(toMap());
}
