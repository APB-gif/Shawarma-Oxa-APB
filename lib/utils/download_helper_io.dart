// Implementation for non-web platforms: create a temporary .txt file and
// invoke the system share sheet so the user can save/send the file.
import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:path_provider/path_provider.dart';

Future<String> downloadTextFile(String filename, String content) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsString(content, encoding: utf8);
  return file.path;
}
