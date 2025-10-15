// Web implementation: downloads a .txt file using dart:html
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

Future<String?> downloadTextFile(String filename, String content) async {
  final bytes = const Utf8Encoder().convert(content);
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.document.createElement('a') as html.AnchorElement
    ..href = url
    ..download = filename
    ..style.display = 'none';
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return filename;
}
