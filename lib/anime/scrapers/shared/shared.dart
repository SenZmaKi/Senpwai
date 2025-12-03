import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

Document parseHtml(dynamic input) {
  return html.parse(input);
}

class ScrapingException implements Exception {
  final String message;
  ScrapingException(this.message);

  @override
  String toString() => 'ScrapingException: $message';
}
