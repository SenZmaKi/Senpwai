import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

Document parseHtml(dynamic input) {
  return html.parse(input);
}

class ScrapingException implements Exception {
  final String message;
  final Map<String, dynamic> metadata;
  ScrapingException({required this.message, required this.metadata});

  @override
  String toString() => 'ScrapingException: $message';
}
