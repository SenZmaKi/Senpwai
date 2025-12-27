import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

Document parseHtml(dynamic input) {
  return html.parse(input);
}

String? parseResolution(String text) {
  final match = Constants.resolutionRegex.firstMatch(text);
  final resolution = match?.group(1) ?? match?.group(2);
  return resolution;
}

class Constants {
  static final resolutionRegex = RegExp(r'\b(?:(\d{3,4})p|\d+x(\d+))\b');
}

class ScrapingException implements Exception {
  final String message;
  final Map<String, dynamic> metadata;
  ScrapingException({required this.message, required this.metadata});

  @override
  String toString() => 'ScrapingException: $message, metadata: $metadata';
}
