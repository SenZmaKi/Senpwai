import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

Document parseHtml(dynamic input) {
  return html.parse(input);
}
