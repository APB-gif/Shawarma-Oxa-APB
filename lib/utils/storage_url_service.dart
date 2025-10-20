import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio simple para pedir y cachear signed URLs desde el endpoint de funciones.
class StorageUrlService {
  final String baseUrl; // e.g. https://us-central1-PROJECT.cloudfunctions.net
  final Duration defaultTtl;

  StorageUrlService(
      {required this.baseUrl, this.defaultTtl = const Duration(hours: 6)});

  Future<Map<String, dynamic>> _callGetSignedUrls(List<String> paths,
      {int ttlSeconds = 21600}) async {
    final url = Uri.parse('$baseUrl/getSignedUrls');
    final resp = await http.post(url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'paths': paths, 'ttlSeconds': ttlSeconds}));
    if (resp.statusCode != 200)
      throw Exception('Failed to get signed urls: ${resp.statusCode}');
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<String?> getUrlForPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'signedurl:$path';
    final metaKey = '$key:meta';
    final cached = prefs.getString(key);
    final meta = prefs.getString(metaKey);
    if (cached != null && meta != null) {
      try {
        final m = jsonDecode(meta) as Map<String, dynamic>;
        final exp = DateTime.parse(m['expires']);
        if (DateTime.now().isBefore(exp)) return cached;
      } catch (e) {
        // ignore parse errors
      }
    }
    // Request from server
    try {
      final api =
          await _callGetSignedUrls([path], ttlSeconds: defaultTtl.inSeconds);
      final results = api['results'] as Map<String, dynamic>?;
      final info = results?[path] as Map<String, dynamic>?;
      final url = info?['url'] as String?;
      if (url != null) {
        final metaVal = jsonEncode(
            {'expires': DateTime.now().add(defaultTtl).toIso8601String()});
        await prefs.setString(key, url);
        await prefs.setString(metaKey, metaVal);
        return url;
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('getUrlForPath error: $e');
      return null;
    }
  }

  /// Pide signed URLs en lote para varias paths y las cachea.
  /// Devuelve un mapa path->url (null si falla para esa path).
  Future<Map<String, String?>> getUrlsForPaths(List<String> paths) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final Map<String, String?> result = {};
    // Primero revisamos cache local
    final toRequest = <String>[];
    for (final path in paths) {
      final key = 'signedurl:$path';
      final metaKey = '$key:meta';
      final cached = prefs.getString(key);
      final meta = prefs.getString(metaKey);
      if (cached != null && meta != null) {
        try {
          final m = jsonDecode(meta) as Map<String, dynamic>;
          final exp = DateTime.parse(m['expires']);
          if (now.isBefore(exp)) {
            result[path] = cached;
            continue;
          }
        } catch (e) {
          // fallthrough a request
        }
      }
      toRequest.add(path);
    }
    if (toRequest.isNotEmpty) {
      try {
        final api = await _callGetSignedUrls(toRequest,
            ttlSeconds: defaultTtl.inSeconds);
        final results = api['results'] as Map<String, dynamic>?;
        for (final p in toRequest) {
          final info = results?[p] as Map<String, dynamic>?;
          final url = info?['url'] as String?;
          result[p] = url;
          if (url != null) {
            final key = 'signedurl:$p';
            final metaKey = '$key:meta';
            final metaVal = jsonEncode(
                {'expires': DateTime.now().add(defaultTtl).toIso8601String()});
            await prefs.setString(key, url);
            await prefs.setString(metaKey, metaVal);
          }
        }
      } catch (e) {
        if (kDebugMode) print('getUrlsForPaths error: $e');
        for (final p in toRequest) result[p] = null;
      }
    }
    return result;
  }
}
